import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const root = process.cwd();
const sdk = path.join(root, ".lake/build/vir/sdk");
const runtimeModule = await import(pathToFileURL(path.join(sdk, "js/vir-runtime-node.js")));
const hostModule = await import(pathToFileURL(path.join(sdk, "js/vir-host-bindings.js")));
const wasmBytes = fs.readFileSync(path.join(sdk, "wasm/vir-upstream.wasm"));
const descriptorPath = path.join(
    root,
    ".lake/build/vir/module-sets/VersoSearchVir/Runtime.irpkg-set.json",
);
const descriptor = JSON.parse(fs.readFileSync(descriptorPath, "utf8"));
const packageDir = path.dirname(descriptorPath);
const irPackageSetBytes = descriptor.packages.map(({ path: memberPath }) =>
    fs.readFileSync(path.join(packageDir, memberPath)),
);

const resources = hostModule.createHostResourceState();
const virtualDocumentState = hostModule.createVirtualDocumentState({ resources });
const vir = await runtimeModule.createVirRuntime({
    wasmBytes,
    irPackageSetBytes,
    virtualDocumentState,
});

try {
    const mode = process.argv[2] ?? "all";
    const mapped = vir.call(
        "VersoSearchVir.Runtime.mapDomainJson",
        "Verso.Genre.Manual.section",
        JSON.stringify({
            contents: {
                intro: [
                    {
                        address: "/guide/",
                        id: "intro",
                        data: {
                            sectionNum: "1.",
                            title: "Introduction",
                            searchPriority: 75,
                        },
                    },
                ],
            },
        }),
    );
    if (mapped.kind !== "ok") throw new Error(`mapper failed: ${mapped.value}`);
    const searchables = JSON.parse(mapped.value);
    if (searchables[0]?.searchKey !== "1. Introduction") {
        throw new Error(`unexpected mapper output: ${mapped.value}`);
    }
    if (mode === "mapper") {
        console.log(JSON.stringify({ searchables }));
    } else {
        const semanticHits =
            mode === "empty"
                ? []
                : mode === "neutral"
                  ? [
                        {
                            sourceIndex: 0,
                            rawScore: 0.5,
                            semanticPriority: null,
                            domainPriority: null,
                            itemPriority: null,
                        },
                    ]
                  : mode === "ties"
                    ? [
                          {
                              sourceIndex: 0,
                              rawScore: 0.5,
                              semanticPriority: null,
                              domainPriority: null,
                              itemPriority: null,
                          },
                          {
                              sourceIndex: 1,
                              rawScore: 0.5,
                              semanticPriority: null,
                              domainPriority: null,
                              itemPriority: null,
                          },
                      ]
                    : [
                          {
                              sourceIndex: 0,
                              rawScore: 0.5,
                              semanticPriority: 75,
                              domainPriority: 75,
                              itemPriority: null,
                          },
                          {
                              sourceIndex: 1,
                              rawScore: 0.9,
                              semanticPriority: null,
                              domainPriority: null,
                              itemPriority: null,
                          },
                      ];
        const fullTextHits =
            mode === "all"
                ? [
                      {
                          sourceIndex: 0,
                          rawScore: 2,
                          fullTextPriority: null,
                          documentPriority: null,
                      },
                  ]
                : [];
        const ranked = vir.call(
            "VersoSearchVir.Runtime.rankCandidates",
            semanticHits,
            fullTextHits,
        );
        const shape = ranked.map(({ kind, sourceIndex }) => [kind, Number(sourceIndex)]);
        const expected = [
            ["semantic", 0],
            ["semantic", 1],
            ["fullText", 0],
        ];
        if (mode === "all" && JSON.stringify(shape) !== JSON.stringify(expected)) {
            throw new Error(`unexpected ranking order: ${JSON.stringify(ranked)}`);
        }
        const expectedScores = [1, 0.9, 0.8];
        if (
            mode === "all" &&
            ranked.some(({ score }, index) => Math.abs(score - expectedScores[index]) > 1e-12)
        ) {
            throw new Error(`unexpected ranking scores: ${JSON.stringify(ranked)}`);
        }
        console.log(JSON.stringify({ searchables, ranked }));
    }
} finally {
    vir.dispose();
}
