/**
 * Copyright (c) 2026 Lean FRO LLC. All rights reserved.
 * Released under Apache 2.0 license as described in the file LICENSE.
 * Author: Emilio J. Gallego Arias
 */

// Enable typescript
// @ts-check

/**
 * @typedef {{runtimeModule: string, wasmUrl: string, packageSetUrl: string,
 *            mapEntry: string, rankEntry: string}} SearchVirConfig
 * @typedef {{call: (entry: string, ...args: any[]) => any, dispose: () => void}} VirRuntime
 * @typedef {{mapDomain: (domainId: string, domainData: any) => Searchable[] | null,
 *            rankCandidates: (semantic: VirSemanticHit[], fullText: VirFullTextHit[]) => VirRankedCandidate[]}}
 *            SearchVirProvider
 */

let /** @type {Promise<SearchVirProvider | null> | null} */ providerPromise = null;

/** @param {string} path */
const pageRelativeUrl = (path) => new URL(path, document.baseURI).href;

/**
 * Creates the optional VIR-backed pure search provider.
 *
 * Runtime loading is asynchronous, but calls are synchronous after initialization. Search already
 * waits for `xref.json`, so callers join this promise during the same initialization phase and do
 * not add an `await` to the per-keystroke path.
 *
 * @returns {Promise<SearchVirProvider | null>}
 */
export const loadSearchVirProvider = () =>
    (providerPromise ??= (async () => {
        const config = /** @type {{versoSearchVir?: SearchVirConfig}} */ (
            /** @type {unknown} */ (window)
        ).versoSearchVir;
        if (!config) return null;

        try {
            const runtimeModuleUrl = pageRelativeUrl(config.runtimeModule);
            const [runtimeModule, hostModule] = await Promise.all([
                import(runtimeModuleUrl),
                import(new URL("./vir-host-bindings.js", runtimeModuleUrl).href),
            ]);
            const resources = hostModule.createHostResourceState();
            const runtime = await runtimeModule.createVirRuntime({
                wasmUrl: pageRelativeUrl(config.wasmUrl),
                irPackageSetUrl: pageRelativeUrl(config.packageSetUrl),
                defaultHostBindings: hostModule.createBrowserHostBindings({ resources }),
            });

            window.addEventListener("pagehide", () => runtime.dispose(), { once: true });

            return {
                mapDomain(domainId, domainData) {
                    const result = runtime.call(
                        config.mapEntry,
                        domainId,
                        JSON.stringify(domainData),
                    );
                    // An unregistered extension domain is expected and uses its JavaScript mapper.
                    if (result?.kind === "error") return null;
                    if (result?.kind !== "ok" || typeof result.value !== "string") {
                        throw new Error(`Unexpected ${config.mapEntry} result`);
                    }
                    return JSON.parse(result.value);
                },

                rankCandidates(semantic, fullText) {
                    const result = runtime.call(config.rankEntry, semantic, fullText);
                    if (!Array.isArray(result)) {
                        throw new Error(`Unexpected ${config.rankEntry} result`);
                    }
                    return result.map((candidate) => ({
                        ...candidate,
                        sourceIndex: Number(candidate.sourceIndex),
                    }));
                },
            };
        } catch (error) {
            console.warn("Verso search could not initialize its experimental VIR backend", error);
            return null;
        }
    })());
