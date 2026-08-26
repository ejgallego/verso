import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { performance } from "node:perf_hooks";
import { pathToFileURL } from "node:url";

const root = process.cwd();
const sdk = path.join(root, ".lake/build/vir/sdk");
const runtimeUrl = pathToFileURL(path.join(sdk, "js/vir-runtime-node.js"));
const hostUrl = pathToFileURL(path.join(sdk, "js/vir-host-bindings.js"));

const sdkImportStart = performance.now();
const [runtimeModule, hostModule] = await Promise.all([import(runtimeUrl), import(hostUrl)]);
const sdkImportMs = performance.now() - sdkImportStart;

const runtimeStart = performance.now();
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
const runtimeInitializationMs = performance.now() - runtimeStart;

// Keep this reference lane structurally identical to the production JavaScript fallback in
// static-web/search/search-box.js. It returns only the scalar fields that cross the VIR boundary.
const priorityContribution = (priority) => (priority == null ? 0 : (priority - 50) / 50);

const combineScore = (rawScore, ...priorities) => {
    let sum = 0;
    for (const priority of priorities) sum += priorityContribution(priority);
    return rawScore * Math.pow(2, sum);
};

const rankWithJavaScript = (semanticHits, fullTextHits) => {
    const bestPossibleText = 0.8;
    const maxTextScore = fullTextHits.reduce(
        (max, item) => Math.max(max, item.rawScore),
        -Infinity,
    );
    const textFactor = maxTextScore > bestPossibleText ? bestPossibleText / maxTextScore : 1;
    const candidates = semanticHits.map((hit) => ({
        kind: "semantic",
        sourceIndex: hit.sourceIndex,
        score: combineScore(
            hit.rawScore,
            hit.semanticPriority,
            hit.domainPriority,
            hit.itemPriority,
        ),
    }));
    for (const hit of fullTextHits) {
        candidates.push({
            kind: "fullText",
            sourceIndex: hit.sourceIndex,
            score: combineScore(
                hit.rawScore * textFactor,
                hit.fullTextPriority,
                hit.documentPriority,
            ),
        });
    }
    candidates.sort((left, right) => right.score - left.score);
    return candidates;
};

const makeRandom = (seed) => {
    let state = seed >>> 0;
    return () => {
        state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
        return state / 0x100000000;
    };
};

const makeWorkload = ({ name, semanticCount, fullTextCount }, seed) => {
    const random = makeRandom(seed);
    const priority = () => (random() < 0.2 ? null : Math.floor(random() * 100));
    const semanticHits = Array.from({ length: semanticCount }, (_, sourceIndex) => ({
        sourceIndex,
        rawScore: 0.25 + random() * 0.75,
        semanticPriority: priority(),
        domainPriority: priority(),
        itemPriority: priority(),
    }));
    const fullTextHits = Array.from({ length: fullTextCount }, (_, sourceIndex) => ({
        sourceIndex,
        rawScore: 0.05 + random() * 3.95,
        fullTextPriority: priority(),
        documentPriority: priority(),
    }));
    return { name, semanticHits, fullTextHits };
};

const assertEquivalent = (expected, actual, workload) => {
    if (expected.length !== actual.length) {
        throw new Error(`${workload}: candidate count differs`);
    }
    for (let index = 0; index < expected.length; index++) {
        const js = expected[index];
        const lean = actual[index];
        if (js.kind !== lean.kind || js.sourceIndex !== lean.sourceIndex) {
            throw new Error(
                `${workload}: order differs at ${index}: ${JSON.stringify({ js, lean })}`,
            );
        }
        const tolerance = 1e-12 * Math.max(1, Math.abs(js.score));
        if (Math.abs(js.score - lean.score) > tolerance) {
            throw new Error(
                `${workload}: score differs at ${index}: ${JSON.stringify({ js, lean })}`,
            );
        }
    }
};

let checksum = 0;

const timeBatch = (run, iterations) => {
    const start = performance.now();
    for (let iteration = 0; iteration < iterations; iteration++) {
        const result = run();
        checksum = (checksum + result.length + (result[0]?.sourceIndex ?? 0)) >>> 0;
    }
    return performance.now() - start;
};

const median = (values) => {
    const sorted = [...values].sort((left, right) => left - right);
    return sorted[Math.floor(sorted.length / 2)];
};

const benchmark = (run) => {
    for (let index = 0; index < 3; index++) run();
    const calibrationMs = Math.max(timeBatch(run, 1), 0.01);
    const iterations = Math.max(1, Math.min(5000, Math.ceil(100 / calibrationMs)));
    const samples = Array.from({ length: 9 }, () => timeBatch(run, iterations) / iterations);
    return {
        iterations,
        medianMs: median(samples),
        minMs: Math.min(...samples),
        maxMs: Math.max(...samples),
    };
};

const workloadSpecs = [
    { name: "empty", semanticCount: 0, fullTextCount: 0 },
    { name: "small", semanticCount: 12, fullTextCount: 4 },
    { name: "medium", semanticCount: 48, fullTextCount: 16 },
    { name: "large", semanticCount: 192, fullTextCount: 64 },
];

const rows = [];
try {
    for (const [index, spec] of workloadSpecs.entries()) {
        const workload = makeWorkload(spec, 0x5eed0000 + index);
        const runJavaScript = () =>
            rankWithJavaScript(workload.semanticHits, workload.fullTextHits);
        const runVir = () =>
            vir
                .call(
                    "VersoSearchVir.Runtime.rankCandidates",
                    workload.semanticHits,
                    workload.fullTextHits,
                )
                .map((candidate) => ({
                    ...candidate,
                    sourceIndex: Number(candidate.sourceIndex),
                }));
        assertEquivalent(runJavaScript(), runVir(), workload.name);
        const javascript = benchmark(runJavaScript);
        const virResult = benchmark(runVir);
        rows.push({
            workload: workload.name,
            candidates: spec.semanticCount + spec.fullTextCount,
            semantic: spec.semanticCount,
            fullText: spec.fullTextCount,
            javascript,
            vir: virResult,
            virToJavaScript: virResult.medianMs / javascript.medianMs,
        });
    }
} finally {
    vir.dispose();
}

const report = {
    environment: {
        node: process.version,
        v8: process.versions.v8,
        platform: `${process.platform}-${process.arch}`,
        cpu: os.cpus()[0]?.model ?? "unknown",
    },
    initialization: {
        sdkImportMs,
        runtimeAndPackagesMs: runtimeInitializationMs,
    },
    rows,
    checksum,
};

if (process.argv.includes("--json")) {
    console.log(JSON.stringify(report, null, 2));
} else {
    console.log(`Node ${report.environment.node}; ${report.environment.cpu}`);
    console.log(
        `VIR initialization: SDK import ${sdkImportMs.toFixed(1)} ms; ` +
            `runtime + packages ${runtimeInitializationMs.toFixed(1)} ms`,
    );
    console.table(
        rows.map((row) => ({
            workload: row.workload,
            candidates: row.candidates,
            "JS median (ms)": row.javascript.medianMs.toFixed(4),
            "VIR median (ms)": row.vir.medianMs.toFixed(4),
            "VIR / JS": `${row.virToJavaScript.toFixed(1)}x`,
            "JS iterations": row.javascript.iterations,
            "VIR iterations": row.vir.iterations,
        })),
    );
}
