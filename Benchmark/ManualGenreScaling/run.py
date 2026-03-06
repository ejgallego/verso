#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import math
import os
import statistics
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BENCH_DIR = ROOT / "Benchmark" / "ManualGenreScaling"
GENERATED_DIR = BENCH_DIR / "Generated"
OUT_DIR = ROOT / "_out" / "perf" / "manual_genre_scaling"
TRAVERSE_SCRIPT = BENCH_DIR / "Traverse.lean"

DEFAULT_SIZES = [25, 50, 100, 200, 400, 800]
ELAB_REPEATS = 3
TRAVERSE_REPEATS = 5


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def generated_source(sections: int) -> str:
    body = []
    for index in range(sections):
        body.extend(
            [
                f"# Section {index}",
                "",
                f"This benchmark section {index} includes _emphasis_, *bold text*, and `code-{index}` so the elaborator sees a nontrivial inline tree.",
                "",
                f"A second paragraph in section {index} repeats the same structure to stress incremental `#doc` elaboration on larger manuals.",
                "",
                f"## Detail {index}",
                "",
                f"Subsection {index} adds another paragraph with `detail-{index}` and a bit more prose to keep traversal work proportional to size.",
                "",
            ]
        )
    body_text = "\n".join(body)
    return (
        "import VersoManual\n\n"
        "open Verso Doc Genre Manual\n\n"
        "set_option maxRecDepth 100000\n"
        "set_option maxHeartbeats 0\n\n"
        f"#doc (Manual) \"Synthetic elaboration benchmark ({sections} sections)\" =>\n\n"
        f"{body_text}\n"
    )


def source_path_for(sections: int) -> Path:
    return GENERATED_DIR / f"S{sections:04d}.lean"


def write_source(sections: int) -> dict[str, int | str]:
    ensure_dir(GENERATED_DIR)
    text = generated_source(sections)
    path = source_path_for(sections)
    path.write_text(text, encoding="utf-8")
    return {
        "path": str(path),
        "source_bytes": len(text.encode("utf-8")),
        "source_lines": text.count("\n"),
    }


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
    joined = " ".join(cmd)
    sys.stderr.write(f"Command failed: {joined}\n")
    if proc.stdout:
        sys.stderr.write(proc.stdout)
    if proc.stderr:
        sys.stderr.write(proc.stderr)
    raise SystemExit(proc.returncode)


def warm_elaboration_cache() -> None:
    info = write_source(1)
    cmd = ["lake", "env", "lean", str(Path(info["path"]).relative_to(ROOT))]
    _, proc = run_timed(cmd)
    ensure_success(proc, cmd)


def measure_elaboration(sizes: list[int], repeats: int) -> list[dict[str, object]]:
    warm_elaboration_cache()
    rows: list[dict[str, object]] = []
    for sections in sizes:
        info = write_source(sections)
        path = Path(info["path"]).relative_to(ROOT)
        samples: list[float] = []
        for _ in range(repeats):
            elapsed_ms, proc = run_timed(["lake", "env", "lean", str(path)])
            ensure_success(proc, ["lake", "env", "lean", str(path)])
            samples.append(elapsed_ms)
        rows.append(
            {
                "kind": "elaboration",
                "sections": sections,
                "source_bytes": info["source_bytes"],
                "source_lines": info["source_lines"],
                "repeats": repeats,
                "median_ms": statistics.median(samples),
                "mean_ms": statistics.mean(samples),
                "min_ms": min(samples),
                "max_ms": max(samples),
            }
        )
    return rows


def measure_traversal(sizes: list[int], repeats: int) -> list[dict[str, object]]:
    cmd = [
        "lake",
        "env",
        "lean",
        "--run",
        str(TRAVERSE_SCRIPT.relative_to(ROOT)),
        str(repeats),
        *[str(size) for size in sizes],
    ]
    _, proc = run_timed(cmd)
    ensure_success(proc, cmd)
    reader = csv.DictReader(proc.stdout.strip().splitlines())
    rows: list[dict[str, object]] = []
    for row in reader:
        rows.append(
            {
                "kind": "traversal",
                "sections": int(row["sections"]),
                "parts": int(row["parts"]),
                "blocks": int(row["blocks"]),
                "inlines": int(row["inlines"]),
                "repeats": int(row["repeats"]),
                "median_ms": float(row["median_ms"]),
                "mean_ms": float(row["mean_ms"]),
                "min_ms": float(row["min_ms"]),
                "max_ms": float(row["max_ms"]),
            }
        )
    return rows


def fit_power_law(rows: list[dict[str, object]]) -> dict[str, float]:
    if len(rows) < 2:
        return {"slope": float("nan"), "intercept": float("nan")}
    xs = [math.log(float(row["sections"])) for row in rows]
    ys = [math.log(float(row["median_ms"])) for row in rows]
    mean_x = sum(xs) / len(xs)
    mean_y = sum(ys) / len(ys)
    denom = sum((x - mean_x) ** 2 for x in xs)
    slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys)) / denom
    intercept = mean_y - slope * mean_x
    return {"slope": slope, "intercept": intercept}


