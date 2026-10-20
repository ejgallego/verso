#!/usr/bin/env python3
"""Check Linux shared linking, mode changes, and interpreted/rendered output."""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent.parent
TARGETS = [
    "verso", "verso-serve", "verso-html", "verso-literate",
    "verso-literate-html", "verso-literate-plan", "simplepage", "usersguide",
]


def lake(mode, *args, **kwargs):
    # Lake retains the options used to elaborate a cached lakefile until -R.
    options = ["-R"] if args[0] == "build" else []
    try:
        return subprocess.run(
            ["lake", *options, f"-KsharedLean={mode}", *args], cwd=ROOT, check=True, **kwargs
        )
    except subprocess.CalledProcessError as error:
        if error.stdout:
            sys.stderr.buffer.write(error.stdout)
        if error.stderr:
            sys.stderr.buffer.write(error.stderr)
        raise


def run_exe(mode, name, cwd, *args):
    # Keep Lake's runtime environment while giving generators a separate output directory.
    return lake(
        mode, "env", sys.executable, "-c",
        "import os,sys; os.chdir(sys.argv[1]); os.execv(sys.argv[2], sys.argv[2:])",
        str(cwd), str(ROOT / ".lake/build/bin" / name), *map(str, args),
        capture_output=True,
    )


def files(directory):
    return {
        str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in directory.rglob("*") if p.is_file()
    }


def main():
    if sys.platform != "linux":
        print("Shared-linking checks apply only to Linux.")
        return

    output = ROOT / "_out/shared-linking"
    output.mkdir(parents=True, exist_ok=True)
    sizes = {}
    outputs = {}
    with tempfile.TemporaryDirectory(prefix="check-", dir=output) as tmp:
        tmp = Path(tmp)
        (tmp / "LinkingSmoke.lean").write_text(
            "import Lean\nopen Lean Elab Command\n"
            'elab "#linkingSmoke" : command => do\n'
            "  elabCommand (← `(def linkingSmokeValue : Nat := 42))\n"
            "#linkingSmoke\n#eval linkingSmokeValue\n"
        )
        for mode in ["false", "true"]:
            lake(mode, "build", *TARGETS)
            sizes[mode] = {}
            for name in TARGETS:
                binary = ROOT / ".lake/build/bin" / name
                dynamic = subprocess.check_output(["readelf", "-d", binary], text=True)
                needed = re.findall(r"Shared library: \[(.*?)\]", dynamic)
                has_shared_lean = "libleanshared.so" in needed
                if has_shared_lean != (mode == "true"):
                    raise RuntimeError(f"{name}: unexpected dependencies in mode {mode}: {needed}")
                sizes[mode][name] = binary.stat().st_size

            smoke = tmp / f"smoke-{mode}.json"
            run_exe(mode, "verso-literate", tmp, "LinkingSmoke", smoke)
            # This command elaborates a new command elaborator and executes #eval.
            json.loads(smoke.read_bytes())
            demo = tmp / f"demo-{mode}"
            demo.mkdir()
            run_exe(mode, "simplepage", demo)
            manual = tmp / f"manual-{mode}"
            run_exe(mode, "usersguide", ROOT, "--output", manual,
                    "--without-tex", "--without-html-multi", "--with-html-single")
            outputs[mode] = (smoke.read_bytes(), files(demo), files(manual))
            if not (demo / "index.html").is_file() or not (manual / "html-single/index.html").is_file():
                raise RuntimeError(f"Missing HTML output in mode {mode}")

        if outputs["false"] != outputs["true"]:
            raise RuntimeError("Static and shared builds produced different output")
        lake("true", "test", "--", "ErrataTests", "--test-options", "--help")
        runner = ROOT / ".lake/build/bin/errata-runner-internal"
        if "libleanshared.so" not in subprocess.check_output(["readelf", "-d", runner], text=True):
            raise RuntimeError("The generated Errata runner did not use shared Lean")
        # Check the reverse transition too: a shared binary must not stay cached.
        lake("false", "build", *TARGETS)
        for name in TARGETS:
            binary = ROOT / ".lake/build/bin" / name
            dynamic = subprocess.check_output(["readelf", "-d", binary], text=True)
            if "libleanshared.so" in dynamic:
                raise RuntimeError(f"{name} did not return to static linking")

    (output / "sizes.json").write_text(json.dumps(sizes, indent=2) + "\n")
    print("Shared linking, both mode transitions, interpreted Lean, and HTML output agree.")


if __name__ == "__main__":
    main()
