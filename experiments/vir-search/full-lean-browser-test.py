import json
import statistics
import sys

from playwright.sync_api import sync_playwright


if len(sys.argv) != 2:
    raise SystemExit("usage: full-lean-browser-test.py URL")

with sync_playwright() as playwright:
    browser = playwright.chromium.launch()
    page = browser.new_page()
    console_errors = []
    page.on("console", lambda message: console_errors.append(message.text) if message.type == "error" else None)
    page.goto(sys.argv[1], wait_until="networkidle")
    page.locator("#verso-full-lean-search").wait_for(state="visible")
    page.wait_for_function(
        "document.querySelector('#verso-full-lean-search')?.dataset.leanSearchState === 'ready'"
    )
    entry_status = page.locator("#verso-full-lean-status").text_content()
    reference = page.evaluate(
        """async () => {
            const [{domainMappers}, {buildSearchableMap}] = await Promise.all([
                import('/-verso-search/domain-mappers.js'),
                import('/-verso-search/search-box.js'),
            ]);
            const data = JSON.parse(document.querySelector('#verso-full-lean-xref').textContent);
            const mapped = buildSearchableMap(data, domainMappers);
            const keys = Object.keys(mapped);
            const prepared = keys.map(name => window.fuzzysort.prepare(name));
            window.__fullLeanReference = {mapped, prepared};
            return {
                keys: prepared.length,
                items: Object.values(mapped).reduce((count, values) => count + values.length, 0),
                asciiKeys: keys.filter(key => /^[\x00-\x7f]*$/.test(key)).length,
                maxCodePoints: Math.max(...keys.map(key => [...key].length)),
            };
        }"""
    )

    timings = []
    timings_by_query = {}
    queries = ["websites", "markup", "lean", "site config", "html", "manual", "positional'"]
    for query in queries * 3:
        measurement = page.evaluate(
            """query => {
                const input = document.querySelector('#verso-full-lean-query');
                input.value = query;
                const start = performance.now();
                input.dispatchEvent(new Event('input', {bubbles: true}));
                return {
                    elapsedMs: performance.now() - start,
                    count: Number(document.querySelector('#verso-full-lean-results').dataset.resultCount),
                    keys: [...document.querySelectorAll('#verso-full-lean-results a')]
                        .map(link => link.dataset.searchKey),
                    highlighted: document.querySelector('#verso-full-lean-results em')?.textContent ?? null,
                };
            }""",
            query,
        )
        assert measurement["count"] > 0, measurement
        assert measurement["keys"], measurement
        assert measurement["highlighted"] is not None, measurement
        reference_keys = page.evaluate(
            """query => window.fuzzysort
                .go(query, window.__fullLeanReference.prepared, {threshold: 0.25})
                .flatMap(result => window.__fullLeanReference.mapped[result.target]
                    .map(item => item.searchKey))
                .slice(0, 30)""",
            query,
        )
        # Fuzzysort's bounded heap does not preserve source order inside exact-score ties. The Lean
        # lane deliberately uses a stable bounded insertion, so compare the winner and admitted set.
        assert measurement["keys"][:4] == reference_keys[:4], {
            "query": query,
            "leanLeaders": measurement["keys"][:4],
            "javascriptLeaders": reference_keys[:4],
        }
        overlap = len(set(measurement["keys"]) & set(reference_keys))
        assert overlap >= min(len(measurement["keys"]), len(reference_keys)) - 1, {
            "query": query,
            "lean": measurement["keys"],
            "javascript": reference_keys,
            "overlap": overlap,
        }
        timings.append(measurement["elapsedMs"])
        timings_by_query.setdefault(query, []).append(measurement["elapsedMs"])

    javascript_timings = page.evaluate(
        """queries => {
            const timings = [];
            for (const query of queries) {
                window.fuzzysort.go(query, window.__fullLeanReference.prepared, {threshold: 0.25});
                const repetitions = 200;
                const start = performance.now();
                for (let i = 0; i < repetitions; ++i) {
                    window.fuzzysort.go(query, window.__fullLeanReference.prepared, {threshold: 0.25});
                }
                timings.push((performance.now() - start) / repetitions);
            }
            return timings;
        }""",
        ["websites", "markup", "lean"],
    )

    assert not console_errors, console_errors
    print(
        json.dumps(
            {
                "state": page.locator("#verso-full-lean-search").get_attribute(
                    "data-lean-search-state"
                ),
                "entries": entry_status,
                "referenceItems": reference["items"],
                "referenceKeys": reference["keys"],
                "referenceAsciiKeys": reference["asciiKeys"],
                "referenceMaxCodePoints": reference["maxCodePoints"],
                "medianQueryMs": statistics.median(timings),
                "maxQueryMs": max(timings),
                "medianByQueryMs": {
                    query: statistics.median(values) for query, values in timings_by_query.items()
                },
                "javascriptFuzzysortMedianMs": statistics.median(javascript_timings),
                "queries": len(timings),
            }
        )
    )
    browser.close()
