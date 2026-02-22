/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import VersoManual
import VersoBlueprint.Environment

open Verso Doc Elab
open Verso.Genre Manual

namespace Informal

structure TexPreludeData where
  prelude : String
deriving Lean.FromJson, Lean.ToJson, Lean.Quote

def texPreludeInjectorJs : String := r##"
(() => {
  const PRELUDE_SELECTOR = 'script.verso-tex-prelude[type=\"text/plain\"]';

  function collectPrelude() {
    const chunks = [];
    for (const node of document.querySelectorAll(PRELUDE_SELECTOR)) {
      const text = (node.textContent || '').trim();
      if (text.length > 0 && !chunks.includes(text)) {
        chunks.push(text);
      }
    }
    return chunks.join('\n');
  }

  function prependPrelude(tex, prelude) {
    if (!prelude) return tex;
    const body = typeof tex === 'string' ? tex : String(tex ?? '');
    return `${prelude}\n${body}`;
  }

  function patchKaTeX() {
    console.log("Patching KaTex");
    const katex = window.katex;
    if (!katex || typeof katex !== 'object') {
      return false;
    }

    if (typeof katex.render === 'function' && !katex.render.__versoTexPreludeWrapped) {
      const render = katex.render.bind(katex);
      const wrappedRender = function (tex, el, opts) {
        var tex = prependPrelude(tex, collectPrelude());
        console.log("Render: " + tex);
        return render(tex, el, opts);
      };
      wrappedRender.__versoTexPreludeWrapped = true;
      wrappedRender.__versoTexPreludeOriginal = render;
      katex.render = wrappedRender;
    }

    if (typeof katex.renderToString === 'function' && !katex.renderToString.__versoTexPreludeWrapped) {
      const renderToString = katex.renderToString.bind(katex);
      const wrappedRenderToString = function (tex, opts) {
        return renderToString(prependPrelude(tex, collectPrelude()), opts);
      };
      wrappedRenderToString.__versoTexPreludeWrapped = true;
      wrappedRenderToString.__versoTexPreludeOriginal = renderToString;
      katex.renderToString = wrappedRenderToString;
    }

    return (
      typeof katex.render === 'function' &&
      !!katex.render.__versoTexPreludeWrapped &&
      typeof katex.renderToString === 'function' &&
      !!katex.renderToString.__versoTexPreludeWrapped
    );
  }

  if (patchKaTeX()) return;

  const retry = () => {
    if (patchKaTeX()) {
      window.removeEventListener('load', retry);
      document.removeEventListener('DOMContentLoaded', retry);
      if (timer !== null) {
        clearInterval(timer);
      }
    }
  };

  document.addEventListener('DOMContentLoaded', retry);
  window.addEventListener('load', retry);

  let tries = 0;
  const timer = setInterval(() => {
    tries += 1;
    if (patchKaTeX() || tries >= 50) {
      clearInterval(timer);
    }
  }, 80);
})();
"##

def texPreludeInjectorJsFile : JsFile := {
  filename := "verso-blueprint/tex-prelude.js"
  contents := texPreludeInjectorJs
  sourceMap? := none
  after := #["katex/math.js"]
}

block_extension Block.texPrelude (data : TexPreludeData) where
  data := Lean.toJson data
  traverse _id _data _contents := do
    pure none
  toTeX := none
  extraJsFiles := singleton texPreludeInjectorJsFile
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI _goB _id data _blocks => do
      let .ok { prelude } := Lean.fromJson? (α := TexPreludeData) data
        | HtmlT.logError s!"Malformed data: {data}"
          pure .empty
      pure {{<script type="text/plain" class="verso-tex-prelude">{{.text false prelude}}</script>}}

/-- Informal directives -/
@[code_block]
def texPrelude : CodeBlockExpanderOf Unit
  | _, contents => do
    let prelude := contents.getString
    Environment.addTexPrelude prelude
    let data : TexPreludeData := { prelude }
    ``(Block.other (Block.texPrelude $(Lean.quote data)) #[])

end Informal
