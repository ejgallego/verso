import argparse
import hashlib
import json
import statistics
from pathlib import Path

from playwright.sync_api import sync_playwright


QUERIES = ["websites", "markup", "lean", "site config", "html", "manual", "zzzzzz"]
EDIT_SEQUENCES = {
    "lean": ["l", "le", "lea", "lean", "lea", "lean", "le", "lean"],
    "manual": ["m", "ma", "man", "manu", "manua", "manual", "manua", "manual"],
}
FULL_LEAN_SOURCE = Path(__file__).parent / "VersoSearchVir/FullLean.lean"


def wait_until_ready(page, url):
    page.goto(url, wait_until="domcontentloaded")
    page.wait_for_function(
        "document.querySelector('#verso-full-lean-search')?.dataset.leanSearchState === 'ready'"
    )
    return page.evaluate("performance.now()")


def dispatch(page, query):
    return page.evaluate(
        """query => {
            const input = document.querySelector('#verso-full-lean-query');
            input.value = query;
            const started = performance.now();
            input.dispatchEvent(new Event('input', {bubbles: true}));
            return {
                elapsedMs: performance.now() - started,
                count: Number(
                    document.querySelector('#verso-full-lean-results').dataset.resultCount
                ),
            };
        }""",
        query,
    )


def measure_page(browser, label, url, pass_index, warm_repetitions):
    page = browser.new_page()
    startup_ms = wait_until_ready(page, url)
    rows = []
    for query in QUERIES:
        for repetition in range(warm_repetitions + 1):
            result = dispatch(page, query)
            rows.append(
                {
                    "label": label,
                    "pass": pass_index,
                    "query": query,
                    "phase": "cold" if repetition == 0 else "repeat",
                    "repetition": repetition,
                    **result,
                }
            )
    page.close()
    return startup_ms, rows


def measure_edit_sequences(browser, label, url, pass_index):
    rows = []
    for sequence_name, queries in EDIT_SEQUENCES.items():
        page = browser.new_page()
        wait_until_ready(page, url)
        seen = set()
        for step, query in enumerate(queries):
            result = dispatch(page, query)
            rows.append(
                {
                    "label": label,
                    "pass": pass_index,
                    "sequence": sequence_name,
                    "step": step,
                    "query": query,
                    "phase": "revisit" if query in seen else "forward",
                    **result,
                }
            )
            seen.add(query)
        page.close()
    return rows


DOM_COUNTERS = """
(() => {
    const counts = Object.create(null);
    const bump = name => counts[name] = (counts[name] || 0) + 1;
    const wrapMethod = (prototype, name, label) => {
        const original = prototype[name];
        prototype[name] = function (...args) {
            bump(label);
            return original.apply(this, args);
        };
    };
    const wrapSetter = (prototype, name, label) => {
        const descriptor = Object.getOwnPropertyDescriptor(prototype, name);
        Object.defineProperty(prototype, name, {
            ...descriptor,
            set(value) {
                bump(label);
                return descriptor.set.call(this, value);
            },
        });
    };
    wrapMethod(Document.prototype, 'createElement', 'createElement');
    wrapMethod(Element.prototype, 'setAttribute', 'setAttribute');
    wrapMethod(Node.prototype, 'appendChild', 'appendChild');
    wrapMethod(DOMTokenList.prototype, 'add', 'classList.add');
    wrapSetter(Node.prototype, 'textContent', 'textContent');
    wrapSetter(Element.prototype, 'innerHTML', 'innerHTML');
    window.__versoVirDomCounts = counts;
    window.__resetVersoVirDomCounts = () => {
        for (const key of Object.keys(counts)) delete counts[key];
    };
})();
"""


def boundary_diagnostics(browser, label, url):
    page = browser.new_page()
    page.add_init_script(DOM_COUNTERS)
    wait_until_ready(page, url)
    rows = []
    for query in ["websites", "lean", "manual"]:
        for phase in ["cold", "repeat"]:
            page.evaluate("window.__resetVersoVirDomCounts()")
            result = dispatch(page, query)
            result["label"] = label
            result["query"] = query
            result["phase"] = phase
            result["domOperations"] = page.evaluate("({...window.__versoVirDomCounts})")
            result["domOperationTotal"] = sum(result["domOperations"].values())
            rows.append(result)
    page.close()
    return rows


