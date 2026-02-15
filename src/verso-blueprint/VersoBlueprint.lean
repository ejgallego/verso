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

structure ComputedData where
  proved : Bool := false

def toHtml (data : BlockData) (cdata : ComputedData) (_domain : Json) (content : Array Output.Html) : Output.Html :=
  open Verso.Output.Html in
  if data.kind = .code_ then
    {{ "hidden lean code" }}
  else
    {{ <div class="bp_wrapper" id=s!"{data.label}">
         <div class="bp_heading">
           <span class="bp_caption"> s!"{data.kind}" </span>
           <span class="bp_label"> s!"{data.label}" </span>
           <div class="bp_extras"> {{ if cdata.proved then "✓" else "" }} </div>
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
    let .ok { kind := _, label, count := _ } := fromJson? (α := BlockData) data
      | logError s!"Malformed data: {data}"
        pure none
    let d : Option Multi.Domain := (← get).domains.get? ``informal
    let size : Nat := d.map (·.objects.size) |>.getD 0
    if let .some _d := (← get).getDomainObject? ``informal label.toString then
      return none
    else
      let n_entry := size + 1
      modify λ s => s.saveDomainObject ``informal label.toString id
      modify λ s => s.saveDomainObjectData ``informal label.toString n_entry
      return none
  toTeX := none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB _id data blocks => do
      let .ok data := fromJson? (α := BlockData) data
        | HtmlT.logError s!"Malformed data: {data}"
          pure .empty
      let s ← HtmlT.state
      let dentry : Json := ((s.getDomainObject? ``informal data.label.toString).map (·.data)).getD (.str "")
      let cdata := { proved := true }
      return toHtml data cdata dentry (← blocks.mapM goB)

/-- Informal directives -/
def expander (kind : BlockKind) : DirectiveExpanderOf Config
  | cfg, contents => do
    let label := cfg.label
    let isProof := (kind == .proof_)
    Environment.push label isProof
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

/-- Formal (lean) code blocks -/

-- XXX: Needs fixing upstream, maybe fork?
def default_config : InlineLean.LeanBlockConfig where
  «show» := true
  keep := true
  name := none
  error := false
  fresh := false

/-- Interpreting Embedded Lean Code blocks -/
@[code_block]
def lean : CodeBlockExpanderOf Config
  | cfg, contents => do
    -- XXX: do something fun with cfg.label
    let data : BlockData := { kind := .code_, label := cfg.label, count := 0}
    let codeBlock ← InlineLean.lean default_config contents
    ``(Block.other (Block.informal $(quote data)) #[$codeBlock])

structure InlineData where
  label : Data.Label
  block : Option BlockData
deriving FromJson, ToJson, Quote

inline_extension Inline.informal (data : InlineData) where
  data := toJson data
  traverse _id _data _contents := pure none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun goI _id data inlines => do
      let .ok { label, block } := fromJson? (α := InlineData) data
        | HtmlT.logError "Malformed data in Inline.informal traversal"
          pure .empty
      match block, inlines.isEmpty with
      | none, true =>
        return {{ <span> "[??]" </span> }}
      | none, false =>
        return {{ <span> {{ ← inlines.mapM goI }} </span> }}
      | some block, true =>
        return {{ <span> <a href="">s!"{block.kind} {block.count}" </a> </span> }}
      | some block, false =>
        return {{ <span> <a href=""> {{ ← inlines.mapM goI }} </a> </span> }}
  toTeX := none

@[role]
def uses : RoleExpanderOf Config
  | cfg, contents => do
    let contents ← contents.mapM elabInline
    let label := cfg.label
    let _node ← Environment.getNode? label
    let block := some { kind := .lem_, label, count := 1 }
    Environment.addDep (← getRef) label
    let data : InlineData := { label, block }
    ``(Inline.other (Inline.informal $(quote data)) #[$contents,*])

-- Extra stuff
@[code_block]
def rocq : CodeBlockExpanderOf Unit
  | _cfg, contents => do
    ``(Block.code $contents)

end Informal