def write_csv(rows: list[dict[str, object]], path: Path) -> None:
    ensure_dir(path.parent)
    fieldnames = [
        "kind",
        "sections",
        "source_bytes",
        "source_lines",
        "parts",
        "blocks",
        "inlines",
        "repeats",
        "median_ms",
        "mean_ms",
        "min_ms",
        "max_ms",
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


def write_svg(
    elab_rows: list[dict[str, object]],
    trav_rows: list[dict[str, object]],
    elab_fit: dict[str, float],
    trav_fit: dict[str, float],
    path: Path,
) -> None:
    ensure_dir(path.parent)
    width = 960
    height = 640
    margin_left = 90
    margin_right = 40
    margin_top = 80
    margin_bottom = 80
    plot_width = width - margin_left - margin_right
    plot_height = height - margin_top - margin_bottom

    all_sections = [float(row["sections"]) for row in elab_rows + trav_rows]
    all_times = [float(row["median_ms"]) for row in elab_rows + trav_rows]
    min_x, max_x = min(all_sections), max(all_sections)
    min_y, max_y = 0.0, max(all_times) * 1.1

    def x_scale(value: float) -> float:
        span = max_x - min_x
        if span == 0:
            return margin_left + plot_width / 2
        return margin_left + (value - min_x) / span * plot_width

    def y_scale(value: float) -> float:
        span = max_y - min_y
        if span == 0:
            return margin_top + plot_height / 2
        return margin_top + plot_height - (value - min_y) / span * plot_height

    x_ticks = sorted(set(all_sections))
    y_ticks = [max_y * tick / 5 for tick in range(6)]

    def points(rows: list[dict[str, object]]) -> list[tuple[float, float]]:
        return [(x_scale(float(row["sections"])), y_scale(float(row["median_ms"]))) for row in rows]

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
  <rect width="{width}" height="{height}" fill="#fbfaf6" />
  <text x="{margin_left}" y="38" font-size="28" font-family="Georgia, serif" fill="#14213d">Verso manual scaling benchmark</text>
  <text x="{margin_left}" y="60" font-size="16" font-family="sans-serif" fill="#4a5568">Median time vs synthetic section count, single-threaded. Elaboration uses generated #doc sources; traversal uses synthetic Part Manual values.</text>
  {''.join(grid)}
  <line x1="{margin_left}" y1="{height - margin_bottom}" x2="{width - margin_right}" y2="{height - margin_bottom}" stroke="#334155" stroke-width="2" />
  <line x1="{margin_left}" y1="{margin_top}" x2="{margin_left}" y2="{height - margin_bottom}" stroke="#334155" stroke-width="2" />
  {''.join(labels)}
  {svg_polyline(points(elab_rows), "#b5651d")}
  {svg_polyline(points(trav_rows), "#1d4d6b")}
  <text x="{margin_left + 24}" y="{margin_top + 18}" font-size="16" font-family="sans-serif" fill="#b5651d">Elaboration median, exponent ≈ {elab_fit["slope"]:.2f}</text>
  <text x="{margin_left + 24}" y="{margin_top + 42}" font-size="16" font-family="sans-serif" fill="#1d4d6b">Traversal median, exponent ≈ {trav_fit["slope"]:.2f}</text>
  <text x="{margin_left + plot_width / 2:.1f}" y="{height - 24}" text-anchor="middle" font-size="16" font-family="sans-serif" fill="#334155">Synthetic sections</text>
  <text x="26" y="{margin_top + plot_height / 2:.1f}" transform="rotate(-90 26 {margin_top + plot_height / 2:.1f})" text-anchor="middle" font-size="16" font-family="sans-serif" fill="#334155">Median time (ms)</text>
</svg>
"""
    path.write_text(svg, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Measure Verso manual elaboration and traversal scaling.")
    parser.add_argument("--sizes", nargs="+", type=int, default=DEFAULT_SIZES, help="Synthetic section counts to benchmark.")
    parser.add_argument("--elab-repeats", type=int, default=ELAB_REPEATS, help="Repetitions per elaboration data point.")
    parser.add_argument("--traverse-repeats", type=int, default=TRAVERSE_REPEATS, help="Repetitions per traversal data point.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    sizes = args.sizes
    ensure_dir(OUT_DIR)
    elaboration_rows = measure_elaboration(sizes, args.elab_repeats)
    traversal_rows = measure_traversal(sizes, args.traverse_repeats)
    all_rows = elaboration_rows + traversal_rows

    csv_path = OUT_DIR / "results.csv"
    svg_path = OUT_DIR / "time_vs_sections.svg"
    summary_path = OUT_DIR / "summary.json"

    write_csv(all_rows, csv_path)
    elab_fit = fit_power_law(elaboration_rows)
    trav_fit = fit_power_law(traversal_rows)
    write_svg(elaboration_rows, traversal_rows, elab_fit, trav_fit, svg_path)

    summary = {
        "sizes": sizes,
        "elaboration_repeats": args.elab_repeats,
        "traversal_repeats": args.traverse_repeats,
        "elaboration_power_law": elab_fit,
        "traversal_power_law": trav_fit,
        "csv": str(csv_path),
        "svg": str(svg_path),
    }
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(f"Wrote {csv_path}")
    print(f"Wrote {svg_path}")
    print(f"Elaboration exponent: {elab_fit['slope']:.3f}")
    print(f"Traversal exponent: {trav_fit['slope']:.3f}")


if __name__ == "__main__":
    main()
