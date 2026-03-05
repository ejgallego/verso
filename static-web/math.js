document.addEventListener("DOMContentLoaded", () => {
    const renderMath = (node, displayMode) => {
        const tex = node.textContent || "";
        const prelude = (node.getAttribute("data-bp-tex-prelude") || "").trim();
        const renderInput = prelude ? `${prelude}\n${tex}` : tex;
        katex.render(renderInput, node, { throwOnError: false, displayMode });
    };
    for (const m of document.querySelectorAll(".math.inline")) {
        renderMath(m, false);
    }
    for (const m of document.querySelectorAll(".math.display")) {
        renderMath(m, true);
    }
});
