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

inductive BlockCodeStatus where
  | none
  | userOk
  | external (decls : Array Data.ExternalRef)
deriving Repr, Inhabited, FromJson, ToJson, Quote

def BlockCodeStatus.ofCodeRef (codeRef? : Option Data.CodeRef) : BlockCodeStatus :=
  match codeRef? with
  | some .userOk => .userOk
  | some (.external decls) => .external decls
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
  provedStatus : Data.ProvedStatus := .proved
deriving FromJson, ToJson, Quote

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

def provedStatusHasSorry (status : Data.ProvedStatus) : Bool :=
  status.isIncomplete

def provedStatusLocationText (status : Data.ProvedStatus) : String :=
  match status with
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
    (summaryText summaryTitle : String)
    (progressBar body : Output.Html)
    (attrs : Array (String × String) := #[]) : Output.Html :=
  open Verso.Output.Html in
  {{
    <div class="bp_wrapper bp_code_panel_wrapper">
      <details class="bp_code_block bp_code_panel" {{attrs}}>
        <summary title={{summaryTitle}}>
          <span class="bp_code_summary_text">{{.text true summaryText}}</span>
          {{progressBar}}
          <span class="bp_code_expand_hint"></span>
        </summary>
        {{body}}
      </details>
    </div>
  }}

end Informal
