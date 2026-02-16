/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias, David Thrane Christiansen
-/

-- Blueprint library extending the Verso `Manual` genre.

import Lean.Elab.InfoTree.Types

import VersoManual

import VersoBlueprint.Data
import VersoBlueprint.Environment
import VersoBlueprint.Attribute
import VersoBlueprint.Commands
import VersoBlueprint.Lean
import VersoBlueprint.Widget
-- import DevWidgets.DHover
-- import DevWidgets.InfoViewExplorer

set_option doc.verso true

open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse
open Lean.Doc.Syntax
open Lean Elab

namespace Informal

namespace Internal

def ppBlock (b : TSyntax `term) : Format := b.raw.formatStx

instance : ToString PartFrame where
  toString p :=
    let ⟨titleSyntax, expandedTitle, metadata, blocks, priorParts⟩ := p
    s!"[title: {titleSyntax.formatStx}
        - has_expended_title: {expandedTitle.isSome}
        - has_metadata: {metadata.isSome}
        - blocks: {blocks.size} where {Array.map ppBlock blocks}
        - prior: {priorParts.size}
    ]"

instance : ToString PartContext where
  toString p :=
    let ⟨frame, parents⟩ := p
    s!"{frame} with {parents.size} parents: {parents}"

end Internal

/- "Informal" Verso objects:

  - An informal verso object is identified by a label, and lives in the `informal` Verso domain.
  - For IO (Informal Object), we associate a `Data` entry, which mainly captures other objects the IO depends on
  - Objects are declared via directives / code blocks
  - Dependencies are declared via the {uses ...}`...` role, which _must_ be inside a directive.

Elaboration, traversal, and rendering are standard, using {ref VersoManual} helpers for custom blocks and inlines.

-/

/-- Domain for informal-like objects; each informal object is
  characterized by its canonical name declared by the user. -/
def informal : Domain := {}

/-- Name used in {name}`TraverseState.domains` for informal objects. -/
def informalDomain : Name := Name.mkSimple "Informal.Block.informal"
/-- Name used in {name}`TraverseState.domains` for informal Lean code blocks. -/
def informalCodeDomain : Name := Name.mkSimple "Informal.Block.informalCode"

/-- Configuration for directives / code-blocks. Q: should we allow non-labelled informal objects? -/
structure Config where
  label : Data.Label
  labelSyntax : Syntax := Syntax.missing
  lean : Option String := none
--  hide : Bool := false

section
variable [Monad m] [MonadInfoTree m] [MonadLiftT CoreM m] [MonadEnv m] [MonadError m] [MonadFileMap m]

-- def _root_.Verso.ArgParse.ValDesc.array (elem : ValDesc m e) : ValDesc m (Array e) where
--   description := .text "array parser, using list syntax"
--   signature := { ident := false, string := false, num := false }
--   get := sorry

def Config.parse  : ArgParse m Config :=
  (fun (labelArg : Verso.ArgParse.WithSyntax String) lean =>
    {
      label := Name.mkSimple labelArg.val
      labelSyntax := labelArg.syntax
      lean := lean
    }) <$> .positional `label (.withSyntax .string) <*> .named `lean .string true

instance : FromArgs Config m where
  fromArgs := Config.parse

end

inductive BlockKind where
  | def_
  | lem_
  | thm_
  | proof_
  | cor_
  | code_
deriving FromJson, ToJson, DecidableEq, Quote

instance : ToString BlockKind where
 toString
  | .def_   => "Definition"
  | .lem_   => "Lemma"
  | .thm_   => "Theorem"
  | .proof_ => "Proof"
  | .cor_   => "Corollary"
  | .code_  => "Lean Code"

structure BlockData where
  kind : BlockKind
  label : Data.Label
  count : Nat
deriving FromJson, ToJson, Quote

structure CodeDeclData where
  name : Name
  commandIndex : Nat := 0
  weight : Nat := 1
  hasSorry : Bool := false
  hasTypeSorry : Bool := false
  hasProofSorry : Bool := false
deriving FromJson, ToJson, Quote

structure CodeBlockData where
  label : Data.Label
  definedDefs : Array CodeDeclData := #[]
  definedTheorems : Array CodeDeclData := #[]
  foldProofs : Bool := true
deriving FromJson, ToJson, Quote

structure TexPreludeData where
  prelude : String
deriving FromJson, ToJson, Quote

register_option verso.blueprint.foldProofs : Bool := {
  defValue := true
  descr := "Enable proof folding in VersoBlueprint Lean code blocks (hide text after `by` behind a toggle)"
}

structure CodeHoverDecl where
  text : String
  href : Option String := none

structure CodeHoverData where
  label : Data.Label
  definedDefs : Array CodeHoverDecl := #[]
  definedTheorems : Array CodeHoverDecl := #[]
  sorries : Array CodeHoverDecl := #[]

structure ComputedData where
  proved : Bool := false
  codeHref : Option String := none
  codeHover : Option CodeHoverData := none
  hasStatementSorries : Bool := false
  hasProofSorries : Bool := false

def mkCodeHoverData
    (label : Data.Label)
    (definedDefs definedTheorems : Array CodeDeclData)
    (hrefOf : Name → Option String) : CodeHoverData :=
  let toDecl (d : CodeDeclData) : CodeHoverDecl :=
    { text := toString d.name, href := hrefOf d.name }
  let toSorry (d : CodeDeclData) : CodeHoverDecl :=
    let kind :=
      if d.hasTypeSorry && d.hasProofSorry then "in statement and proof"
      else if d.hasTypeSorry then "in statement"
      else if d.hasProofSorry then "in proof"
      else "unknown"
    { text := s!"{d.name} [{kind}]", href := hrefOf d.name }
  {
    label
    definedDefs := definedDefs.map toDecl
    definedTheorems := definedTheorems.map toDecl
    sorries := (definedDefs ++ definedTheorems).filter (·.hasSorry) |>.map toSorry
  }

def codeHoverText (label : Data.Label) (definedDefs definedTheorems : Array CodeDeclData) : String :=
  if definedDefs.isEmpty && definedTheorems.isEmpty then
    s!"{label}"
  else
    let definedDefNames := definedDefs.map (·.name)
    let definedTheoremNames := definedTheorems.map (·.name)
    let defs :=
      if definedDefNames.isEmpty then
        "none"
      else
        String.intercalate ", " (definedDefNames.toList.map toString)
    let thms :=
      if definedTheoremNames.isEmpty then
        "none"
      else
        String.intercalate ", " (definedTheoremNames.toList.map toString)
    let sorryDecls := (definedDefs ++ definedTheorems).filter (·.hasSorry)
    let sorries :=
      if sorryDecls.isEmpty then
        "none"
      else
        String.intercalate ", " <| sorryDecls.toList.map fun d =>
          let kind :=
            if d.hasTypeSorry && d.hasProofSorry then "in statement and proof"
            else if d.hasTypeSorry then "in statement"
            else if d.hasProofSorry then "in proof"
            else "unknown"
          s!"{d.name} [{kind}]"
    s!"{label}\nLean definitions: {defs}\nLean theorems/lemmas: {thms}\nSorries: {sorries}"

private def sortDeclsByCommand (decls : Array CodeDeclData) : Array CodeDeclData :=
  decls.qsort (fun a b =>
    a.commandIndex < b.commandIndex ||
    (a.commandIndex == b.commandIndex && a.name.toString < b.name.toString))

def blueprintCss : String := r##"
.bp_wrapper {
  scroll-margin-top: 1rem;
  margin: 0.85rem 0;
}

.bp_heading {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  font-style: normal;
  font-weight: bold;
}

.bp_caption {
  display: inline;
}

.bp_label {
  margin-left: 0.5rem;
}

span[class$="_thmlabel"]::after {
  content: ".";
}

.bp_extras {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  margin-left: auto;
}

.bp_code_link {
  display: inline;
  font-size: 0.8rem;
  color: inherit;
  text-decoration: none;
}

.bp_code_link_wrap {
  position: relative;
  display: inline-flex;
  align-items: center;
  padding-bottom: 0.45rem;
  margin-bottom: -0.45rem;
}

.bp_code_link_wrap::after {
  content: "";
  position: absolute;
  left: -0.25rem;
  right: -0.25rem;
  top: 100%;
  height: 0.45rem;
}

.bp_code_hover {
  position: absolute;
  left: 50%;
  top: 100%;
  transform: translateX(-50%);
  min-width: 20rem;
  max-width: min(34rem, 75vw);
  z-index: 20;
  border: 1px solid #cbd5e1;
  border-radius: 0.45rem;
  padding: 0.45rem 0.55rem;
  background: #ffffff;
  box-shadow: 0 8px 20px rgba(15, 23, 42, 0.15);
  display: none;
  font-size: 0.78rem;
  font-style: normal;
  font-weight: 400;
}

.bp_code_link_wrap:is(:hover, :focus-within) > .bp_code_hover {
  display: block;
}

.bp_code_hover_title {
  font-weight: 700;
  margin-bottom: 0.3rem;
}

.bp_code_hover_section {
  margin-top: 0.28rem;
}

.bp_code_hover_label {
  font-weight: 600;
  color: #334155;
}

.bp_code_hover_list {
  margin: 0.12rem 0 0;
  padding-left: 1.1rem;
}

.bp_code_hover_list code {
  font-size: 0.76rem;
}

.bp_code_hover_none {
  color: #64748b;
  font-style: italic;
}

.bp_code_block summary {
  display: flex;
  align-items: center;
  gap: 0.55rem;
}

.bp_code_summary_text {
  white-space: nowrap;
}

.bp_code_progress {
  display: inline-flex;
  flex: 1 1 10rem;
  min-width: 7rem;
  max-width: 22rem;
  height: 0.72rem;
  border-radius: 0;
  overflow: hidden;
  border: 1px solid #cbd5e1;
  background: #f8fafc;
}

.bp_code_progress_segment {
  min-width: 0.28rem;
}

.bp_code_progress_segment + .bp_code_progress_segment {
  border-left: 2px solid rgba(15, 23, 42, 0.45);
}

.bp_code_progress_segment_ok {
  background: #16a34a;
}

.bp_code_progress_segment_sorry {
  background: #dc2626;
}

.bp_code_expand_hint {
  color: #64748b;
  font-size: 0.74rem;
  white-space: nowrap;
}

.bp_code_expand_hint::before {
  content: "expand";
}

details[open] > summary .bp_code_expand_hint::before {
  content: "collapse";
}

.bp_decl_target {
  background: rgba(59, 130, 246, 0.18);
  border-radius: 0.18rem;
  box-shadow: 0 0 0 0.12rem rgba(59, 130, 246, 0.22);
  animation: bp-decl-target-pulse 1.8s ease-out;
}

.bp_decl_target_block {
  border-radius: 0.3rem;
  box-shadow: 0 0 0 0.18rem rgba(59, 130, 246, 0.2);
  background: linear-gradient(180deg, rgba(59, 130, 246, 0.08), rgba(59, 130, 246, 0.04));
  animation: bp-decl-block-pulse 2.2s ease-out;
}

@keyframes bp-decl-target-pulse {
  0% {
    background: rgba(59, 130, 246, 0.28);
    box-shadow: 0 0 0 0.2rem rgba(59, 130, 246, 0.3);
  }
  100% {
    background: rgba(59, 130, 246, 0.1);
    box-shadow: 0 0 0 0.08rem rgba(59, 130, 246, 0.16);
  }
}

@keyframes bp-decl-block-pulse {
  0% {
    background: rgba(59, 130, 246, 0.14);
    box-shadow: 0 0 0 0.28rem rgba(59, 130, 246, 0.24);
  }
  100% {
    background: rgba(59, 130, 246, 0.04);
    box-shadow: 0 0 0 0.14rem rgba(59, 130, 246, 0.16);
  }
}

.bp_code_link:hover {
  text-decoration: underline;
}

.bp_content {
  padding-left: 0.65rem;
}

.bp_content > :first-child {
  margin-top: 0;
}

.bp_content > :last-child {
  margin-bottom: 0;
}

.bp-proof-tail-hidden {
  display: none;
}

.bp-proof-gap-hidden {
  display: none;
}

.bp-proof-by-toggle {
  cursor: pointer;
  text-decoration: underline dotted;
  text-decoration-thickness: 1px;
}

.bp-proof-by-toggle::after {
  content: " ...";
  color: #64748b;
}

.bp-proof-by-toggle.bp-proof-open::after {
  content: "";
}

div.theorem-style-plain div[class$="_thmheading"] {
  font-style: normal;
  font-weight: bold;
}

div.theorem-style-plain div[class$="_thmcontent"] {
  font-style: italic;
  font-weight: normal;
}

div.theorem-style-definition div[class$="_thmheading"] {
  font-style: normal;
  font-weight: bold;
}

div.theorem_thmcontent {
  border-left: 0.15rem solid black;
}

div.proposition_thmcontent {
  border-left: 0.15rem solid black;
}

div.lemma_thmcontent {
  border-left: 0.1rem solid black;
}

div.corollary_thmcontent {
  border-left: 0.1rem solid black;
}

div.proof_content {
  border-left: 0.08rem solid grey;
}

.bp_wrapper:target {
  animation: bp-target-pulse 1.6s ease-out;
  box-shadow: 0 0 0 0.18rem rgba(37, 99, 235, 0.22);
  border-radius: 0.35rem;
}

@keyframes bp-target-pulse {
  0% {
    background-color: rgba(37, 99, 235, 0.14);
    box-shadow: 0 0 0 0.28rem rgba(37, 99, 235, 0.28);
  }
  100% {
    background-color: transparent;
    box-shadow: 0 0 0 0.18rem rgba(37, 99, 235, 0.22);
  }
}
"##

def blueprintStyleSwitcherCss : String := r##"
#bp-style-switcher {
  position: fixed;
  right: 1rem;
  bottom: 1rem;
  z-index: 1000;
  background: #ffffff;
  border: 1px solid #cbd5e1;
  border-radius: 0.45rem;
  box-shadow: 0 4px 14px rgba(15, 23, 42, 0.1);
  padding: 0.4rem 0.55rem;
  font-size: 0.82rem;
}

#bp-style-switcher label {
  margin-right: 0.35rem;
  font-weight: 600;
}

#bp-style-switcher select {
  border: 1px solid #cbd5e1;
  border-radius: 0.3rem;
  background: #ffffff;
  font-size: 0.82rem;
  padding: 0.1rem 0.25rem;
}

html[data-bp-style="blueprint"] .bp_wrapper {
  border: 1px solid #cbd5e1;
  border-radius: 0.35rem;
  padding: 0.45rem 0.6rem 0.55rem;
  background: #ffffff;
}

html[data-bp-style="blueprint"] .bp_heading {
  border-bottom: 1px solid #e2e8f0;
  padding-bottom: 0.35rem;
}

html[data-bp-style="blueprint"] .bp_content {
  margin-top: 0.35rem;
  padding-left: 0.45rem;
}

html[data-bp-style="blueprint"] div.theorem_thmcontent,
html[data-bp-style="blueprint"] div.proposition_thmcontent,
html[data-bp-style="blueprint"] div.lemma_thmcontent,
html[data-bp-style="blueprint"] div.corollary_thmcontent,
html[data-bp-style="blueprint"] div.proof_content {
  border-left-color: #334155;
}

html[data-bp-style="modern"] .bp_wrapper {
  border: 1px solid #d6deea;
  border-radius: 0.7rem;
  padding: 0.6rem 0.7rem 0.68rem;
  background: linear-gradient(180deg, #ffffff, #f8fbff);
  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.08);
}

html[data-bp-style="modern"] .bp_heading {
  border-bottom: 1px solid #e2e8f0;
  padding-bottom: 0.4rem;
}

html[data-bp-style="modern"] .bp_caption {
  background: #e0ecff;
  border-radius: 999px;
  padding: 0.08rem 0.5rem;
}

html[data-bp-style="modern"] .bp_content {
  margin-top: 0.45rem;
  padding-left: 0.5rem;
}

html[data-bp-style="modern"] .bp_wrapper div.theorem_thmcontent,
html[data-bp-style="modern"] .bp_wrapper div.proposition_thmcontent,
html[data-bp-style="modern"] .bp_wrapper div.lemma_thmcontent,
html[data-bp-style="modern"] .bp_wrapper div.corollary_thmcontent,
html[data-bp-style="modern"] .bp_wrapper div.proof_content {
  border-left-color: #64748b;
}

html[data-bp-style="bold"] .bp_wrapper {
  border: 2px solid #0f172a;
  border-radius: 0.85rem;
  padding: 0.6rem 0.75rem 0.75rem;
  background:
    radial-gradient(circle at 100% 0%, rgba(251, 191, 36, 0.2), transparent 36%),
    radial-gradient(circle at 0% 100%, rgba(16, 185, 129, 0.2), transparent 32%),
    #ffffff;
  box-shadow: 0 9px 0 #0f172a;
}

html[data-bp-style="bold"] .bp_heading {
  border-bottom: 2px solid #0f172a;
  padding-bottom: 0.45rem;
  letter-spacing: 0.01em;
}

html[data-bp-style="bold"] .bp_caption {
  background: #0f172a;
  color: #f8fafc;
  border-radius: 0.25rem;
  padding: 0.08rem 0.45rem;
  text-transform: uppercase;
}

html[data-bp-style="bold"] .bp_label {
  background: #f59e0b;
  color: #111827;
  border-radius: 999px;
  padding: 0.06rem 0.42rem;
}

html[data-bp-style="bold"] .bp_code_link {
  color: #7c2d12;
  font-weight: 700;
}

html[data-bp-style="bold"] .bp_code_hover {
  border: 2px solid #0f172a;
  border-radius: 0.55rem;
  box-shadow: 0 8px 0 #0f172a;
}

html[data-bp-style="bold"] .bp_content {
  margin-top: 0.5rem;
  padding-left: 0.6rem;
}

html[data-bp-style="bold"] .bp_wrapper div.theorem_thmcontent,
html[data-bp-style="bold"] .bp_wrapper div.proposition_thmcontent,
html[data-bp-style="bold"] .bp_wrapper div.lemma_thmcontent,
html[data-bp-style="bold"] .bp_wrapper div.corollary_thmcontent,
html[data-bp-style="bold"] .bp_wrapper div.proof_content {
  border-left: 0.2rem solid #0f172a;
}
  "##

def blueprintStyleSwitcherJs : String := r##"(function () {
  const storageKey = "verso-blueprint-style";
  const switcherId = "bp-style-switcher";
  const root = document.documentElement;
  const targetClass = "bp_decl_target";
  const targetBlockClass = "bp_decl_target_block";

  function normalize(style) {
    if (style === "blueprint" || style === "modern" || style === "bold") return style;
    return "blueprint";
  }

  function applyStyle(style) {
    root.setAttribute("data-bp-style", normalize(style));
  }

  function getSavedStyle() {
    try {
      return normalize(localStorage.getItem(storageKey));
    } catch (_err) {
      return "blueprint";
    }
  }

  function saveStyle(style) {
    try {
      localStorage.setItem(storageKey, normalize(style));
    } catch (_err) {}
  }

  function installSwitcher() {
    if (document.getElementById(switcherId)) return;
    if (!document.body) return;

    const host = document.createElement("div");
    host.id = switcherId;

    const label = document.createElement("label");
    label.setAttribute("for", "bp-style-select");
    label.textContent = "Style";

    const select = document.createElement("select");
    select.id = "bp-style-select";
    select.innerHTML = [
      '<option value="blueprint">blueprint</option>',
      '<option value="modern">modern</option>',
      '<option value="bold">bold</option>'
    ].join("");

    const current = getSavedStyle();
    select.value = current;
    applyStyle(current);

    select.addEventListener("change", function () {
      const value = normalize(select.value);
      applyStyle(value);
      saveStyle(value);
    });

    host.appendChild(label);
    host.appendChild(select);
    document.body.appendChild(host);
  }

  function installProofHider() {
    const blocks = document.querySelectorAll("details.bp_code_block code.hl.lean.block");
    const declKeywords = new Set(["theorem", "lemma", "corollary", "example"]);
    const commandStartKeywords = new Set([
      "theorem", "lemma", "corollary", "example", "def", "abbrev", "instance",
      "axiom", "constant", "opaque", "inductive", "structure", "class", "namespace",
      "section", "end", "open", "local", "attribute", "set_option", "variable",
      "variables", "notation", "infix", "infixl", "infixr", "prefix", "postfix",
      "macro", "syntax", "elab", "initialize", "mutual"
    ]);

    function locateTextPosition(rootNode, absIndex) {
      const walker = document.createTreeWalker(rootNode, NodeFilter.SHOW_TEXT);
      let seen = 0;
      while (true) {
        const node = walker.nextNode();
        if (!node) break;
        const len = node.nodeValue ? node.nodeValue.length : 0;
        if (absIndex <= seen + len) {
          return { node, offset: absIndex - seen };
        }
        seen += len;
      }
      return null;
    }

    function toggleProof(toggleNode, proofTail, gapNode) {
      const hidden = proofTail.classList.toggle("bp-proof-tail-hidden");
      toggleNode.classList.toggle("bp-proof-open", !hidden);
      toggleNode.setAttribute("aria-expanded", hidden ? "false" : "true");
      if (gapNode) {
        gapNode.classList.toggle("bp-proof-gap-hidden", !hidden);
      }
    }

    function absIndexBeforeElement(rootNode, el) {
      const r = document.createRange();
      r.setStart(rootNode, 0);
      r.setEndBefore(el);
      return r.toString().length;
    }

    function lineIndent(text, idx) {
      const lastNl = text.lastIndexOf("\n", Math.max(0, idx - 1));
      const lineStart = lastNl + 1;
      let i = lineStart;
      while (i < idx && text[i] === " ") i++;
      return i - lineStart;
    }

    function isFirstTokenOnLine(text, idx) {
      const lastNl = text.lastIndexOf("\n", Math.max(0, idx - 1));
      const lineStart = lastNl + 1;
      return /^[ \t]*$/.test(text.slice(lineStart, idx));
    }

    function isCommandStartText(tokText) {
      if (!tokText) return false;
      if (tokText[0] === "#") return true;
      return commandStartKeywords.has(tokText);
    }

    blocks.forEach((block) => {
      if (!(block instanceof HTMLElement)) return;
      const details = block.closest("details.bp_code_block");
      if (details instanceof HTMLElement && details.dataset.bpProofFold === "off") return;
      if (block.dataset.bpProofHider === "1") return;
      block.dataset.bpProofHider = "1";

      const text = block.textContent || "";
      if (!text) return;

      const tokenNodes = Array.from(block.querySelectorAll(".token"));
      const keywordNodes = Array.from(block.querySelectorAll(".keyword.token"));

      const allTokens = tokenNodes.map((el) => {
        const tokText = (el.textContent || "").trim();
        const start = absIndexBeforeElement(block, el);
        const end = start + (el.textContent || "").length;
        const firstOnLine = isFirstTokenOnLine(text, start);
        const indent = lineIndent(text, start);
        return { el, tokText, start, end, firstOnLine, indent };
      });

      const commandStarts = allTokens.filter((t) =>
        t.firstOnLine && isCommandStartText(t.tokText)
      );

      const keywordTokens = keywordNodes.map((el) => {
        const tokText = (el.textContent || "").trim();
        const start = absIndexBeforeElement(block, el);
        const end = start + (el.textContent || "").length;
        const indent = lineIndent(text, start);
        return { el, tokText, start, end, indent };
      });

      const declStarts = keywordTokens.filter((t) => declKeywords.has(t.tokText));
      if (declStarts.length === 0) return;

      const segments = [];
      for (const decl of declStarts) {
        const boundary = commandStarts.find((c) =>
          c.start > decl.start && c.indent <= decl.indent
        );
        const segmentEnd = boundary ? boundary.start : text.length;
        if (segmentEnd <= decl.start) continue;
        const byTok = keywordTokens.find((t) =>
          t.tokText === "by" && t.start > decl.start && t.end <= segmentEnd
        );
        if (!byTok) continue;
        let hideStart = byTok.end;
        if (hideStart >= segmentEnd) continue;
        const gapText = text.slice(hideStart, segmentEnd).includes("\n") ? "\n" : "";
        segments.push({
          byEl: byTok.el,
          byStart: byTok.start,
          byEnd: byTok.end,
          hideStart,
          hideEnd: segmentEnd,
          gapText
        });
      }
      if (segments.length === 0) return;

      for (let i = segments.length - 1; i >= 0; i--) {
        const seg = segments[i];
        const hideStartPos = locateTextPosition(block, seg.hideStart);
        const hideEndPos = locateTextPosition(block, seg.hideEnd);
        if (!hideStartPos || !hideEndPos) continue;
        const hideRange = document.createRange();
        hideRange.setStart(hideStartPos.node, hideStartPos.offset);
        hideRange.setEnd(hideEndPos.node, hideEndPos.offset);
        const fragment = hideRange.extractContents();
        if (!fragment.textContent || fragment.textContent.length === 0) continue;

        const proofTail = document.createElement("span");
        proofTail.className = "bp-proof-tail bp-proof-tail-hidden";
        proofTail.appendChild(fragment);
        hideRange.insertNode(proofTail);
        let gapNode = null;
        if (seg.gapText) {
          gapNode = document.createElement("span");
          gapNode.textContent = seg.gapText;
          proofTail.parentNode.insertBefore(gapNode, proofTail);
        }

        const toggle = seg.byEl;
        if (!(toggle instanceof HTMLElement)) continue;
        toggle.classList.add("bp-proof-by-toggle");
        toggle.tabIndex = 0;
        toggle.setAttribute("role", "button");
        toggle.setAttribute("aria-expanded", "false");
        toggle.setAttribute("aria-label", "Toggle proof");
        toggle.addEventListener("click", function () {
          toggleProof(toggle, proofTail, gapNode);
        });
        toggle.addEventListener("keydown", function (ev) {
          if (!(ev instanceof KeyboardEvent)) return;
          if (ev.key !== "Enter" && ev.key !== " ") return;
          ev.preventDefault();
          toggleProof(toggle, proofTail, gapNode);
        });
      }
    });
  }

  function openDetailsAncestors(elem) {
    let cur = elem && elem.parentElement;
    while (cur) {
      if (cur.tagName === "DETAILS") {
        cur.setAttribute("open", "open");
      }
      cur = cur.parentElement;
    }
  }

  function revealDeclFromHash() {
    const hash = window.location.hash;
    if (!hash || hash.length < 2) return;
    const id = decodeURIComponent(hash.slice(1));
    const target = document.getElementById(id);
    if (!target) return;
    openDetailsAncestors(target);
    document.querySelectorAll("." + targetClass).forEach((el) => el.classList.remove(targetClass));
    document.querySelectorAll("." + targetBlockClass).forEach((el) => el.classList.remove(targetBlockClass));
    target.classList.remove(targetClass);
    void target.offsetWidth;
    target.classList.add(targetClass);
    const block = target.closest("code.hl.lean.block, pre.hl.lean, .example-file");
    if (block) {
      block.classList.remove(targetBlockClass);
      void block.offsetWidth;
      block.classList.add(targetBlockClass);
    }
    target.scrollIntoView({ block: "center", inline: "nearest", behavior: "smooth" });
  }

  applyStyle(getSavedStyle());

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      installSwitcher();
      installProofHider();
      revealDeclFromHash();
    });
  } else {
    installSwitcher();
    installProofHider();
    revealDeclFromHash();
  }

  window.addEventListener("hashchange", revealDeclFromHash);
  document.addEventListener("click", function (ev) {
    const target = ev.target;
    if (!(target instanceof Element)) return;
    const a = target.closest("a[href]");
    if (!a) return;
    const url = new URL(a.getAttribute("href"), window.location.href);
    if (url.pathname !== window.location.pathname || !url.hash) return;
    if (decodeURIComponent(url.hash) !== window.location.hash) return;
    setTimeout(revealDeclFromHash, 0);
  });
})();"##

def toHtml (data : BlockData) (cdata : ComputedData) (_domain : Json) (attrs : Array (String × String))
    (content : Array Output.Html) : Output.Html :=
  open Verso.Output.Html in
  let listItems (items : Array CodeHoverDecl) : Output.Html :=
    if items.isEmpty then
      {{<li class="bp_code_hover_none">"none"</li>}}
    else
      .seq <| items.map fun item =>
        let txt := {{<code>{{.text true item.text}}</code>}}
        {{<li>{{if let some href := item.href then {{<a href={{href}}>{{txt}}</a>}} else txt}}</li>}}
  let codeHover : Output.Html :=
    match cdata.codeHover with
    | none => .empty
    | some hover => {{
      <div class="bp_code_hover" role="tooltip">
        <div class="bp_code_hover_title">{{.text true s!"{hover.label}"}}</div>
        <div class="bp_code_hover_section">
          <span class="bp_code_hover_label">"Lean definitions"</span>
          <ul class="bp_code_hover_list">
            {{listItems hover.definedDefs}}
          </ul>
        </div>
        <div class="bp_code_hover_section">
          <span class="bp_code_hover_label">"Lean theorems/lemmas"</span>
          <ul class="bp_code_hover_list">
            {{listItems hover.definedTheorems}}
          </ul>
        </div>
        <div class="bp_code_hover_section">
          <span class="bp_code_hover_label">"Sorries"</span>
          <ul class="bp_code_hover_list">
            {{listItems hover.sorries}}
          </ul>
        </div>
      </div>
    }}
  let kindText := s!"{data.kind}"
  let labelTextNum := s!"{data.count}"
  let labelText := s!"{data.label}"
  let showLabel := data.kind != .proof_
  let (kindCss, wrapperCss, headingCss, captionCss, labelCss, contentCss) :=
    match data.kind with
    | .def_ =>
      ("definition", "definition_thmwrapper theorem-style-definition bp_kind_definition",
        "definition_thmheading", "definition_thmcaption", "definition_thmlabel", "definition_thmcontent")
    | .thm_ =>
      ("theorem", "theorem_thmwrapper theorem-style-plain bp_kind_theorem",
        "theorem_thmheading", "theorem_thmcaption", "theorem_thmlabel", "theorem_thmcontent")
    | .lem_ =>
      ("lemma", "lemma_thmwrapper theorem-style-plain bp_kind_lemma",
        "lemma_thmheading", "lemma_thmcaption", "lemma_thmlabel", "lemma_thmcontent")
    | .cor_ =>
      ("corollary", "corollary_thmwrapper theorem-style-plain bp_kind_corollary",
        "corollary_thmheading", "corollary_thmcaption", "corollary_thmlabel", "corollary_thmcontent")
    | .proof_ =>
      ("proof", "proof_wrapper bp_kind_proof",
        "proof_heading", "proof_caption", "proof_label", "proof_content")
    | .code_ =>
      ("code", "lemma_thmwrapper theorem-style-plain bp_kind_code",
        "lemma_thmheading", "lemma_thmcaption", "lemma_thmlabel", "lemma_thmcontent")
  let wrapperClass := s!"bp_wrapper {kindCss}_thmwrapper {wrapperCss}"
  let headingClass := s!"bp_heading {headingCss}"
  let captionClass := s!"bp_caption {captionCss}"
  let labelClass := s!"bp_label {labelCss}"
  let contentClass := s!"bp_content {contentCss}"
  let statusMark : Output.Html :=
    if cdata.codeHref.isNone then
      .empty
    else
      let (hasSorriesHere, whereTxt) :=
        if data.kind == .proof_ then
          (cdata.hasProofSorries, "proof")
        else
          (cdata.hasStatementSorries, "statement")
      let mark := if hasSorriesHere then "✗" else "✓"
      let title := if hasSorriesHere then s!"Contains sorries in {whereTxt}" else s!"No sorries in {whereTxt}"
      {{ <span title={{title}}>{{.text true mark}}</span> }}
  {{ <div class={{wrapperClass}} title={{labelText}} {{attrs}}>
       <div class={{headingClass}}>
         <span class={{captionClass}} title={{labelText}}> {{.text true kindText}} </span>
         {{ if showLabel then {{<span class={{labelClass}}> {{.text true labelTextNum}} </span>}} else .empty }}
         <div class="bp_extras thm_header_extras">
           {{statusMark}}
           {{
             if let some href := cdata.codeHref then
               {{<span class="bp_code_link_wrap"><a class="bp_code_link" href={{href}}>"L∃∀N"</a>{{codeHover}}</span>}}
             else .empty
           }}
         </div>
         <div class="bp_hiddenextras thm_header_hidden_extras"> </div>
       </div>
       <div class={{contentClass}}> {{ content }} </div>
     </div>
  }}

/- Informal custom blocks -/
block_extension Block.informal (data : BlockData) where
  -- for TOC
  -- localContentItem _ _ _ := none
  data := toJson data
  traverse id data _contents := do
    -- XXX: (maybe) lift the Except into the main monad error thread
    let .ok blockData@{ kind := _, label, count := _ } := fromJson? (α := BlockData) data
      | logError s!"Malformed data: {data}"
        pure none
    if let .some _d := (← get).getDomainObject? informalDomain label.toString then
      return none
    else
      let path ← (·.path) <$> read
      let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-{label}"
      modify λ s => s.saveDomainObject informalDomain label.toString id
      modify λ s => s.saveDomainObjectData informalDomain label.toString (toJson blockData)
      return none
  toTeX := none
  extraCss := ([blueprintCss, blueprintStyleSwitcherCss] : List String)
  extraJs := ([blueprintStyleSwitcherJs] : List String)
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB id data blocks => do
      let .ok data := fromJson? (α := BlockData) data
        | HtmlT.logError s!"Malformed data: {data}"
          pure .empty
      let s ← HtmlT.state
      let attrs := s.htmlId id
      let dentry : Json := ((s.getDomainObject? informalDomain data.label.toString).map (·.data)).getD (.str "")
      let codeHref : Option String :=
        match s.resolveDomainObject informalCodeDomain data.label.toString with
        | .ok dest => some dest.relativeLink
        | .error _ => none
      let codeData? : Option CodeBlockData :=
        match s.getDomainObject? informalCodeDomain data.label.toString with
        | none => none
        | some obj =>
          match fromJson? (α := CodeBlockData) obj.data with
          | .ok cdata => some cdata
          | .error _ => none
      let getDeclHref (decl : Name) : Option String :=
        match s.resolveDomainObject ``Verso.Genre.Manual.example decl.toString with
        | .ok dest => some dest.relativeLink
        | .error _ =>
          match s.domains.get? ``Verso.Genre.Manual.example with
          | none => none
          | some dom =>
            let pref := decl.toString ++ " (in "
            let cands := dom.objects.foldl (init := #[]) fun acc key _obj =>
              if key == decl.toString || key.startsWith pref then
                acc.push key
              else
                acc
            if cands.size = 1 then
              match s.resolveDomainObject ``Verso.Genre.Manual.example cands[0]! with
              | .ok dest => some dest.relativeLink
              | .error _ => none
            else
              none
      let codeHover : Option CodeHoverData := codeData?.map (fun cdata =>
        mkCodeHoverData data.label cdata.definedDefs cdata.definedTheorems getDeclHref)
      let hasSorries : Bool :=
        match codeData? with
        | none => false
        | some cdata => (cdata.definedDefs ++ cdata.definedTheorems).any (·.hasSorry)
      let hasStatementSorries : Bool :=
        match codeData? with
        | none => false
        | some cdata =>
          (cdata.definedDefs ++ cdata.definedTheorems).any (·.hasTypeSorry)
      let hasProofSorries : Bool :=
        match codeData? with
        | none => false
        | some cdata =>
          (cdata.definedDefs ++ cdata.definedTheorems).any (·.hasProofSorry)
      let cdata := {
        proved := codeData?.isSome && !hasSorries
        codeHref
        codeHover
        hasStatementSorries
        hasProofSorries
      }
      return toHtml data cdata dentry attrs (← blocks.mapM goB)

block_extension Block.informalCode (data : CodeBlockData) where
  data := toJson data
  traverse id data _contents := do
    let .ok cdata@{ label, definedDefs := _, definedTheorems := _ } := fromJson? (α := CodeBlockData) data
      | logError s!"Malformed data: {data}"
        pure none
    if let .some _d := (← get).getDomainObject? informalCodeDomain label.toString then
      pure none
    else
      let path ← (·.path) <$> read
      let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-code-{label}"
      modify λ s => s.saveDomainObject informalCodeDomain label.toString id
      modify λ s => s.saveDomainObjectData informalCodeDomain label.toString (toJson cdata)
      pure none
  toTeX := none
  extraCss := ([blueprintCss, blueprintStyleSwitcherCss] : List String)
  extraJs := ([blueprintStyleSwitcherJs] : List String)
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB id data blocks => do
      let .ok { label, definedDefs, definedTheorems, foldProofs } := fromJson? (α := CodeBlockData) data
        | HtmlT.logError s!"Malformed data: {data}"
          pure .empty
      let s ← HtmlT.state
      let attrs := s.htmlId id
      let summaryText :=
        match s.getDomainObject? informalDomain label.toString with
        | some obj =>
          match fromJson? (α := BlockData) obj.data with
          | .ok b => s!"Code for {b.kind} {b.count}"
          | .error _ => "Code"
        | none => "Code"
      let orderedDecls := sortDeclsByCommand (definedDefs ++ definedTheorems)
      let progressBar : Output.Html :=
        if orderedDecls.isEmpty then
          .empty
        else
          let segments := orderedDecls.map fun decl =>
            let cls :=
              if decl.hasSorry then
                "bp_code_progress_segment bp_code_progress_segment_sorry"
              else
                "bp_code_progress_segment bp_code_progress_segment_ok"
            let weight := max decl.weight 1
            let title :=
              if decl.hasSorry then
                s!"{decl.name}: has sorry"
              else
                s!"{decl.name}: complete"
            {{<span class={{cls}} title={{title}} style={{s!"flex: {weight} 1 0%"}}></span>}}
          {{<span class="bp_code_progress" aria-label="Lean declaration progress">{{segments}}</span>}}
      let summaryHover := codeHoverText label definedDefs definedTheorems
      pure {{
        <details class="bp_code_block" "data-bp-proof-fold"={{if foldProofs then "on" else "off"}} {{attrs}}>
          <summary title={{summaryHover}}>
            <span class="bp_code_summary_text">{{summaryText}}</span>
            {{progressBar}}
            <span class="bp_code_expand_hint"></span>
          </summary>
          {{ ← blocks.mapM goB }}
        </details>
      }}

block_extension Block.texPrelude (data : TexPreludeData) where
  data := toJson data
  traverse _id _data _contents := do
    pure none
  toTeX := none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI _goB _id data _blocks => do
      let .ok { prelude } := fromJson? (α := TexPreludeData) data
        | HtmlT.logError s!"Malformed data: {data}"
          pure .empty
      let injectorJs := r##"
(() => {
  const script = document.currentScript;
  const carrier = script && script.previousElementSibling;
  if (!carrier || !carrier.classList || !carrier.classList.contains('verso-tex-prelude')) return;

  const prelude = carrier.textContent || '';
  if (!window.__versoTexPreludeBlocks) window.__versoTexPreludeBlocks = [];
  if (prelude.trim().length > 0) window.__versoTexPreludeBlocks.push(prelude);

  if (window.__versoTexPreludePatched) return;

  const patchKaTeX = () => {
    if (!window.katex || typeof window.katex.render !== 'function') return false;
    const originalRender = window.katex.render.bind(window.katex);
    window.katex.render = (tex, ...args) => {
      const blocks = window.__versoTexPreludeBlocks || [];
      const fullPrelude = blocks.join('\n').trim();
      const base = tex == null ? '' : String(tex);
      const injected = fullPrelude.length > 0 ? `${fullPrelude}\n${base}` : base;
      return originalRender(injected, ...args);
    };
    window.__versoTexPreludePatched = true;
    return true;
  };

  if (!patchKaTeX()) {
    document.addEventListener('DOMContentLoaded', () => { patchKaTeX(); }, { once: true });
  }
})();
"##
      pure {{
        <script type="text/plain" class="verso-tex-prelude">{{.text false prelude}}</script>
        <script>{{.text false injectorJs}}</script>
      }}

/-- Informal directives -/
@[code_block]
def texPrelude : CodeBlockExpanderOf Unit
  | _, contents => do
    let prelude := contents.getString
    Environment.addTexPrelude prelude
    let data : TexPreludeData := { prelude }
    ``(Block.other (Block.texPrelude $(quote data)) #[])

def expander (kind : BlockKind) : DirectiveExpanderOf Config
  | cfg, contents => do
    let label := cfg.label
    let isProof := (kind == .proof_)
    let kind? := if isProof then none else some (toString kind)
    let blockRef ← getRef
    Environment.push label kind? isProof
    let contents ← contents.mapM elabBlock
    if !isProof then
      Environment.setStatementElab contents
    let count ← Environment.pop blockRef
    -- Make the blueprint widget available when selecting this labeled block.
    activateForLabelDoc label blockRef
    let data : BlockData := {kind, label, count}
    ``(Block.other (Block.informal $(quote data)) #[$contents,*])

@[directive] def «definition» := expander .def_
@[directive] def «lemma_» := expander .lem_
@[directive] def «theorem» := expander .thm_
@[directive] def «corollary» := expander .cor_
@[directive] def «proof» := expander .proof_

-- Have a look to MonadQuotation ()

-- Formal (lean) code blocks.

/-- Interpreting Embedded Lean Code blocks -/
@[code_block]
def lean : CodeBlockExpanderOf Config
  | cfg, contents => do
    let leanCfg : Lean.LeanBlockConfig := { Lean.defaultConfig with name := some (cfg.label : Lean.Name) }
    let res ← Lean.elabCommands leanCfg contents
    let codeBlock := res.block
    let definedDefs := res.definedDefs.map (fun d => ({
      name := d.name
      commandIndex := d.commandIndex
      weight := max (toString d.name).length 1
      hasSorry := d.hasSorry
      hasTypeSorry := d.hasTypeSorry
      hasProofSorry := d.hasProofSorry
    } : CodeDeclData))
    let definedTheorems := res.definedTheorems.map (fun d => ({
      name := d.name
      commandIndex := d.commandIndex
      weight := max (toString d.name).length 1
      hasSorry := d.hasSorry
      hasTypeSorry := d.hasTypeSorry
      hasProofSorry := d.hasProofSorry
    } : CodeDeclData))
    let data : CodeBlockData := {
      label := cfg.label
      definedDefs
      definedTheorems
      foldProofs := verso.blueprint.foldProofs.get (← getOptions)
    }
    let codeRef ← getRef
    let codeInfo : Data.CodeInfo := {
      proved := !definedTheorems.isEmpty
      definedDefs := res.definedDefs.map (fun d => ({
        name := d.name
        commandStx := d.commandStx
        commandIndex := d.commandIndex
        hasSorry := d.hasSorry
        sorryRefs := d.sorryRefs
        hasTypeSorry := d.hasTypeSorry
        hasProofSorry := d.hasProofSorry
        typeSorryRefs := d.typeSorryRefs
        proofSorryRefs := d.proofSorryRefs
      } : Data.DefinedDecl))
      definedTheorems := res.definedTheorems.map (fun d => ({
        name := d.name
        commandStx := d.commandStx
        commandIndex := d.commandIndex
        hasSorry := d.hasSorry
        sorryRefs := d.sorryRefs
        hasTypeSorry := d.hasTypeSorry
        hasProofSorry := d.hasProofSorry
        typeSorryRefs := d.typeSorryRefs
        proofSorryRefs := d.proofSorryRefs
      } : Data.DefinedDecl))
    }
    Environment.registerCode cfg.label codeRef (some codeInfo)
    activateForLabelDoc cfg.label codeRef
    ``(Block.other (Block.informalCode $(quote data)) #[$codeBlock])

/-- Internal Lean setup blocks:
executed but not rendered and not tracked as blueprint code blocks. -/
@[code_block]
def internal : CodeBlockExpanderOf Unit
  | _, contents => do
    let leanCfg : Lean.LeanBlockConfig := { Lean.defaultConfig with «show» := false, name := none }
    let _ ← Lean.elabCommands leanCfg contents
    ``(Block.concat #[])

structure InlineData where
  label : Data.Label
  block : Option BlockData
deriving FromJson, ToJson, Quote

def Data.Node.toBlockInfo (node : Data.Node) (label : Data.Label) : BlockData :=
  let kind :=
    match node.kind with
    | "Definition" => BlockKind.def_
    | "Lemma" => BlockKind.lem_
    | "Theorem" => BlockKind.thm_
    | "Proof" => BlockKind.proof_
    | "Corollary" => BlockKind.cor_
    | "Lean Code" => BlockKind.code_
    | _ => BlockKind.lem_
  { kind, label, count := node.count }

inline_extension Inline.informal (data : InlineData) where
  data := toJson data
  traverse _id data contents := do
    let .ok info@{ label, block } := fromJson? (α := InlineData) data
      | logError s!"Malformed data in Inline.informal traversal: {data}"
        pure none
    if block.isSome then
      pure none
    else
      let some obj := (← get).getDomainObject? informalDomain label.toString
        | pure none
      let .ok bdata := fromJson? (α := BlockData) obj.data
        | logError s!"Malformed informal domain data for {label}: {obj.data}"
          pure none
      pure <| some (.other (Inline.informal { info with block := some bdata }) contents)
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun goI _id data inlines => do
      let .ok { label, block } := fromJson? (α := InlineData) data
        | HtmlT.logError "Malformed data in Inline.informal traversal"
          pure .empty
      let st ← HtmlT.state
      let resolvedBlock : Option BlockData :=
        match block with
        | some b => some b
        | none =>
          match st.getDomainObject? informalDomain label.toString with
          | none => none
          | some obj =>
            match fromJson? (α := BlockData) obj.data with
            | .ok b => some b
            | .error _ => none
      let href : Option String :=
        match st.resolveDomainObject informalDomain label.toString with
        | .ok dest => some dest.relativeLink
        | .error _ => none
      match resolvedBlock, inlines.isEmpty with
      | none, true =>
        return {{ <span> "[??]" </span> }}
      | none, false =>
        return {{ <span> {{ ← inlines.mapM goI }} </span> }}
      | some block, true =>
        let labelText := s!"{label}"
        let titleText := s!"{block.kind} {block.count}"
        if let some href := href then
          return {{ <span> <a href={{href}} title={{labelText}}> {{titleText}} </a> </span> }}
        else
          return {{ <span title={{labelText}}> {{titleText}} </span> }}
      | some _block, false =>
        let labelText := s!"{label}"
        if let some href := href then
          return {{ <span> <a href={{href}} title={{labelText}}> {{ ← inlines.mapM goI }} </a> </span> }}
        else
          return {{ <span> {{ ← inlines.mapM goI }} </span> }}
  toTeX := none

@[role]
def uses : RoleExpanderOf Config
  | cfg, contents => do
    let contents ← contents.mapM elabInline
    let label := cfg.label
    let node ← Environment.getNode? label
    let useRef ← getRef
    Environment.addDep useRef label
    if node.isSome then
      activateForLabelDoc label useRef
    let data : InlineData := { label, block := node.map (fun n => n.toBlockInfo label) }
    ``(Inline.other (Inline.informal $(quote data)) #[$contents,*])

-- Extra stuff
@[code_block]
def rocq : CodeBlockExpanderOf Unit
  | _cfg, contents => do
    ``(Block.code $contents)

end Informal
