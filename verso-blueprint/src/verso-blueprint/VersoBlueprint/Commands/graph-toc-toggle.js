(function () {
  const className = "bp-graph-toc-hidden";
  const storageKey = "verso-blueprint-graph-toc-visible";
  if (!document.querySelector(".bp_graph_fullwidth")) return;
  if (!document.getElementById("toc")) return;

  function readVisible() {
    try {
      const saved = localStorage.getItem(storageKey);
      if (saved === "1") return true;
      if (saved === "0") return false;
    } catch (_err) {}
    return false;
  }

  let visible = readVisible();
  const root = document.documentElement;
  const button = document.createElement("button");
  button.id = "bp-toc-toggle";
  button.type = "button";

  function apply() {
    if (visible) root.classList.remove(className);
    else root.classList.add(className);
    button.textContent = visible ? "Hide ToC" : "Show ToC";
    window.dispatchEvent(new Event("resize"));
  }

  function persist() {
    try {
      localStorage.setItem(storageKey, visible ? "1" : "0");
    } catch (_err) {}
  }

  button.addEventListener("click", function () {
    visible = !visible;
    persist();
    apply();
  });

  if (document.body) {
    document.body.appendChild(button);
  } else {
    document.addEventListener("DOMContentLoaded", function () {
      if (document.body) document.body.appendChild(button);
    }, { once: true });
  }

  apply();
})();
