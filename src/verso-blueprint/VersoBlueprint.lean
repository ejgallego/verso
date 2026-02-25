/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias, David Thrane Christiansen
-/

-- XXX VersoManual is not module yet
-- module

-- Blueprint library extending the Verso `Manual` genre.

import Lean.Elab.InfoTree.Types

import VersoManual

import VersoBlueprint.Data
import VersoBlueprint.Environment
import VersoBlueprint.Attribute
import VersoBlueprint.Cite
import VersoBlueprint.Commands
import VersoBlueprint.Lean
import VersoBlueprint.NameParsing
import VersoBlueprint.Resolve
import VersoBlueprint.StyleSwitcher
import VersoBlueprint.TexPrelude
import VersoBlueprint.Widget
import VersoBlueprint.Profiling

set_option doc.verso true

open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse
open Lean.Doc.Syntax
open Lean Elab

namespace Informal

/- "Informal" Verso objects:

  - An informal verso object is identified by a label, and lives in the `informal` Verso domain.
  - For IO (Informal Object), we associate a `Data` entry, which mainly captures other objects the IO depends on
  - Objects are declared via directives / code blocks
  - Dependencies are declared via the {uses ...}`...` role, which _must_ be inside a directive.

Elaboration, traversal, and rendering are standard, using {ref VersoManual} helpers for custom blocks and inlines.

-/

/-- Domain for informal-like objects; each informal object is
  characterized by its canonical name declared by the user. -/
def _informal : Domain := {}

/-- Name used in {name}`TraverseState.domains` for informal objects. -/
def informalDomain : Name := Resolve.informalDomainName

/-- Name used in {name}`TraverseState.domains` for informal Lean code blocks. -/
def informalCodeDomain : Name := Resolve.informalCodeDomainName

/-- Configuration for directives / code-blocks. Q: should we allow non-labelled informal objects? -/
structure Config where
  label : Data.Label
  labelSyntax : Syntax := Syntax.missing
  lean : Option String := none
  leanok : Option Bool := none
  externalCode : Array Data.ExternalRef := #[]
  invalidExternalCode : Array String := #[]
--  hide : Bool := false

section
variable [Monad m] [MonadInfoTree m] [MonadLiftT CoreM m] [MonadEnv m] [MonadError m] [MonadFileMap m]

private def splitExternalCodeRefs (s : String) : Array String :=
  NameParsing.splitCsvNormalized s

