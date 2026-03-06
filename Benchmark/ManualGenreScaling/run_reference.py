#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BENCH_DIR = ROOT / "Benchmark" / "ManualGenreScaling"
GENERATED_DIR = ROOT / "src/tests/Tests/GeneratedReference"
OUT_ROOT = ROOT / "_out" / "perf" / "manual_genre_reference"

DEFAULT_SIZES = [8, 16, 32]
DOC_FILE_COUNT = 4
DEFAULT_INDEX_REPEATS = 8


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def bench_env() -> dict[str, str]:
    env = os.environ.copy()
    env.setdefault("LEAN_NUM_THREADS", "1")
    return env


def run_timed(cmd: list[str]) -> tuple[float, subprocess.CompletedProcess[str]]:
    start = time.perf_counter()
    proc = subprocess.run(
        cmd,
        cwd=ROOT,
        env=bench_env(),
        text=True,
        capture_output=True,
    )
    elapsed_ms = (time.perf_counter() - start) * 1000.0
    return elapsed_ms, proc


def ensure_success(proc: subprocess.CompletedProcess[str], cmd: list[str]) -> None:
    if proc.returncode == 0:
        return
    sys.stderr.write(f"Command failed: {' '.join(cmd)}\n")
    if proc.stdout:
        sys.stderr.write(proc.stdout)
    if proc.stderr:
        sys.stderr.write(proc.stderr)
    raise SystemExit(proc.returncode)


def case_prefix(size: int) -> str:
    return f"Tests.GeneratedReference.S{size:04d}"


def case_dir(size: int) -> Path:
    return GENERATED_DIR / f"S{size:04d}"


def relative(path: Path) -> str:
    return str(path.relative_to(ROOT))


def api_module_source(prefix: str, size: int) -> str:
    lines = [f"namespace {prefix}.Api", ""]
    for index in range(size):
        lines.extend(
            [
                f"/-- Compute the primary benchmark value for entry {index}. -/",
                f"def benchFn{index} (n : Nat) : Nat :=",
                f"  n + {index}",
                "",
                f"/-- A documented derived value for entry {index}. -/",
                f"def benchValue{index} : Nat := benchFn{index} {index + 1}",
                "",
                f"/-- A documented text payload for entry {index}. -/",
                f"def benchText{index} : String := s!\"entry-{index}:{{benchValue{index}}}\"",
                "",
            ]
        )
    lines.extend([f"end {prefix}.Api", ""])
    return "\n".join(lines)


def papers_module_source(prefix: str, size: int) -> str:
    lines = [
        "import VersoManual",
        "",
        "open Verso.Genre.Manual",
        "",
        f"namespace {prefix}.Papers",
        "",
    ]
    for index in range(size):
        lines.extend(
            [
                f"/-- Synthetic citation target {index}. -/",
                f"def citation{index} : Article where",
                f"  title := inlines!\"Synthetic Citation {index}\"",
                f"  authors := #[inlines!\"Author {index}\"]",
                "  journal := inlines!\"Benchmark Proceedings\"",
                f"  year := {2020 + (index % 5)}",
                "  month := some inlines!\"January\"",
                "  volume := inlines!\"1\"",
                f"  number := inlines!\"{index + 1}\"",
                f"  pages := some ({index + 1}, {index + 3})",
                "",
            ]
        )
    lines.extend([f"end {prefix}.Papers", ""])
    return "\n".join(lines)


def examples_module_source(prefix: str, size: int) -> str:
    lines = [f"namespace {prefix}.Examples", ""]
    for index in range(size):
        anchor = f"bench{index}"
        lines.extend(
            [
                f"-- ANCHOR: {anchor}",
                f"def helper{index} (n : Nat) : Nat :=",
                f"  n + {index}",
                f"#eval helper{index} {index + 2}",
                f"-- ANCHOR_END: {anchor}",
                "",
            ]
        )
    lines.extend([f"end {prefix}.Examples", ""])
    return "\n".join(lines)


