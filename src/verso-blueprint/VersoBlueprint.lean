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
import VersoBlueprint.Commands
import VersoBlueprint.Lean
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
  lean : Option String := none
--  hide : Bool := false

section
variable [Monad m] [MonadInfoTree m] [MonadLiftT CoreM m] [MonadEnv m] [MonadError m] [MonadFileMap m]

-- def _root_.Verso.ArgParse.ValDesc.array (elem : ValDesc m e) : ValDesc m (Array e) where
--   description := .text "array parser, using list syntax"
--   signature := { ident := false, string := false, num := false }
--   get := sorry

def Config.parse  : ArgParse m Config :=
  Config.mk <$> (Name.mkSimple <$> .positional `label .string) <*> .named `lean .string true

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

structure CodeBlockData where
  label : Data.Label
  definedConsts : Array Name := #[]
  definedProofs : Array Name := #[]
deriving FromJson, ToJson, Quote

structure ComputedData where
  proved : Bool := false
  codeHref : Option String := none
  codeHover : Option String := none

def codeHoverText (label : Data.Label) (definedConsts definedProofs : Array Name) : String :=
  if definedConsts.isEmpty && definedProofs.isEmpty then
    s!"{label}"
  else
    let defs :=
      if definedConsts.isEmpty then
        "none"
      else
        String.intercalate ", " (definedConsts.toList.map toString)
    let prfs :=
      if definedProofs.isEmpty then
        "none"
      else
        String.intercalate ", " (definedProofs.toList.map toString)
    s!"{label}\nLean definitions: {defs}\nLean proofs: {prfs}"

def blueprintCss : String := r##"
.bp_wrapper {
  --bp-border: #dbe4f0;
  --bp-heading-bg: #f8fafc;
  --bp-caption-bg: #e2e8f0;
  --bp-caption-fg: #0f172a;
  --bp-content-fg: #0f172a;
  --bp-link-bg: #0f172a;
  --bp-link-fg: #f8fafc;
  scroll-margin-top: 1rem;
  margin: 1rem 0;
  border: 1px solid var(--bp-border);
  border-radius: 0.45rem;
  background: white;
  overflow: clip;
}

.bp_heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.45rem 0.6rem;
  border-bottom: 1px solid var(--bp-border);
  background: var(--bp-heading-bg);
}

.bp_caption {
  display: inline-block;
  padding: 0.1rem 0.45rem;
  border-radius: 999px;
  background: var(--bp-caption-bg);
  color: var(--bp-caption-fg);
  font-size: 0.84rem;
  font-weight: 650;
  letter-spacing: 0.01em;
}

.bp_extras {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
}

.bp_code_link {
  display: inline-block;
  padding: 0.08rem 0.4rem;
  border-radius: 0.3rem;
  font-size: 0.8rem;
  font-weight: 650;
  background: var(--bp-link-bg);
  color: var(--bp-link-fg);
  text-decoration: none;
}

.bp_code_link:hover {
  text-decoration: underline;
}

.bp_content {
  color: var(--bp-content-fg);
  padding: 0.75rem 0.85rem 0.85rem;
}

.bp_content > :first-child {
  margin-top: 0;
}

.bp_content > :last-child {
  margin-bottom: 0;
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

def toHtml (data : BlockData) (cdata : ComputedData) (_domain : Json) (attrs : Array (String × String))
    (content : Array Output.Html) : Output.Html :=
  open Verso.Output.Html in
  let titleText := s!"{data.kind} {data.count}"
  let labelText := s!"{data.label}"
  {{ <div class="bp_wrapper" title={{labelText}} {{attrs}}>
       <div class="bp_heading">
         <span class="bp_caption" title={{labelText}}> {{titleText}} </span>
         <div class="bp_extras">
           {{ if cdata.proved then "✓" else "" }}
           {{
             if let some href := cdata.codeHref then
               let hover := cdata.codeHover.getD labelText
               {{ <a class="bp_code_link" href={{href}} title={{hover}}>"L∃∀N"</a> }}
             else ""
           }}
         </div>
         <div class="bp_hiddenextras"> </div>
       </div>
       <div class="bp_content"> {{ content }} </div>
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
  extraCss := singleton ⟨blueprintCss⟩
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
      let codeHover : Option String :=
        match s.getDomainObject? informalCodeDomain data.label.toString with
        | none => none
        | some obj =>
          match fromJson? (α := CodeBlockData) obj.data with
          | .ok cdata => some (codeHoverText data.label cdata.definedConsts cdata.definedProofs)
          | .error _ => none
      let cdata := { proved := true, codeHref, codeHover }
      return toHtml data cdata dentry attrs (← blocks.mapM goB)

block_extension Block.informalCode (data : CodeBlockData) where
  data := toJson data
  traverse id data _contents := do
    let .ok cdata@{ label, definedConsts := _, definedProofs := _ } := fromJson? (α := CodeBlockData) data
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
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB id data blocks => do
      let .ok { label, definedConsts, definedProofs } := fromJson? (α := CodeBlockData) data
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
      let summaryHover := codeHoverText label definedConsts definedProofs
      pure {{
        <details class="bp_code_block" {{attrs}}>
          <summary title={{summaryHover}}> {{summaryText}} </summary>
          {{ ← blocks.mapM goB }}
        </details>
      }}

/-- Informal directives -/
def expander (kind : BlockKind) : DirectiveExpanderOf Config
  | cfg, contents => do
    let label := cfg.label
    let isProof := (kind == .proof_)
    let kind? := if isProof then none else some (toString kind)
    Environment.push label kind? isProof
    let contents ← contents.mapM elabBlock
    let ref ← getRef
    let proof := if isProof then some ref else none
    let count ← Environment.pop proof
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
    let definedConsts := res.definedConsts
    let definedProofs := res.definedProofs
    let data : CodeBlockData := { label := cfg.label, definedConsts, definedProofs }
    let codeRef ← getRef
    let codeInfo : Data.CodeInfo := { proved := !definedProofs.isEmpty, definedConsts, definedProofs }
    Environment.registerCode cfg.label codeRef (some codeInfo)
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
    Environment.addDep (← getRef) label
    let data : InlineData := { label, block := node.map (fun n => n.toBlockInfo label) }
    ``(Inline.other (Inline.informal $(quote data)) #[$contents,*])

-- Extra stuff
@[code_block]
def rocq : CodeBlockExpanderOf Unit
  | _cfg, contents => do
    ``(Block.code $contents)

end Informal
