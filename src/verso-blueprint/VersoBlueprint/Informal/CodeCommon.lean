/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Data

namespace Informal

open Verso Doc Elab
open Lean Elab

def renderErrorMessage? : Data.ExternalDeclRender → Option String
  | .ok _ => none
  | .error error => some error.message

structure CodeDeclData where
  name : Name
  commandIndex : Nat := 0
  weight : Nat := 1
  provedStatus : Data.ProvedStatus := .proved
deriving Repr, Inhabited, FromJson, ToJson, Quote

def CodeDeclData.ofLiterateDef (d : Data.LiterateDef) : CodeDeclData :=
  {
    name := d.name
    commandIndex := d.commandIndex
    weight := max d.commandLines 1
    provedStatus := d.provedStatus
  }

def CodeDeclData.ofLiterateThm (d : Data.LiterateThm) : CodeDeclData :=
  {
    name := d.name
    commandIndex := d.commandIndex
    weight := max d.commandLines 1
    provedStatus := d.provedStatus
  }

structure InlineCodeData where
  label : Data.Label
  definedDefs : Array CodeDeclData := #[]
  definedTheorems : Array CodeDeclData := #[]
  foldProofs : Bool := true
deriving Repr, Inhabited, FromJson, ToJson, Quote

/--
Resolved block-level code semantics used by informal block rendering.

This unifies directive hints and inline code payloads (`InlineCodeData`)
for the HTML phase:
- `inline` takes precedence whenever code-block data exists,
- otherwise we fall back to optional directive hints (`userOk` / `external`).
-/
inductive BlockCodeData where
  /-- User asserted completion with `(leanok := true)`. -/
  | userOk
  /-- Inline/literate code block associated with this label. -/
  | inline (code : InlineCodeData)
  /-- External Lean declarations associated with this label. -/
  | external (decls : Array Data.ExternalRef)
deriving Repr, Inhabited, FromJson, ToJson, Quote

/-- Projection from environment-level `Data.CodeRef` into JSON-safe block payload hints. -/
def BlockCodeData.ofCodeRefHint (codeRef? : Option Data.CodeRef) : Option BlockCodeData :=
  match codeRef? with
  | some .userOk => some .userOk
  | some (.external decls) => some (.external decls)
  | _ => none

/-- Resolve inline precedence at render time by combining optional hint + inline payload. -/
def BlockCodeData.ofHintAndInline (hint? : Option BlockCodeData) (inline? : Option InlineCodeData)
    : Option BlockCodeData :=
  match inline? with
  | some code => some (.inline code)
  | Option.none => hint?

def BlockCodeData.inlineData? : BlockCodeData → Option InlineCodeData
  | .inline code => some code
  | _ => Option.none

def BlockCodeData.externalDecls : BlockCodeData → Array Data.ExternalRef
  | .external decls => decls
  | _ => #[]

def BlockCodeData.isUserOk : BlockCodeData → Bool
  | .userOk => true
  | _ => false

structure BlockStatusMark where
  status : Data.ProvedStatus := .proved
  title : String
  symbolOverride? : Option String := none
deriving Repr, Inhabited

def BlockStatusMark.text (s : BlockStatusMark) : String :=
  match s.symbolOverride? with
  | some txt => txt
  | none =>
    match s.status with
    | .proved => "✓"
    | .missing => "✗"
    | .axiomLike => "⚠"
    | .containsSorry _ => "✗"

def BlockStatusMark.toHtml (s : BlockStatusMark) : Output.Html :=
  open Verso.Output.Html in
  {{ <span class="bp_status_mark" title={{s.title}}>{{.text true s.text}}</span> }}

structure BlockData where
  kind : Data.NodeKind
  label : Data.Label
  count : Nat
  isProof : Bool := false
  codeData : Option BlockCodeData := none
  texPrelude : String := ""
deriving FromJson, ToJson, Quote

structure CodePanelHeader where
  caption : String
  number? : Option String := none
deriving Repr, Inhabited

def codePanelHeader (data : BlockData) : CodePanelHeader :=
  if data.isProof then
    { caption := "Code for proof" }
  else
    {
      caption := s!"Code for {data.kind}"
      number? := some s!"{data.count}"
    }

def fallbackCodePanelHeader : CodePanelHeader := {
  caption := "Code"
}

register_option verso.blueprint.foldProofs : Bool := {
  defValue := true
  descr := "Enable proof folding in VersoBlueprint Lean code blocks (hide text after `by` behind a toggle)"
}

def provedStatusHasSorry (status : Data.ProvedStatus) : Bool :=
  status.isIncomplete

def provedStatusLocationText (status : Data.ProvedStatus) : String :=
  match status with
  | .missing => "missing declaration"
  | .axiomLike => "axiom-like (no body)"
  | .containsSorry info =>
    let hasType := info.any (·.location == .statement)
    let hasProof := info.any (·.location == .proof)
    if hasType && hasProof then
      "in statement and proof"
    else if hasType then
      "in statement"
    else if hasProof then
      "in proof"
    else
      "location unknown"
  | .proved => "location unknown"

def provedStatusContainsSorry (status : Data.ProvedStatus) : Bool :=
  match status with
  | .containsSorry _ => true
  | _ => false

def mkCodePanel
    (header : CodePanelHeader) (summaryTitle : String)
    (progressBar body : Output.Html)
    (attrs : Array (String × String) := #[]) : Output.Html :=
  open Verso.Output.Html in
  {{
    <div class="bp_wrapper bp_code_panel_wrapper">
      <details class="bp_code_block bp_code_panel" {{attrs}}>
        <summary class="bp_heading lemma_thmheading" title={{summaryTitle}}>
          <span class="bp_caption lemma_thmcaption bp_code_summary_text">{{.text true header.caption}}</span>
          {{if let some number := header.number? then
              {{<span class="bp_label lemma_thmlabel bp_code_summary_label">{{.text true number}}</span>}}
            else
              .empty}}
          {{progressBar}}
          <span class="bp_code_expand_hint"></span>
        </summary>
        {{body}}
      </details>
    </div>
  }}

end Informal
