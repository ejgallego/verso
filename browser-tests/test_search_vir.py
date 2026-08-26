"""Browser-boundary tests for the optional VIR search provider.

The real Lean package is exercised by ``experiments/vir-search/smoke.mjs``. These tests focus on
the JavaScript adapter: scalar hit marshalling, source-object rehydration, and mapper fallback.
"""

import json

import pytest
from playwright.sync_api import Page


SEARCH_BOX_PATH = "/-verso-search/search-box.js"


def test_real_vir_provider_when_assets_are_staged(server: str, page: Page):
    """Exercise Wasm, package loading, mapper, and ranker when the experiment is staged."""
    page.goto(server)
    result = page.evaluate(
        """async () => {
            if (!window.versoSearchVir) return null;
            const {loadSearchVirProvider} = await import('/-verso-search/vir-search.js');
            const {domainMappers} = await import('/-verso-search/domain-mappers.js');
            const provider = await loadSearchVirProvider();
            if (!provider) throw new Error('configured VIR provider did not initialize');
            const mapped = provider.mapDomain('Verso.Genre.Manual.section', {
                contents: {
                    intro: [{
                        address: '/guide/',
                        id: 'intro',
                        data: {sectionNum: '1.', title: 'Introduction', searchPriority: 75},
                    }],
                },
            });
            const ranked = provider.rankCandidates(
                [
                    {
                        sourceIndex: 0, rawScore: 0.5, semanticPriority: 75,
                        domainPriority: 75, itemPriority: null,
                    },
                    {
                        sourceIndex: 1, rawScore: 0.9, semanticPriority: null,
                        domainPriority: null, itemPriority: null,
                    },
                ],
                [{
                    sourceIndex: 0, rawScore: 2, fullTextPriority: null,
                    documentPriority: null,
                }],
            );
            const xref = await fetch('/xref.json').then((response) => response.json());
            const supportedDomains = [
                'VersoHtml.module',
                'Verso.Genre.Manual.doc',
                'Verso.Genre.Manual.doc.option',
                'VersoHtml.constant',
                'Verso.Genre.Manual.doc.tech',
                'Verso.Genre.Manual.doc.tactic',
                'Verso.Genre.Manual.doc.tactic.conv',
                'Verso.Genre.Manual.doc.suggestion',
                'Verso.Genre.Manual.section',
                'Verso.Genre.Manual.example',
            ];
            const canonical = (value) => {
                if (Array.isArray(value)) return value.map(canonical);
                if (value && typeof value === 'object') {
                    return Object.fromEntries(
                        Object.keys(value).sort().map((key) => [key, canonical(value[key])]),
                    );
                }
                return value;
            };
            const normalized = (items) => items.map((item) => canonical({
                searchKey: item.searchKey,
                address: item.address,
                domainId: item.domainId,
                ref: item.ref ?? null,
                priority: item.priority ?? null,
            }));
            const mismatches = [];
            for (const domainId of supportedDomains) {
                if (!xref[domainId] || !domainMappers[domainId]) continue;
                const javascript = normalized(domainMappers[domainId].dataToSearchables(xref[domainId]));
                const lean = normalized(provider.mapDomain(domainId, xref[domainId]));
                if (JSON.stringify(lean) !== JSON.stringify(javascript)) {
                    const index = lean.findIndex(
                        (item, index) => JSON.stringify(item) !== JSON.stringify(javascript[index]),
                    );
                    mismatches.push({
                        domainId,
                        count: {lean: lean.length, javascript: javascript.length},
                        index,
                        lean: lean[index],
                        javascript: javascript[index],
                    });
                }
            }
            return {mapped, ranked, mismatches};
        }"""
    )
    if result is None:
        pytest.skip("experimental VIR assets were not staged in this site")

    assert result["mapped"][0]["searchKey"] == "1. Introduction"
    assert result["mapped"][0]["address"] == "/guide/#intro"
    assert result["mismatches"] == [], json.dumps(result["mismatches"], indent=2)
    assert [
        (candidate["kind"], candidate["sourceIndex"]) for candidate in result["ranked"]
    ] == [("semantic", 0), ("semantic", 1), ("fullText", 0)]
    assert [candidate["score"] for candidate in result["ranked"]] == pytest.approx(
        [1, 0.9, 0.8], abs=1e-12
    )


