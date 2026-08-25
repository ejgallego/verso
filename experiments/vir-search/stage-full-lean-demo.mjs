import fs from "node:fs";
import path from "node:path";

const [sourceArgument, destinationArgument] = process.argv.slice(2);
if (!sourceArgument || !destinationArgument) {
    throw new Error("usage: node stage-full-lean-demo.mjs SOURCE-SITE DESTINATION-SITE");
}

const root = process.cwd();
const source = path.resolve(root, sourceArgument);
const destination = path.resolve(root, destinationArgument);
const sdk = path.join(root, ".lake/build/vir/sdk");
const packageSet = path.join(root, ".lake/build/vir/module-sets/VersoSearchVir");

for (const required of [source, sdk, packageSet]) {
    if (!fs.existsSync(required)) throw new Error(`missing required directory: ${required}`);
}
if (fs.existsSync(destination)) {
    throw new Error(`destination already exists: ${destination}`);
}

fs.cpSync(source, destination, { recursive: true });

const virDestination = path.join(destination, "-verso-search/vir");
fs.mkdirSync(virDestination, { recursive: true });
fs.cpSync(path.join(sdk, "js"), path.join(virDestination, "js"), { recursive: true });
fs.mkdirSync(path.join(virDestination, "wasm"), { recursive: true });
fs.copyFileSync(
    path.join(sdk, "wasm/vir-upstream.wasm"),
    path.join(virDestination, "wasm/vir-upstream.wasm"),
);
fs.cpSync(packageSet, path.join(virDestination, "VersoSearchVir"), { recursive: true });
fs.copyFileSync(path.join(root, "vir-startup.mjs"), path.join(virDestination, "vir-startup.mjs"));
fs.copyFileSync(
    path.join(root, "full-lean-demo.css"),
    path.join(virDestination, "full-lean-demo.css"),
);

const xrefPath = path.join(destination, "xref.json");
const indexPath = path.join(destination, "index.html");
const xref = JSON.stringify(JSON.parse(fs.readFileSync(xrefPath, "utf8")))
    .replaceAll("&", "\\u0026")
    .replaceAll("<", "\\u003c");
const fragment = `
<link rel="stylesheet" href="-verso-search/vir/full-lean-demo.css"/>
<section id="verso-full-lean-search" aria-label="Experimental Lean-owned search"></section>
<script id="verso-full-lean-xref" type="application/json">${xref}</script>
<script type="module"
        src="-verso-search/vir/vir-startup.mjs"
        data-vir-wasm="-verso-search/vir/wasm/vir-upstream.wasm"
        data-vir-package-set="-verso-search/vir/VersoSearchVir/Runtime.irpkg-set.json"></script>
`;
const original = fs.readFileSync(indexPath, "utf8");
if (!original.includes("</body>")) throw new Error(`missing </body> in ${indexPath}`);
fs.writeFileSync(indexPath, original.replace("</body>", `${fragment}</body>`));

console.log(`staged full-Lean VIR demo in ${destination}`);