def doc_part_source(prefix: str, size: int, part_index: int, start: int, stop: int, index_repeats: int) -> str:
    previous_tag = f"bench-part-{part_index - 1}" if part_index > 0 else "bench-root"
    current_tag = f"bench-part-{part_index}"
    lines = [
        "import VersoManual",
        f"import {prefix}.Api",
        f"import {prefix}.Papers",
        f'import {prefix}.Examples',
        "",
        "open Verso.Genre Manual",
        "open Verso.Genre.Manual.InlineLean",
        "open Verso.Code.External",
        "",
        'set_option verso.exampleProject "."',
        f'set_option verso.exampleModule "{prefix}.Examples"',
        "set_option verso.docstring.allowMissing true",
        "set_option maxRecDepth 100000",
        "set_option maxHeartbeats 0",
        "",
        f'#doc (Manual) "Reference Part {part_index}" =>',
        "%%%",
        f'tag := "{current_tag}"',
        "%%%",
        "",
        f'This benchmark part links back to {{ref "{previous_tag}"}}[the previous part] and records {{index}}[reference-part-{part_index}].',
        "",
    ]
    for index in range(start, stop):
        fq = f"{prefix}.Api"
        papers = f"{prefix}.Papers"
        anchor = f"bench{index}"
        prev_citation = f"citation{max(index - 1, 0)}"
        stress_lines = []
        for rep in range(index_repeats):
            stress_lines.extend(
                [
                    f'Stress pass {rep} adds {{index}}[shared concept], {{index}}[entry-{index}-{rep}], '
                    f'{{see "shared concept"}}[entry-{index}-{rep}], and '
                    f'{{seeAlso "reference-part-{part_index}"}}[entry-{index}-{rep}].',
                    "",
                ]
            )
        lines.extend(
            [
                f"# Item {index}",
                "",
                "%%%",
                f'tag := "bench-item-{index}"',
                "%%%",
                "",
                f'This section cross-references {{ref "bench-item-{index}"}}[its own tag] and exercises inline code like {{anchorName {anchor}}}`helper{index}`.',
                f' It also cites {{citep {papers}.citation{index}}}[] and {{citet {papers}.{prev_citation}}}[] to exercise bibliography traversal.',
                f' Shared index traffic appears in {{index}}[shared concept] and item-specific traffic in {{index}}[entry-{index}].',
                f' Cross-index redirects use {{see "shared concept"}}[entry-{index}] and {{seeAlso "reference-part-{part_index}"}}[entry-{index}].',
                "",
                *stress_lines,
                f"{{docstring {fq}.benchFn{index}}}",
                "",
                f"{{docstring {fq}.benchValue{index}}}",
                "",
                "{optionDocs pp.universes}",
                "",
                f"```anchor {anchor}",
                f"def helper{index} (n : Nat) : Nat :=",
                f"  n + {index}",
                f"#eval helper{index} {index + 2}",
                "```",
                f"```anchorInfo {anchor}",
                f"{2 * index + 2}",
                "```",
                "",
            ]
        )
    lines.append("")
    return "\n".join(lines)


def root_source(prefix: str, part_count: int) -> str:
    imports = "\n".join(f"import {prefix}.DocPart{part_index:02d}" for part_index in range(part_count))
    includes = "\n\n".join(f"{{include 0 {prefix}.DocPart{part_index:02d}}}" for part_index in range(part_count))
    return "\n".join(
        [
            "import VersoManual",
            imports,
            "",
            "open Verso.Genre Manual",
            "",
            "set_option maxRecDepth 100000",
            "set_option maxHeartbeats 0",
            "",
            f'#doc (Manual) "Reference-like benchmark" =>',
            "%%%",
            'tag := "bench-root"',
            'authors := ["Codex"]',
            'shortTitle := "Reference benchmark"',
            "%%%",
            "",
            "This synthetic manual is designed to look more like a reference-manual workload: multiple files, docstrings, external code anchors, cross-references, and JSON-emitting output steps.",
            "",
            includes,
            "",
        ]
    )


def remote_config_source(case_output: Path) -> str:
    return json.dumps(
        {
            "version": 0,
            "sources": {},
            "output": str(case_output / ".verso-remote"),
        },
        indent=2,
    )


def main_source(prefix: str, case_output: Path, remote_config: Path, mode: str) -> str:
    if mode == "immediate":
        emit_line = "  emitHtmlMulti := .immediately"
    elif mode == "delay":
        emit_line = f'  emitHtmlMulti := .delay "{case_output / "saved-state.json"}"'
    elif mode == "resume":
        emit_line = f'  emitHtmlMulti := .resumeFrom "{case_output / "saved-state.json"}"'
    else:
        raise ValueError(mode)
    return "\n".join(
        [
            "import VersoManual",
            f"import {prefix}.ManualRoot",
            "",
            "open Verso Genre Manual",
            "",
            "def config : Config where",
            f'  destination := "{case_output}"',
            "  emitTeX := false",
            "  emitHtmlSingle := .no",
            emit_line,
            "  htmlDepth := 2",
            "  verbose := true",
            f'  remoteConfigFile := some "{remote_config}"',
            "",
            f"def main := manualMain (%doc {prefix}.ManualRoot) (config := {{ config with }})",
            "",
        ]
    )