def test_ranker_provider_matches_javascript_reference(server: str, page: Page):
    page.goto(server)
    result = page.evaluate(
        f"""async () => {{
            const m = await import('{SEARCH_BOX_PATH}');
            const mappedData = {{
                alpha: [{{searchKey: 'alpha', address: '/alpha', domainId: 'test', priority: 75}}],
                alphabet: [{{searchKey: 'alphabet', address: '/alphabet', domainId: 'test'}}],
            }};
            const preparedData = Object.keys(mappedData).map(window.fuzzysort.prepare);
            const opts = {{
                preparedData,
                mappedData,
                searchPriorities: {{semantic: 75, fullText: 50, domains: {{test: 75}}}},
                docPriorities: {{doc: 25}},
                searchIndex: {{search: () => [{{ref: 'doc', score: 2}}]}},
            }};
            const baseline = m.computeCandidates('alp', opts);
            let received;
            const virProvider = {{
                mapDomain: () => null,
                rankCandidates: (semantic, fullText) => {{
                    received = {{semantic, fullText}};
                    const maxText = fullText.reduce((max, hit) => Math.max(max, hit.rawScore), -Infinity);
                    const textFactor = maxText > 0.8 ? 0.8 / maxText : 1;
                    return [
                        ...semantic.map((hit) => ({{
                            kind: 'semantic',
                            sourceIndex: hit.sourceIndex,
                            score: m.combineScore(
                                hit.rawScore,
                                hit.semanticPriority,
                                hit.domainPriority,
                                hit.itemPriority,
                            ),
                        }})),
                        ...fullText.map((hit) => ({{
                            kind: 'fullText',
                            sourceIndex: hit.sourceIndex,
                            score: m.combineScore(
                                hit.rawScore * textFactor,
                                hit.fullTextPriority,
                                hit.documentPriority,
                            ),
                        }})),
                    ].sort((a, b) => b.score - a.score);
                }},
            }};
            const candidateSummary = (candidate) => ({{
                kind: candidate.kind,
                score: candidate.score,
                source: candidate.kind === 'semantic'
                    ? candidate.fuzzysortResult.target
                    : candidate.textMatch.ref,
            }});
            const viaVir = m.computeCandidates('alp', {{...opts, virProvider}});
            return {{
                baseline: baseline.map(candidateSummary),
                viaVir: viaVir.map(candidateSummary),
                received,
            }};
        }}"""
    )

    assert result["viaVir"] == result["baseline"]
    assert len(result["received"]["semantic"]) == 2
    assert result["received"]["semantic"][0]["semanticPriority"] == 75
    assert result["received"]["semantic"][0]["domainPriority"] == 75
    assert result["received"]["semantic"][0]["itemPriority"] == 75
    assert result["received"]["fullText"] == [
        {
            "sourceIndex": 0,
            "rawScore": 2,
            "fullTextPriority": 50,
            "documentPriority": 25,
        }
    ]


def test_mapper_uses_vir_then_falls_back_per_domain(server: str, page: Page):
    page.goto(server)
    result = page.evaluate(
        f"""async () => {{
            const m = await import('{SEARCH_BOX_PATH}');
            const calls = [];
            const domainMappers = {{
                builtin: {{
                    dataToSearchables: () => [{{
                        searchKey: 'javascript-builtin', address: '/wrong', domainId: 'builtin'
                    }}],
                }},
                extension: {{
                    dataToSearchables: () => [{{
                        searchKey: 'javascript-extension', address: '/extension', domainId: 'extension'
                    }}],
                }},
            }};
            const provider = {{
                mapDomain: (domainId) => {{
                    calls.push(domainId);
                    return domainId === 'builtin'
                        ? [{{searchKey: 'lean-builtin', address: '/builtin', domainId}}]
                        : null;
                }},
                rankCandidates: () => [],
            }};
            const mapped = m.buildSearchableMap(
                {{builtin: {{}}, extension: {{}}, ignored: {{}}}},
                domainMappers,
                provider,
            );
            return {{calls, keys: Object.keys(mapped), mapped}};
        }}"""
    )

    assert result["calls"] == ["builtin", "extension"]
    assert result["keys"] == ["lean-builtin", "javascript-extension"]
    assert result["mapped"]["lean-builtin"][0]["address"] == "/builtin"
    assert result["mapped"]["javascript-extension"][0]["address"] == "/extension"