private def parseExternalCodeList (lean : Option String) : Array Data.ExternalRef × Array String :=
  match lean with
  | none => (#[], #[])
  | some s =>
    (splitExternalCodeRefs s).foldl (init := (#[], #[])) fun (acc, invalid) ref =>
      match NameParsing.parseNameE ref with
      | .ok name =>
        let extRef := Data.ExternalRef.ofName name .directiveLean
        if acc.any (fun entry => entry.canonical == extRef.canonical) then
          (acc, invalid)
        else
          (acc.push extRef, invalid)
      | .error err =>
        (acc, invalid.push s!"{ref} ({err})")

private def pushExternalRefDedup (acc : Array Data.ExternalRef) (ref : Data.ExternalRef) : Array Data.ExternalRef :=
  if acc.any (fun entry => entry.canonical == ref.canonical) then
    acc
  else
    acc.push ref

private def parsedExternalRef (ref : Data.ExternalRef) : Data.ExternalRef :=
  { ref with canonical := ref.written.eraseMacroScopes }

private def resolvedExternalRef (ref : Data.ExternalRef) (resolved : Name) : Data.ExternalRef :=
  { written := ref.written, canonical := resolved.eraseMacroScopes, origin := ref.origin }

private def resolveExternalNameCandidates [MonadResolveName m] [MonadOptions m]
    [MonadLog m] [AddMessageContext m]
    (name : Name) : m (Array Name) := do
  let resolved ← Lean.resolveGlobalName name (enableLog := false)
  return resolved.foldl (init := #[]) fun acc (candidate, fieldList) =>
    if fieldList.isEmpty && !acc.contains candidate then
      acc.push candidate
    else
      acc

private def resolveExternalCodeList [MonadResolveName m] [MonadOptions m]
    [MonadLog m] [AddMessageContext m]
    (label : Name) (refs : Array Data.ExternalRef) : m (Array Data.ExternalRef) := do
  refs.foldlM (init := #[]) fun acc ref => do
    let candidates ← resolveExternalNameCandidates ref.written
    match candidates.toList with
    | [] =>
      logWarning m!"Label {label}: external Lean name '{ref.written}' could not be resolved in current namespace/open declarations; keeping parsed name"
      return pushExternalRefDedup acc (parsedExternalRef ref)
    | [resolved] =>
      return pushExternalRefDedup acc (resolvedExternalRef ref resolved)
    | many =>
      logWarning m!"Label {label}: external Lean name '{ref.written}' is ambiguous ({String.intercalate ", " (many.map toString)}); keeping parsed name"
      return pushExternalRefDedup acc (parsedExternalRef ref)

def Config.parse  : ArgParse m Config :=
  (fun (labelArg : Verso.ArgParse.WithSyntax String) lean leanok =>
    let (externalCode, invalidExternalCode) := parseExternalCodeList lean
    {
      label := Name.mkSimple labelArg.val
      labelSyntax := labelArg.syntax
      lean := lean
      leanok := leanok
      externalCode := externalCode
      invalidExternalCode := invalidExternalCode
    }) <$> .positional `label (.withSyntax .string) <*> .named `lean .string true
        <*> .named `leanok .bool true

instance : FromArgs Config m where
  fromArgs := Config.parse

end

structure ExternalDeclStatus where
  decl : Name
  present : Bool := false
deriving Repr, Inhabited, FromJson, ToJson, Quote

inductive BlockCodeStatus where
  | none
  | userOk
  | external (decls : Array ExternalDeclStatus)
deriving Repr, Inhabited, FromJson, ToJson, Quote

def BlockCodeStatus.ofCodeRef (env : Lean.Environment) (codeRef? : Option Data.CodeRef) : BlockCodeStatus :=
  match codeRef? with
  | some .userOk => .userOk
  | some (.external decls) =>
    .external <| decls.map fun decl =>
      { decl := decl.written, present := (env.find? decl.canonical).isSome }
  | _ => .none

structure BlockData where
  kind : Data.NodeKind
  label : Data.Label
  count : Nat
  isProof : Bool := false
  codeStatus : BlockCodeStatus := .none
deriving FromJson, ToJson, Quote

structure CodeDeclData where
  name : Name
  commandIndex : Nat := 0
  weight : Nat := 1
  hasSorry : Bool := false
  hasTypeSorry : Bool := false
  hasProofSorry : Bool := false
deriving FromJson, ToJson, Quote

def CodeDeclData.ofLiterateDef (d : Data.LiterateDef) : CodeDeclData :=
  {
    name := d.name
    commandIndex := d.commandIndex
    weight := max d.commandLines 1
    hasSorry := d.hasSorry
    hasTypeSorry := d.hasTypeSorry
    hasProofSorry := false
  }

def CodeDeclData.ofLiterateThm (d : Data.LiterateThm) : CodeDeclData :=
  {
    name := d.name
    commandIndex := d.commandIndex
    weight := max d.commandLines 1
    hasSorry := d.hasSorry
    hasTypeSorry := d.hasTypeSorry
    hasProofSorry := d.hasProofSorry
  }

structure CodeBlockData where
  label : Data.Label
  definedDefs : Array CodeDeclData := #[]
  definedTheorems : Array CodeDeclData := #[]
  foldProofs : Bool := true
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

structure ExternalHoverDecl where
  decl : Name
  href : Option String := none
  present : Bool := false

structure ComputedData where
  proved : Bool := false
  codeHref : Option String := none
  codeHover : Option CodeHoverData := none
  manualStatus : Bool := false
  externalDecls : Array ExternalHoverDecl := #[]
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
  background: #eab308;
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

.bp_status_mark {
  font-size: 0.78rem;
  font-weight: 600;
}

.bp_external_badge {
  font-size: 0.74rem;
  font-weight: 600;
  border: 1px solid #cbd5e1;
  border-radius: 0.3rem;
  padding: 0.08rem 0.35rem;
  background: #f8fafc;
}

.bp_external_decl_ok {
  color: #166534;
}

.bp_external_decl_missing {
  color: #b91c1c;
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

def blueprintStyleSwitcherCss : String := StyleSwitcher.css

def blueprintStyleSwitcherJs : String := StyleSwitcher.jsInteractive

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
  let externalListItems (items : Array ExternalHoverDecl) : Output.Html :=
    if items.isEmpty then
      {{<li class="bp_code_hover_none">"none"</li>}}
    else
      .seq <| items.map fun item =>
        let declTxt := {{<code>{{.text true s!"{item.decl}"}}</code>}}
        let declNode :=
          if let some href := item.href then
            {{<a href={{href}}>{{declTxt}}</a>}}
          else
            declTxt
        let statusTxt := if item.present then "(has Lean declaration)" else "(missing Lean declaration)"
        let statusClass := if item.present then "bp_external_decl_ok" else "bp_external_decl_missing"
        {{<li>{{declNode}} " " <span class={{statusClass}}>{{.text true statusTxt}}</span></li>}}
  let externalHover : Output.Html :=
    if cdata.externalDecls.isEmpty then
      .empty
    else
      {{
        <div class="bp_code_hover" role="tooltip">
          <div class="bp_code_hover_title">"External Lean references"</div>
          <div class="bp_code_hover_section">
            <ul class="bp_code_hover_list">
              {{externalListItems cdata.externalDecls}}
            </ul>
          </div>
        </div>
      }}
  let kindText := if data.isProof then "Proof" else s!"{data.kind}"
  let labelTextNum := s!"{data.count}"
  let labelText := s!"{data.label}"
  let showLabel := !data.isProof
  let (kindCss, wrapperCss, headingCss, captionCss, labelCss, contentCss) :=
    if data.isProof then
      ("proof", "proof_wrapper bp_kind_proof",
        "proof_heading", "proof_caption", "proof_label", "proof_content")
    else
      match data.kind with
      | .definition =>
        ("definition", "definition_thmwrapper theorem-style-definition bp_kind_definition",
          "definition_thmheading", "definition_thmcaption", "definition_thmlabel", "definition_thmcontent")
      | .theorem =>
        ("theorem", "theorem_thmwrapper theorem-style-plain bp_kind_theorem",
          "theorem_thmheading", "theorem_thmcaption", "theorem_thmlabel", "theorem_thmcontent")
      | .lemma =>
        ("lemma", "lemma_thmwrapper theorem-style-plain bp_kind_lemma",
          "lemma_thmheading", "lemma_thmcaption", "lemma_thmlabel", "lemma_thmcontent")
      | .corollary =>
        ("corollary", "corollary_thmwrapper theorem-style-plain bp_kind_corollary",
          "corollary_thmheading", "corollary_thmcaption", "corollary_thmlabel", "corollary_thmcontent")
  let wrapperClass := s!"bp_wrapper {kindCss}_thmwrapper {wrapperCss}"
  let headingClass := s!"bp_heading {headingCss}"
  let captionClass := s!"bp_caption {captionCss}"
  let labelClass := s!"bp_label {labelCss}"
  let contentClass := s!"bp_content {contentCss}"
  let statusMark : Output.Html :=
    if !cdata.externalDecls.isEmpty then
      let total := cdata.externalDecls.size
      let found := cdata.externalDecls.foldl (init := 0) fun acc decl => acc + (if decl.present then 1 else 0)
      let missing := total - found
      let title :=
        if missing == 0 then
          s!"External Lean names ({total}) are present"
        else
          s!"External Lean names: {found} present, {missing} missing"
      {{<span class="bp_code_link_wrap"><span class="bp_external_badge" title={{title}}>s!"external ({found}/{total})"</span>{{externalHover}}</span>}}
    else if cdata.manualStatus then
      {{ <span class="bp_status_mark" title="Marked complete via (leanok := true)">"✓ (manually set)"</span> }}
    else if cdata.codeHref.isNone then
      .empty
    else
      let (hasSorriesHere, whereTxt) :=
        if data.isProof then
          (cdata.hasProofSorries, "proof")
        else
          (cdata.hasStatementSorries, "statement")
      let mark := if hasSorriesHere then "✗" else "✓"
      let title := if hasSorriesHere then s!"Contains sorries in {whereTxt}" else s!"No sorries in {whereTxt}"
      {{ <span class="bp_status_mark" title={{title}}>{{.text true mark}}</span> }}
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
    match fromJson? (α := BlockData) data with
    | .error err =>
      logError s!"Malformed data ({err}): {data}"
      pure none
    | .ok blockData =>
      let label := blockData.label
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
      match fromJson? (α := BlockData) data with
      | .error err =>
        HtmlT.logError s!"Malformed data ({err}): {data}"
        pure .empty
      | .ok data =>
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
          Resolve.resolveExampleDeclHref? s decl
        let codeHover : Option CodeHoverData := codeData?.map (fun cdata =>
          mkCodeHoverData data.label cdata.definedDefs cdata.definedTheorems getDeclHref)
        let externalDecls : Array ExternalHoverDecl :=
          match data.codeStatus with
          | .external decls =>
            decls.map fun decl => { decl := decl.decl, href := getDeclHref decl.decl, present := decl.present }
          | _ => #[]
        let manualStatus : Bool :=
          match data.codeStatus with
          | .userOk => true
          | _ => false
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
          manualStatus
          externalDecls
          hasStatementSorries
          hasProofSorries
        }
        return toHtml data cdata dentry attrs (← blocks.mapM goB)

block_extension Block.informalCode (data : CodeBlockData) where
  data := toJson data
  traverse id data _contents := do
    let .ok cdata@{ label, definedDefs := _, definedTheorems := _, foldProofs := _ } := fromJson? (α := CodeBlockData) data
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

private def expanderImpl (kind : Data.NodeKind) (isProof : Bool := false) : DirectiveExpanderOf Config
  | cfg, contents => do
    let blockRef ← getRef
    let label := cfg.label
    let kind? := if isProof then none else some kind
    let resolvedExternalCode ← resolveExternalCodeList label cfg.externalCode
    let hasExternal := !resolvedExternalCode.isEmpty
    let hasLeanok := cfg.leanok.getD false
    if !cfg.invalidExternalCode.isEmpty then
      logWarning m!"Label {label}: ignoring malformed names in '(lean := ...)' ({String.intercalate ", " cfg.invalidExternalCode.toList})"
    if hasExternal && hasLeanok then
      logError m!"Label {label} cannot use '(leanok := true)' together with '(lean := ...)'"
    let codeHint : Option Data.CodeRef :=
      if hasExternal then
        some (.external resolvedExternalCode)
      else if hasLeanok then
        some .userOk
      else
        none
    Environment.push label kind? isProof codeHint
    let contents ← contents.mapM elabBlock
    if !isProof then
      Environment.setStatementElab contents
    let count ← Environment.pop blockRef
    let node? ← Environment.getNode? label
    let env ← getEnv
    let nodeCodeRef? := node?.bind (·.code)
    let nodeKind := node?.map (·.kind) |>.getD kind
    let codeStatus := BlockCodeStatus.ofCodeRef env nodeCodeRef?
    -- Make the blueprint widget available when selecting this labeled block.
    activateForLabelDoc label blockRef
    let data : BlockData := { kind := nodeKind, label, count, isProof, codeStatus }
    ``(Block.other (Block.informal $(quote data)) #[$contents,*])

private def directiveName (kind : Data.NodeKind) (isProof : Bool): String :=
  if isProof then "proof" else (toString kind).toLower

private def expander (kind : Data.NodeKind) (isProof : Bool := false) : DirectiveExpanderOf Config
  | cfg, contents => do
    let label := (directiveName kind isProof)
    Profile.withDocElab "directive" label <|
      (expanderImpl kind isProof) cfg contents

@[directive] def «definition» := expander .definition
@[directive] def «lemma_» := expander .lemma
@[directive] def «theorem» := expander .theorem
@[directive] def «corollary» := expander .corollary
@[directive] def «proof» := expander .lemma (isProof := true)

/-- Interpreting Embedded Lean Code blocks -/
private def leanImpl : CodeBlockExpanderOf Config
  | cfg, contents => do
    let leanCfg : Lean.LeanBlockConfig := { Lean.defaultConfig with name := some (cfg.label : Lean.Name) }
    let res ← Lean.elabCommands leanCfg contents
    let codeBlock := res.block
    let definedDefs := res.definedDefs.map CodeDeclData.ofLiterateDef
    let definedTheorems := res.definedTheorems.map CodeDeclData.ofLiterateThm
    let data : CodeBlockData := {
      label := cfg.label
      definedDefs
      definedTheorems
      foldProofs := verso.blueprint.foldProofs.get (← getOptions)
    }
    let codeRef ← getRef
    Environment.registerCode cfg.label codeRef res.definedDefs res.definedTheorems
    activateForLabelDoc cfg.label codeRef
    ``(Block.other (Block.informalCode $(quote data)) #[$codeBlock])

@[code_block]
def lean : CodeBlockExpanderOf Config
  | cfg, contents => do
    Profile.withDocElab "code_block" "lean" <| leanImpl cfg contents

/-- Internal Lean setup blocks:
executed but not rendered and not tracked as blueprint code blocks. -/
private def internalImpl : CodeBlockExpanderOf Unit
  | _, contents => do
    let leanCfg : Lean.LeanBlockConfig := { Lean.defaultConfig with «show» := false, name := none }
    let _ ← Lean.elabCommands leanCfg contents
    ``(Block.concat #[])

@[code_block]
def internal : CodeBlockExpanderOf Unit
  | cfg, contents => do
    Profile.withDocElab "code_block" "internal" <| internalImpl cfg contents

structure InlineData where
  label : Data.Label
  block : Option BlockData
deriving FromJson, ToJson, Quote

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

private def Data.Node.toBlockInfo (node : Data.Node) (label : Data.Label) : BlockData :=
  { kind := node.kind, label, count := node.count }

private def usesImpl : RoleExpanderOf Config
  | cfg, contents => do
    let contents ← contents.mapM elabInline
    let label := cfg.label
    let node ← Environment.getNode? label
    let useRef ← getRef
    Environment.addDep useRef label
    -- Activate the widget if we can resolve the reference
    if node.isSome then
      activateForLabelDoc label useRef
    let data : InlineData := { label, block := node.map (fun n => n.toBlockInfo label) }
    ``(Inline.other (Inline.informal $(quote data)) #[$contents,*])

@[role]
def uses : RoleExpanderOf Config
  | cfg, contents => do
    Profile.withDocElab "role" "uses" <| usesImpl cfg contents

-- Extra stuff
private def rocqImpl : CodeBlockExpanderOf Unit
  | _cfg, contents => do
    ``(Block.code $contents)

@[code_block]
def rocq : CodeBlockExpanderOf Unit
  | cfg, contents => do
    Profile.withDocElab "code_block" "rocq" <| rocqImpl cfg contents

end Informal