def write_case(size: int, doc_files: int, index_repeats: int) -> dict[str, object]:
    prefix = case_prefix(size)
    directory = case_dir(size)
    output_dir = directory / "_out"
    if directory.exists():
        shutil.rmtree(directory)
    ensure_dir(directory)

    part_count = min(max(1, doc_files), max(1, size))
    entries_per_part = size // part_count
    remainder = size % part_count

    api_path = directory / "Api.lean"
    api_path.write_text(api_module_source(prefix, size), encoding="utf-8")

    papers_path = directory / "Papers.lean"
    papers_path.write_text(papers_module_source(prefix, size), encoding="utf-8")

    examples_path = directory / "Examples.lean"
    examples_path.write_text(examples_module_source(prefix, size), encoding="utf-8")

    start = 0
    for part_index in range(part_count):
        count = entries_per_part + (1 if part_index < remainder else 0)
        stop = start + count
        path = directory / f"DocPart{part_index:02d}.lean"
        path.write_text(doc_part_source(prefix, size, part_index, start, stop, index_repeats), encoding="utf-8")
        start = stop

    root_path = directory / "ManualRoot.lean"
    root_path.write_text(root_source(prefix, part_count), encoding="utf-8")

    remote_path = directory / "remote.json"
    remote_path.write_text(remote_config_source(output_dir), encoding="utf-8")

    main_immediate_path = directory / "MainImmediate.lean"
    main_immediate_path.write_text(main_source(prefix, output_dir, remote_path, "immediate"), encoding="utf-8")

    main_delay_path = directory / "MainDelay.lean"
    main_delay_path.write_text(main_source(prefix, output_dir, remote_path, "delay"), encoding="utf-8")

    main_resume_path = directory / "MainResume.lean"
    main_resume_path.write_text(main_source(prefix, output_dir, remote_path, "resume"), encoding="utf-8")

    source_bytes = sum(path.stat().st_size for path in directory.iterdir() if path.suffix == ".lean")
    return {
        "prefix": prefix,
        "directory": directory,
        "root": root_path,
        "root_module": f"{prefix}.ManualRoot",
        "main_immediate": main_immediate_path,
        "main_delay": main_delay_path,
        "main_resume": main_resume_path,
        "remote": remote_path,
        "source_bytes": source_bytes,
        "doc_files": part_count,
        "index_repeats": index_repeats,
    }


TRAVERSAL_RE = re.compile(r"pass \d+ completed in (\d+) ms")


def parse_traversal_ms(stdout: str) -> int:
    return sum(int(match.group(1)) for match in TRAVERSAL_RE.finditer(stdout))


def file_size_or_zero(path: Path) -> int:
    return path.stat().st_size if path.exists() else 0


def clean_case_build(prefix: str) -> None:
    rel = Path(*str(prefix).split("."))
    for base in (ROOT / ".lake" / "build" / "lib" / "lean", ROOT / ".lake" / "build" / "ir"):
        target = base / rel
        if target.exists():
            shutil.rmtree(target)


def measure_case(size: int, repeats: int) -> dict[str, object]:
    raise RuntimeError("measure_case(size, repeats) should not be called directly")