def sampled_profile(browser, label, url, profile_dir):
    page = browser.new_page()
    wait_until_ready(page, url)
    session = page.context.new_cdp_session(page)
    session.send("Profiler.enable")
    session.send("Profiler.setSamplingInterval", {"interval": 100})
    session.send("Profiler.start")
    for _ in range(8):
        for query in QUERIES[:-1]:
            dispatch(page, query)
    profile = session.send("Profiler.stop")["profile"]
    session.send("Profiler.disable")
    page.close()

    profile_path = profile_dir / f"{label}.cpuprofile"
    profile_path.write_text(json.dumps(profile), encoding="utf-8")
    aggregated = {}
    for node in profile["nodes"]:
        frame = node["callFrame"]
        key = (frame["functionName"], frame["url"], frame["lineNumber"] + 1)
        aggregated[key] = aggregated.get(key, 0) + node.get("hitCount", 0)
    hottest = []
    for (function, url, line), samples in sorted(
        aggregated.items(), key=lambda item: item[1], reverse=True
    ):
        if not samples:
            continue
        hottest.append(
            {
                "samples": samples,
                "function": function,
                "url": url,
                "line": line,
            }
        )
        if len(hottest) == 12:
            break
    return {
        "raw": str(profile_path),
        "sampleCount": len(profile.get("samples", [])),
        "hottest": hottest,
    }


def cold_sampled_profile(browser, label, url, profile_dir, repetitions):
    aggregated = {}
    sample_count = 0
    raw_profiles = []
    for repetition in range(repetitions):
        for query_index, query in enumerate(QUERIES):
            page = browser.new_page()
            wait_until_ready(page, url)
            session = page.context.new_cdp_session(page)
            session.send("Profiler.enable")
            session.send("Profiler.setSamplingInterval", {"interval": 100})
            session.send("Profiler.start")
            dispatch(page, query)
            profile = session.send("Profiler.stop")["profile"]
            session.send("Profiler.disable")
            page.close()

            raw_path = profile_dir / f"{label}-cold-{repetition}-{query_index}.cpuprofile"
            raw_path.write_text(json.dumps(profile), encoding="utf-8")
            raw_profiles.append(str(raw_path))
            sample_count += len(profile.get("samples", []))
            for node in profile["nodes"]:
                frame = node["callFrame"]
                key = (frame["functionName"], frame["url"], frame["lineNumber"] + 1)
                aggregated[key] = aggregated.get(key, 0) + node.get("hitCount", 0)

    hottest = [
        {"samples": samples, "function": function, "url": frame_url, "line": line}
        for (function, frame_url, line), samples in sorted(
            aggregated.items(), key=lambda item: item[1], reverse=True
        )
        if samples
    ][:12]
    return {"raw": raw_profiles, "sampleCount": sample_count, "hottest": hottest}


def target_identity(browser, label, url):
    page = browser.new_page()
    wait_until_ready(page, url)
    identity = page.evaluate(
        """async () => {
            const hex = buffer => [...new Uint8Array(buffer)]
                .map(byte => byte.toString(16).padStart(2, '0')).join('');
            const digest = async resource => {
                const response = await fetch(resource);
                const bytes = await response.arrayBuffer();
                return {
                    bytes: bytes.byteLength,
                    sha256: hex(await crypto.subtle.digest('SHA-256', bytes)),
                };
            };
            const config = document.querySelector('script[data-vir-package-set][data-vir-wasm]');
            const packageSetUrl = new URL(config.dataset.virPackageSet, location.href);
            const packageSet = await (await fetch(packageSetUrl)).json();
            const fullLeanPackage = packageSet.packages.find(
                pkg => pkg.module === 'VersoSearchVir.FullLean'
            );
            const [{domainMappers}, {buildSearchableMap}] = await Promise.all([
                import('/-verso-search/domain-mappers.js'),
                import('/-verso-search/search-box.js'),
            ]);
            const xref = JSON.parse(
                document.querySelector('#verso-full-lean-xref').textContent
            );
            const mapped = buildSearchableMap(xref, domainMappers);
            const keys = Object.values(mapped).flat().map(item => item.searchKey);
            const asciiKeys = keys.filter(key => /^[\x00-\x7f]*$/.test(key));
            return {
                url: location.href,
                userAgent: navigator.userAgent,
                xref: await digest('/xref.json'),
                packageSet: await digest(config.dataset.virPackageSet),
                fullLeanPackage: await digest(new URL(fullLeanPackage.path, packageSetUrl)),
                wasm: await digest(config.dataset.virWasm),
                dataset: {
                    keys: keys.length,
                    asciiKeys: asciiKeys.length,
                    totalCodePoints: keys.reduce((sum, key) => sum + [...key].length, 0),
                    maxCodePoints: Math.max(...keys.map(key => [...key].length)),
                    nonAsciiExamples: keys.filter(key => !/^[\x00-\x7f]*$/.test(key)).slice(0, 5),
                },
            };
        }"""
    )
    page.close()
    return {"label": label, **identity}


def summarize(rows, phase):
    selected = [row["elapsedMs"] for row in rows if row["phase"] == phase]
    by_query = {}
    for query in QUERIES:
        values = [
            row["elapsedMs"]
            for row in rows
            if row["phase"] == phase and row["query"] == query
        ]
        by_query[query] = {
            "medianMs": statistics.median(values),
            "minMs": min(values),
            "maxMs": max(values),
        }
    return {"medianMs": statistics.median(selected), "byQuery": by_query}


