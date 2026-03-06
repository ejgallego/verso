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


def default_site_root() -> Path:
    repo_root = Path(__file__).resolve().parents[2]
    candidates = [repo_root / "_out" / "html-multi"]
    if repo_root.parent.name == ".worktrees":
        candidates.append(repo_root.parents[1] / "_out" / repo_root.name / "html-multi")
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0]


def main() -> int:
    out_root = default_site_root()
    local_theorem = load(out_root / "The-Local-Theorem" / "index.html")
    global_theorem = load(out_root / "The-Global-Theorem" / "index.html")
    bounding = load(out_root / "Bounding-Rotations" / "index.html")

    if "bp_external_status_badge_summary bp_external_status_ok" not in local_theorem:
        fail("missing external summary badge in The-Local-Theorem")
    if "bp_external_status_badge_summary bp_external_status_sorry" not in global_theorem:
        fail("missing external warning summary badge in The-Global-Theorem")
    if "External Lean for Lemma" in local_theorem:
        fail("stale external panel caption still present in The-Local-Theorem")
    if "Code for Lemma" not in local_theorem:
        fail("external panel caption not updated in The-Local-Theorem")
    if 'bp_external_status_badge_text">1 theorem<' not in local_theorem:
        fail("missing theorem-specific external summary text in The-Local-Theorem")
    if 'bp_external_status_badge_text">1 definition<' not in local_theorem:
        fail("missing definition-specific external summary text in The-Local-Theorem")
    if "bp-renderer-select" in local_theorem:
        fail("stale external renderer switcher still present in The-Local-Theorem")
    if "bp_code_expand_hint" in local_theorem:
        fail("stale expand hint markup still present in The-Local-Theorem")

    panel_re = re.compile(r'<details class="bp_code_block bp_code_panel"[^>]*>.*?</details>', re.S)
    external_panels = [p for p in panel_re.findall(local_theorem) if "bp_external_status_badge_summary" in p]
    external_panels += [p for p in panel_re.findall(global_theorem) if "bp_external_status_badge_summary" in p]
    if not external_panels:
        fail("no external code panels found in theorem pages")

    for i, panel in enumerate(external_panels, start=1):
        if "bp_code_progress" in panel:
            fail(f"external panel #{i} still renders a progress bar")
        if 'class="namedocs"' in panel:
            fail(f"external panel #{i} still includes nested namedocs wrapper")
        if "bp_external_decl_renderer_variant" in panel:
            fail(f"external panel #{i} still includes renderer variants")
        if "data-bp-external-renderer" in panel:
            fail(f"external panel #{i} still includes renderer mode attributes")
        if "bp_external_decl_signature" not in panel:
            fail(f"external panel #{i} missing external signature block")
        if '<span class="keyword token">theorem</span>' not in panel and '<span class="keyword token">def</span>' not in panel:
            fail(f"external panel #{i} missing declaration keyword prefix")

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
