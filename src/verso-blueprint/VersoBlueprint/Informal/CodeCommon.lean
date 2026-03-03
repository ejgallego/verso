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

structure CodeHoverDecl where
  text : String
  href : Option String := none

structure CodeHoverData where
  label : Data.Label
  definedDefs : Array CodeHoverDecl := #[]
  definedTheorems : Array CodeHoverDecl := #[]
  sorries : Array CodeHoverDecl := #[]

/--
View model used by informal block rendering for one external Lean declaration.
This extends resolved declaration metadata with optional in-site links.
-/
structure ExternalHoverDecl where
  decl : Data.ExternalRef
  /-- Optional link to local docs/example declaration pages. -/
  href : Option String := none

structure ComputedData where
  codeHref : Option String := none
  codeHover : Option CodeHoverData := none
  manualStatus : Bool := false
  externalDecls : Array ExternalHoverDecl := #[]
  hasStatementSorries : Bool := false
  hasProofSorries : Bool := false

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

private def sorryStatusText (status : Data.ProvedStatus) : String :=
  match status with
  | .axiomLike => "axiom-like (no body)"
  | .containsSorry _ => provedStatusLocationText status
  | .proved => "unknown"

def mkCodeHoverData
    (label : Data.Label)
    (definedDefs definedTheorems : Array CodeDeclData)
    (hrefOf : Name → Option String) : CodeHoverData :=
  let toDecl (d : CodeDeclData) : CodeHoverDecl :=
    { text := toString d.name, href := hrefOf d.name }
  let toSorry (d : CodeDeclData) : CodeHoverDecl :=
    let kind := sorryStatusText d.provedStatus
    { text := s!"{d.name} [{kind}]", href := hrefOf d.name }
  {
    label
    definedDefs := definedDefs.map toDecl
    definedTheorems := definedTheorems.map toDecl
    sorries := (definedDefs ++ definedTheorems).filter (provedStatusHasSorry ∘ (·.provedStatus)) |>.map toSorry
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
    let sorryDecls := (definedDefs ++ definedTheorems).filter (provedStatusHasSorry ∘ (·.provedStatus))
    let sorries :=
      if sorryDecls.isEmpty then
        "none"
      else
        String.intercalate ", " <| sorryDecls.toList.map fun d =>
          let kind := sorryStatusText d.provedStatus
          s!"{d.name} [{kind}]"
    s!"{label}\nLean definitions: {defs}\nLean theorems/lemmas: {thms}\nSorries: {sorries}"

def sortDeclsByCommand (decls : Array CodeDeclData) : Array CodeDeclData :=
  decls.qsort (fun a b =>
    a.commandIndex < b.commandIndex ||
    (a.commandIndex == b.commandIndex && a.name.toString < b.name.toString))

def progressSegmentClass (missing hasSorry : Bool) : String :=
  if missing then
    "bp_code_progress_segment bp_code_progress_segment_missing"
  else if hasSorry then
    "bp_code_progress_segment bp_code_progress_segment_sorry"
  else
    "bp_code_progress_segment bp_code_progress_segment_ok"

def codePanelSummary (data : BlockData) : String :=
  if data.isProof then
    "Code for proof"
  else
    s!"Code for {data.kind} {data.count}"

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

def codeHoverDeclItems (items : Array CodeHoverDecl) : Output.Html :=
  open Verso.Output.Html in
  if items.isEmpty then
    {{<li class="bp_code_hover_none">"none"</li>}}
  else
    .seq <| items.map fun item =>
      let txt := {{<code>{{.text true item.text}}</code>}}
      {{<li>{{if let some href := item.href then {{<a href={{href}}>{{txt}}</a>}} else txt}}</li>}}

end Informal