def measure_case_with_files(size: int, doc_files: int, index_repeats: int, repeats: int) -> dict[str, object]:
    case = write_case(size, doc_files, index_repeats)
    compile_samples: list[float] = []
    runtime_samples: list[float] = []
    traversal_run_samples: list[float] = []
    resume_run_samples: list[float] = []
    traversal_samples: list[float] = []
    xref_sizes: list[int] = []
    docs_sizes: list[int] = []
    for _ in range(repeats):
        clean_case_build(case["prefix"])
        compile_cmd = ["lake", "build", case["root_module"]]
        elapsed_ms, proc = run_timed(compile_cmd)
        ensure_success(proc, compile_cmd)
        compile_samples.append(elapsed_ms)

        run_cmd = ["lake", "env", "lean", "--run", relative(case["main_immediate"])]
        elapsed_ms, proc = run_timed(run_cmd)
        ensure_success(proc, run_cmd)
        runtime_samples.append(elapsed_ms)
        traversal_samples.append(float(parse_traversal_ms(proc.stdout)))

        delay_cmd = ["lake", "env", "lean", "--run", relative(case["main_delay"])]
        elapsed_ms, proc = run_timed(delay_cmd)
        ensure_success(proc, delay_cmd)
        traversal_run_samples.append(elapsed_ms)

        resume_cmd = ["lake", "env", "lean", "--run", relative(case["main_resume"])]
        elapsed_ms, proc = run_timed(resume_cmd)
        ensure_success(proc, resume_cmd)
        resume_run_samples.append(elapsed_ms)

        html_multi = Path(case["directory"]) / "_out" / "html-multi"
        xref_sizes.append(file_size_or_zero(html_multi / "xref.json"))
        docs_sizes.append(file_size_or_zero(html_multi / "-verso-docs.json"))

    return {
        "sections": size,
        "doc_files": case["doc_files"],
        "index_repeats": case["index_repeats"],
        "source_bytes": case["source_bytes"],
        "repeats": repeats,
        "compile_ms": statistics.median(compile_samples),
        "manual_main_ms": statistics.median(runtime_samples),
        "traverse_save_ms": statistics.median(traversal_run_samples),
        "resume_emit_ms": statistics.median(resume_run_samples),
        "traversal_ms": statistics.median(traversal_samples),
        "xref_bytes": max(xref_sizes, default=0),
        "docs_json_bytes": max(docs_sizes, default=0),
    }


def write_csv(rows: list[dict[str, object]], path: Path) -> None:
    ensure_dir(path.parent)
    fieldnames = [
        "sections",
        "doc_files",
        "index_repeats",
        "source_bytes",
        "repeats",
        "compile_ms",
        "manual_main_ms",
        "traverse_save_ms",
        "resume_emit_ms",
        "traversal_ms",
        "xref_bytes",
        "docs_json_bytes",
    ]
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def svg_polyline(points: list[tuple[float, float]], color: str) -> str:
    path = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    circles = "\n".join(
        f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4" fill="{color}" />'
        for x, y in points
    )
    return f'<polyline fill="none" stroke="{color}" stroke-width="3" points="{path}" />\n{circles}'


