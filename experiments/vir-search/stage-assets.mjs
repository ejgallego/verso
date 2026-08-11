import fs from "node:fs";
import path from "node:path";

const [siteArgument] = process.argv.slice(2);
if (!siteArgument) {
    throw new Error("usage: node stage-assets.mjs SITE-DIRECTORY");
}

const root = process.cwd();
const site = path.resolve(root, siteArgument);
const sdk = path.join(root, ".lake/build/vir/sdk");
const packageSet = path.join(root, ".lake/build/vir/module-sets/VersoSearchVir");
const destination = path.join(site, "-verso-search/vir");

for (const required of [site, sdk, packageSet]) {
    if (!fs.existsSync(required)) throw new Error(`missing required directory: ${required}`);
}

fs.mkdirSync(destination, { recursive: true });
fs.cpSync(path.join(sdk, "js"), path.join(destination, "js"), { recursive: true });
fs.mkdirSync(path.join(destination, "wasm"), { recursive: true });
fs.copyFileSync(
    path.join(sdk, "wasm/vir-upstream.wasm"),
    path.join(destination, "wasm/vir-upstream.wasm"),
);
fs.cpSync(packageSet, path.join(destination, "VersoSearchVir"), { recursive: true });

console.log(`staged VIR search assets in ${destination}`);
