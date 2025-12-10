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
  label : Option String := none

section
variable [Monad m] [MonadInfoTree m] [MonadLiftT CoreM m] [MonadEnv m] [MonadError m] [MonadFileMap m]

def Config.parse  : ArgParse m Config :=
  Config.mk <$> .named `label .string true

instance : FromArgs Config m where
  fromArgs := Config.parse

end

/- Informal custom blocks -/
block_extension Block.informal (label : String) where
  -- for TOC
  -- localContentItem _ _ _ := none
  data := .str label
  traverse id data _contents := do
    let .str label := data
      | logError "Malformed data"
        pure none
    let d : Option Multi.Domain := (← get).domains.get? ``informal
    let size : Nat := d.map (·.objects.size) |>.getD 0
    if let .some _d := (← get).getDomainObject? ``informal label then
      return none
    else
      let n_entry := size + 1
      modify λ s => s.saveDomainObject ``informal label id
      modify λ s => s.saveDomainObjectData ``informal label n_entry
      return none
  toTeX := none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB _id data blocks => do
      let .str label := data
        | HtmlT.logError "Malformed data"
          pure .empty
      let s ← HtmlT.state
      if let .some n_entry := s.getDomainObject? ``informal label then
        return {{ <details> <summary> s!"{label} {n_entry.data}" </summary> {{ ← blocks.mapM goB }} </details> }}
      else
        return {{ <details> <summary> s!"{label}" </summary> {{ ← blocks.mapM goB }} </details> }}

/-- Informal directives -/
def expander (kind : String) : DirectiveExpanderOf Config
  | cfg, contents => do
    Environment.push (Name.mkSimple $ cfg.label.getD "nolabel")
    let contents ← contents.mapM elabBlock
    Environment.pop
    let label : String := s!"{kind} {cfg.label}"
    ``(Block.other (Block.informal $(quote label))
        #[Block.para #[Inline.text $(quote label)],$contents,*])

@[directive] def «definition» := expander "Definition"
@[directive] def «lemma» := expander "Lemma"
@[directive] def «theorem» := expander "Theorem"
@[directive] def «corollary» := expander "Corollary"
@[directive] def «proof» := expander "Proof"

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
    let label : String := s!"Code {cfg.label}"
    let codeBlock ← InlineLean.lean default_config contents
    ``(Block.other (Block.informal $(quote label)) #[$codeBlock])

inline_extension Inline.informal (label : String) where
  data := .str label
  traverse _id _data _contents := pure none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun goI _id data inlines => do
      let .str label := data
        | HtmlT.logError "Malformed data"
          pure .empty
      return {{ <span> s!"{label}" {{ ← inlines.mapM goI }} </span> }}
  toTeX := none

@[role]
def uses : RoleExpanderOf Config
  | cfg, contents => do
    let contents ← contents.mapM elabInline
    let label : String := s!"{cfg.label}"
    Environment.addDep (← getRef) (cfg.label.getD "nolabel").toName
    ``(Inline.other (Inline.informal $(quote label)) #[$contents,*])

-- Extra stuff
@[code_block]
def rocq : CodeBlockExpanderOf Unit
  | _cfg, contents => do
    ``(Block.code $contents)

end Informal