def write_svg(rows: list[dict[str, object]], path: Path) -> None:
    ensure_dir(path.parent)
    width = 960
    height = 640
    margin_left = 90
    margin_right = 40
    margin_top = 80
    margin_bottom = 80
    plot_width = width - margin_left - margin_right
    plot_height = height - margin_top - margin_bottom

    use_doc_files_axis = len({int(row["sections"]) for row in rows}) == 1 and len({int(row["doc_files"]) for row in rows}) > 1
    x_key = "doc_files" if use_doc_files_axis else "sections"
    x_label = "Generated doc files" if use_doc_files_axis else "Synthetic entries"

    xs = [float(row[x_key]) for row in rows]
    ys = [
        float(row["compile_ms"])
        for row in rows
    ] + [
        float(row["manual_main_ms"])
        for row in rows
    ] + [
        float(row["traversal_ms"])
        for row in rows
    ]
    min_x, max_x = min(xs), max(xs)
    max_y = max(ys) * 1.1

    def x_scale(value: float) -> float:
        span = max_x - min_x
        if span == 0:
            return margin_left + plot_width / 2
        return margin_left + (value - min_x) / span * plot_width

    def y_scale(value: float) -> float:
        span = max_y
        if span == 0:
            return margin_top + plot_height / 2
        return margin_top + plot_height - value / span * plot_height

    def points(key: str) -> list[tuple[float, float]]:
        return [(x_scale(float(row[x_key])), y_scale(float(row[key]))) for row in rows]

    x_ticks = sorted(set(xs))
    y_ticks = [max_y * tick / 5 for tick in range(6)]

    grid = []
    labels = []
    for tick in x_ticks:
        x = x_scale(tick)
        grid.append(
            f'<line x1="{x:.1f}" y1="{margin_top}" x2="{x:.1f}" y2="{height - margin_bottom}" stroke="#e3e8ee" stroke-width="1" />'
        )
        labels.append(
            f'<text x="{x:.1f}" y="{height - margin_bottom + 28}" text-anchor="middle" font-size="14" fill="#2d3748">{int(tick)}</text>'
        )
    for tick in y_ticks:
        y = y_scale(tick)
        grid.append(
            f'<line x1="{margin_left}" y1="{y:.1f}" x2="{width - margin_right}" y2="{y:.1f}" stroke="#e3e8ee" stroke-width="1" />'
        )
        labels.append(
            f'<text x="{margin_left - 14}" y="{y + 5:.1f}" text-anchor="end" font-size="14" fill="#2d3748">{tick:.0f}</text>'
        )

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <rect width="{width}" height="{height}" fill="#f6fbf8" />
  <text x="{margin_left}" y="38" font-size="28" font-family="Georgia, serif" fill="#173b30">Reference-like Verso benchmark</text>
  <text x="{margin_left}" y="60" font-size="16" font-family="sans-serif" fill="#4a5568">Multi-file manual workload with docstrings, external code anchors, refs, index entries, and JSON-emitting manualMain output.</text>
  {''.join(grid)}
  <line x1="{margin_left}" y1="{height - margin_bottom}" x2="{width - margin_right}" y2="{height - margin_bottom}" stroke="#334155" stroke-width="2" />
  <line x1="{margin_left}" y1="{margin_top}" x2="{margin_left}" y2="{height - margin_bottom}" stroke="#334155" stroke-width="2" />
  {''.join(labels)}
  {svg_polyline(points("compile_ms"), "#8c3d3d")}
  {svg_polyline(points("manual_main_ms"), "#1d5c63")}
  {svg_polyline(points("traversal_ms"), "#b2832f")}
  <text x="{margin_left + 24}" y="{margin_top + 18}" font-size="16" font-family="sans-serif" fill="#8c3d3d">Compile root doc modules</text>
  <text x="{margin_left + 24}" y="{margin_top + 42}" font-size="16" font-family="sans-serif" fill="#1d5c63">manualMain runtime</text>
  <text x="{margin_left + 24}" y="{margin_top + 66}" font-size="16" font-family="sans-serif" fill="#b2832f">Traversal time parsed from verbose output</text>
  <text x="{margin_left + plot_width / 2:.1f}" y="{height - 24}" text-anchor="middle" font-size="16" font-family="sans-serif" fill="#334155">{x_label}</text>
  <text x="26" y="{margin_top + plot_height / 2:.1f}" transform="rotate(-90 26 {margin_top + plot_height / 2:.1f})" text-anchor="middle" font-size="16" font-family="sans-serif" fill="#334155">Median time (ms)</text>
</svg>
"""
    path.write_text(svg, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Benchmark a reference-like multi-file Verso manual workload.")
    parser.add_argument("--sizes", nargs="+", type=int, default=DEFAULT_SIZES, help="Synthetic entry counts to benchmark.")
    parser.add_argument("--doc-files", nargs="+", type=int, default=[DOC_FILE_COUNT], help="Number of generated doc files to use for each size.")
    parser.add_argument("--index-repeats", type=int, default=DEFAULT_INDEX_REPEATS, help="Extra repeated index/see insertions per item.")
    parser.add_argument("--repeats", type=int, default=1, help="Repeats per data point.")
    parser.add_argument("--label", default="current", help="Result subdirectory label.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    out_dir = OUT_ROOT / args.label
    ensure_dir(out_dir)
    rows = [
        measure_case_with_files(size, doc_files, args.index_repeats, args.repeats)
        for size in args.sizes
        for doc_files in args.doc_files
        if doc_files <= max(1, size)
    ]
    rows.sort(key=lambda row: (int(row["sections"]), int(row["doc_files"])))

    csv_path = out_dir / "results.csv"
    svg_path = out_dir / "time_vs_size.svg"
    summary_path = out_dir / "summary.json"

    write_csv(rows, csv_path)
    write_svg(rows, svg_path)
    summary_path.write_text(
        json.dumps(
            {
                "sizes": args.sizes,
                "doc_files": args.doc_files,
                "index_repeats": args.index_repeats,
                "repeats": args.repeats,
                "label": args.label,
                "csv": str(csv_path),
                "svg": str(svg_path),
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    print(f"Wrote {csv_path}")
    print(f"Wrote {svg_path}")


if __name__ == "__main__":
    main()