def summarize_phase_totals(rows):
    grouped = {}
    for row in rows:
        key = (row["label"], row["phase"], row["pass"])
        grouped[key] = grouped.get(key, 0.0) + row["elapsedMs"]

    summaries = []
    phases = sorted({(label, phase) for label, phase, _ in grouped})
    for label, phase in phases:
        totals = [
            {"pass": pass_index, "elapsedMs": grouped[(label, phase, pass_index)]}
            for grouped_label, grouped_phase, pass_index in sorted(grouped)
            if grouped_label == label and grouped_phase == phase
        ]
        summaries.append(
            {
                "label": label,
                "phase": phase,
                "perPass": totals,
                "medianMs": statistics.median(row["elapsedMs"] for row in totals),
            }
        )
    return summaries


parser = argparse.ArgumentParser()
parser.add_argument("targets", nargs="+", metavar="LABEL=URL")
parser.add_argument("--passes", type=int, default=2)
parser.add_argument("--warm-repetitions", type=int, default=4)
parser.add_argument("--cold-profile-repetitions", type=int, default=2)
parser.add_argument("--profile-dir", type=Path, required=True)
parser.add_argument("--json-out", type=Path)
args = parser.parse_args()

targets = []
for target in args.targets:
    label, separator, url = target.partition("=")
    if not separator:
        parser.error(f"target must be LABEL=URL: {target}")
    targets.append((label, url))

args.profile_dir.mkdir(parents=True, exist_ok=True)
with sync_playwright() as playwright:
    browser = playwright.chromium.launch()
    browser_version = browser.version
    timing_rows = []
    edit_rows = []
    startup_rows = []
    for pass_index in range(args.passes):
        ordered = targets if pass_index % 2 == 0 else list(reversed(targets))
        for sequence, (label, url) in enumerate(ordered):
            startup_ms, rows = measure_page(
                browser, label, url, pass_index, args.warm_repetitions
            )
            startup_rows.append(
                {
                    "label": label,
                    "pass": pass_index,
                    "sequence": sequence,
                    "elapsedMs": startup_ms,
                }
            )
            timing_rows.extend(rows)
            edit_rows.extend(measure_edit_sequences(browser, label, url, pass_index))
    diagnostics = {
        label: {
            "boundary": boundary_diagnostics(browser, label, url),
            "warmProfile": sampled_profile(browser, label, url, args.profile_dir),
            "coldProfile": cold_sampled_profile(
                browser, label, url, args.profile_dir, args.cold_profile_repetitions
            ),
        }
        for label, url in targets
    }
    identities = [target_identity(browser, label, url) for label, url in targets]
    browser.close()

summary = {}
for label, _ in targets:
    label_rows = [row for row in timing_rows if row["label"] == label]
    startups = [row["elapsedMs"] for row in startup_rows if row["label"] == label]
    summary[label] = {
        "startupMedianMs": statistics.median(startups),
        "cold": summarize(label_rows, "cold"),
        "repeat": summarize(label_rows, "repeat"),
        "editSequence": {
            phase: {
                "medianMs": statistics.median(
                    row["elapsedMs"]
                    for row in edit_rows
                    if row["label"] == label and row["phase"] == phase
                )
            }
            for phase in ["forward", "revisit"]
        },
    }

report = {
    "identity": {
        "browser": browser_version,
        "harnessSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "fullLeanSourceSha256": hashlib.sha256(FULL_LEAN_SOURCE.read_bytes()).hexdigest(),
        "targets": identities,
    },
    "workload": {
        "queries": QUERIES,
        "passes": args.passes,
        "warmRepetitions": args.warm_repetitions,
        "coldProfileRepetitions": args.cold_profile_repetitions,
        "order": "AB/BA" if len(targets) == 2 else "single target",
    },
    "summary": summary,
    "phaseTotals": {
        "query": summarize_phase_totals(timing_rows),
        "editSequence": summarize_phase_totals(edit_rows),
    },
    "startupRows": startup_rows,
    "timingRows": timing_rows,
    "editRows": edit_rows,
    "diagnostics": diagnostics,
}
rendered = json.dumps(report, indent=2)
if args.json_out:
    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(rendered + "\n", encoding="utf-8")
print(
    json.dumps(
        {
            "workload": report["workload"],
            "summary": report["summary"],
            "profiles": {
                label: {
                    "warm": diagnostics[label]["warmProfile"]["raw"],
                    "cold": diagnostics[label]["coldProfile"]["raw"],
                }
                for label, _ in targets
            },
            "fullReport": str(args.json_out) if args.json_out else None,
        },
        indent=2,
    )
)
