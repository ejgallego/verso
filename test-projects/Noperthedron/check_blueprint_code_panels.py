#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys


def fail(msg: str) -> None:
    print(f"[blueprint-panel-regression] FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def load(path: Path) -> str:
    if not path.exists():
        fail(f"missing file: {path}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    out_root = repo_root / "_out" / "html-multi"
    local_theorem = load(out_root / "The-Local-Theorem" / "index.html")
    bounding = load(out_root / "Bounding-Rotations" / "index.html")

    for cls in (
        "bp_external_status_icon bp_external_status_ok",
        "bp_external_status_icon bp_external_status_sorry",
        "bp_external_status_icon bp_external_status_missing",
    ):
        if cls not in local_theorem:
            fail(f"missing external status class in The-Local-Theorem: {cls}")

    panel_re = re.compile(r'<details class="bp_code_block bp_code_panel"[^>]*>.*?</details>', re.S)
    external_panels = [p for p in panel_re.findall(local_theorem) if "bp_external_status_icon" in p]
    if not external_panels:
        fail("no external code panels found in The-Local-Theorem")

    for i, panel in enumerate(external_panels, start=1):
        if "bp_code_progress" in panel:
            fail(f"external panel #{i} still renders a progress bar")
        if "bp_external_decl_stmt" not in panel:
            fail(f"external panel #{i} has no rendered Lean statement block")

    literate_panels = [p for p in panel_re.findall(bounding) if "data-bp-proof-fold=" in p]
    if not literate_panels:
        fail("no literate code panels found in Bounding-Rotations")

    for i, panel in enumerate(literate_panels, start=1):
        if "bp_code_summary_indicator" not in panel:
            fail(f"literate panel #{i} missing summary indicator wrapper")
        if "bp_code_progress" not in panel:
            fail(f"literate panel #{i} missing progress bar")

    print(
        "[blueprint-panel-regression] OK:",
        f"external_panels={len(external_panels)}",
        f"literate_panels={len(literate_panels)}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
