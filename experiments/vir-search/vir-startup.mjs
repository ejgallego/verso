/**
 * Generic VIR startup bootstrap.
 *
 * The application supplies only artifact URLs as data attributes. Application behavior and its
 * public entry point are discovered from the package manifest through `runStartupEntries()`.
 */

const config = document.querySelector("script[data-vir-package-set][data-vir-wasm]");

if (!config) {
    throw new Error("VIR startup requires data-vir-package-set and data-vir-wasm");
}

const pageRelativeUrl = (value) => new URL(value, document.baseURI).href;

try {
    const { createVirRuntime } = await import(new URL("./js/vir-runtime.js", import.meta.url));
    const runtime = await createVirRuntime({
        wasmUrl: pageRelativeUrl(config.dataset.virWasm),
        irPackageSetUrl: pageRelativeUrl(config.dataset.virPackageSet),
    });
    runtime.runStartupEntries();
    document.documentElement.dataset.virStartupState = "ready";
    window.addEventListener("pagehide", () => runtime.dispose(), { once: true });
} catch (error) {
    document.documentElement.dataset.virStartupState = "error";
    console.error("VIR startup failed", error);
}
