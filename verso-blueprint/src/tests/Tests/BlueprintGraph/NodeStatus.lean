/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintGraph.Shared

namespace Verso.Tests.BlueprintGraph.NodeStatus

open Lean
open Informal
open Informal.Data
open Informal.Environment
open Informal.Graph
open Verso.Tests.BlueprintGraph.Shared

def stateStatus : Environment.State := mkState [
  (`def_formal,
    {
      kind := .definition
      statement := some (mkInformal #[])
      code := some (mkDefCode `def_formal_decl)
    }),
  (`def_ready,
    {
      kind := .definition
      statement := some (mkInformal #[`def_formal])
    }),
  (`def_blocked,
    {
      kind := .definition
      statement := some (mkInformal #[`missing_dep])
    }),
  (`thm_ready,
    {
      kind := .theorem
      statement := some (mkInformal #[`def_formal])
    }),
  (`lean_only,
    {
      kind := .definition
      code := some (mkDefCode `lean_only_decl)
    }),
  (`local_sorry,
    {
      kind := .theorem
      statement := some (mkInformal #[])
      code := some (mkTheoremCode `local_sorry_decl false true)
    }),
  (`thm_type_sorry,
    {
      kind := .theorem
      statement := some (mkInformal #[])
      code := some (mkTheoremCode `thm_type_sorry_decl true false)
    })
]

def graphStatus : Graph Unit :=
  build stateStatus #[`def_formal, `def_ready, `def_blocked, `thm_ready, `lean_only, `local_sorry, `thm_type_sorry]

/-- info: true -/
#guard_msgs in
#eval
  hasNodeWith graphStatus `def_formal (fun n =>
    n.shape == "box" &&
    n.color == statementBorderFormalizedColor &&
    n.fillcolor == proofBackgroundFormalizedAncColor) &&
  hasNodeWith graphStatus `def_ready (fun n =>
    n.shape == "box" &&
    n.color == statementBorderReadyColor) &&
  hasNodeWith graphStatus `def_blocked (fun n =>
    n.color == statementBorderBlockedColor) &&
  hasNodeWith graphStatus `thm_ready (fun n =>
    n.shape == "ellipse" &&
    n.color == statementBorderReadyColor &&
    n.fillcolor == proofBackgroundReadyColor)

/-- info: true -/
#guard_msgs in
#eval
  hasNodeWith graphStatus `lean_only (fun n =>
    n.color == statementBorderFormalizedColor &&
    n.fillcolor == proofBackgroundFormalizedAncColor &&
    styleHasToken n.style "dashed" &&
    n.gradientangle?.isNone) &&
  hasNodeWith graphStatus `local_sorry (fun n =>
    n.color == statementBorderFormalizedColor &&
    n.fillcolor == proofBackgroundReadyColor &&
    styleHasToken n.style "bold" &&
    n.gradientangle?.isNone) &&
  hasNodeWith graphStatus `thm_type_sorry (fun n =>
    n.color == statementBorderReadyColor &&
    n.fillcolor == proofBackgroundReadyColor &&
    styleHasToken n.style "bold" &&
    n.gradientangle?.isNone)

/-- info: true -/
#guard_msgs in
#eval
  hasNodeWith graphStatus `missing_dep (fun n =>
    n.shape == "box" &&
    n.color == unresolvedBorderColor &&
    n.fillcolor == unresolvedFillColor &&
    n.fontcolor == unresolvedFontColor)

def stateAncestorsOk : Environment.State := mkState [
  (`def_ok,
    {
      kind := .definition
      statement := some (mkInformal #[])
      code := some (mkDefCode `def_ok_decl)
    }),
  (`thm_dep_ok,
    {
      kind := .theorem
      statement := some (mkInformal #[`def_ok])
      code := some (mkTheoremCode `thm_dep_ok_decl)
    }),
  (`thm_top_ok,
    {
      kind := .theorem
      statement := some (mkInformal #[`thm_dep_ok])
      code := some (mkTheoremCode `thm_top_ok_decl)
    })
]

def graphAncestorsOk : Graph Unit := build stateAncestorsOk #[`thm_top_ok]

/-- info: true -/
#guard_msgs in
#eval
  hasNodeWith graphAncestorsOk `thm_top_ok (fun n =>
    n.fillcolor == proofBackgroundFormalizedAncColor &&
    n.peripheries == 1)

def stateAncestorsBad : Environment.State := mkState [
  (`def_unfinished,
    {
      kind := .definition
      statement := some (mkInformal #[])
    }),
  (`thm_dep_bad,
    {
      kind := .theorem
      statement := some (mkInformal #[`def_unfinished])
      code := some (mkTheoremCode `thm_dep_bad_decl)
    }),
  (`thm_top_bad,
    {
      kind := .theorem
      statement := some (mkInformal #[`thm_dep_bad])
      code := some (mkTheoremCode `thm_top_bad_decl)
    })
]

def graphAncestorsBad : Graph Unit := build stateAncestorsBad #[`thm_top_bad]

/-- info: true -/
#guard_msgs in
#eval
  hasNodeWith graphAncestorsBad `thm_dep_bad (fun n =>
    n.fillcolor == proofBackgroundFormalizedColor &&
    n.peripheries == 2) &&
  hasNodeWith graphAncestorsBad `thm_top_bad (fun n =>
    n.fillcolor == proofBackgroundFormalizedColor &&
    n.peripheries == 2)

def stateExternalCode : Environment.State := mkState [
  (`def_ext_ok,
    {
      kind := .definition
      statement := some (mkInformal #[])
      code := some (.external #[
        { (Data.ExternalRef.ofName `Ext.good) with
          present := true
          provedStatus := .proved
        }
      ])
    }),
  (`def_ext_bad,
    {
      kind := .definition
      statement := some (mkInformal #[])
      code := some (.external #[
        { (Data.ExternalRef.ofName `Ext.bad) with
          present := true
          provedStatus := .containsSorry #[{ location := .statement }, { location := .proof }]
        }
      ])
    }),
  (`def_ext_missing,
    {
      kind := .definition
      statement := some (mkInformal #[])
      code := some (.external #[
        { (Data.ExternalRef.ofName `Ext.missing) with
          present := false
          provedStatus := .proved
        }
      ])
    })
]

def externalStatus : ExternalCodeStatus := {
  isMissing := fun n => n == `Ext.missing
  provedStatus := fun n =>
    if n == `Ext.bad then
      .containsSorry #[{ location := .statement }, { location := .proof }]
    else
      .proved
}

def externalStatusOverride : ExternalCodeStatus := {
  isMissing := fun n => n == `Ext.missing || n == `Ext.override_missing
  provedStatus := fun n =>
    if n == `Ext.bad || n == `Ext.override_bad then
      .containsSorry #[{ location := .statement }, { location := .proof }]
    else
      .proved
}

def graphExternalCode : Graph Unit :=
  buildWithExternal stateExternalCode #[`def_ext_ok, `def_ext_bad, `def_ext_missing] externalStatus

/-- info: true -/
#guard_msgs in
#eval
  hasNodeWith graphExternalCode `def_ext_ok (fun n =>
    n.color == statementBorderFormalizedColor) &&
  hasNodeWith graphExternalCode `def_ext_bad (fun n =>
    n.color == statementBorderReadyColor &&
    n.fillcolor == proofBackgroundReadyColor &&
    styleHasToken n.style "bold" &&
    n.gradientangle?.isNone) &&
  hasNodeWith graphExternalCode `def_ext_missing (fun n =>
    n.color == statementBorderReadyColor &&
    n.fillcolor == proofBackgroundReadyColor &&
    styleHasToken n.style "dotted" &&
    n.gradientangle?.isNone)

def stateExternalOverride : Environment.State := mkState [
  (`def_ext_override_bad,
    {
      kind := .definition
      statement := some (mkInformal #[])
      code := some (.external #[
        { (Data.ExternalRef.ofName `Ext.override_bad) with
          present := true
          provedStatus := .proved
        }
      ])
    }),
  (`def_ext_override_missing,
    {
      kind := .definition
      statement := some (mkInformal #[])
      code := some (.external #[
        { (Data.ExternalRef.ofName `Ext.override_missing) with
          present := true
          provedStatus := .proved
        }
      ])
    })
]

def graphExternalOverride : Graph Unit :=
  buildWithExternal stateExternalOverride #[`def_ext_override_bad, `def_ext_override_missing] externalStatusOverride

/-- info: true -/
#guard_msgs in
#eval
  hasNodeWith graphExternalOverride `def_ext_override_bad (fun n =>
    n.color == statementBorderReadyColor &&
    n.fillcolor == proofBackgroundReadyColor &&
    styleHasToken n.style "bold" &&
    n.gradientangle?.isNone) &&
  hasNodeWith graphExternalOverride `def_ext_override_missing (fun n =>
    n.color == statementBorderReadyColor &&
    n.fillcolor == proofBackgroundReadyColor &&
    styleHasToken n.style "dotted" &&
    n.gradientangle?.isNone)

def stateLeanOnlyExternalMissing : Environment.State := mkState [
  (`lean_only_ext_missing,
    {
      kind := .definition
      code := some (.external #[
        { (Data.ExternalRef.ofName `Ext.missing) with
          present := false
          provedStatus := .proved
        }
      ])
    })
]

def warningLeanOnlyExternalMissing : WarningFlags :=
  match stateLeanOnlyExternalMissing.data.get? `lean_only_ext_missing with
  | some node => nodeWarnings externalStatus stateLeanOnlyExternalMissing `lean_only_ext_missing node
  | none => {}

/-- info: true -/
#guard_msgs in
#eval
  warningLeanOnlyExternalMissing.leanOnlyNoStatement &&
  warningLeanOnlyExternalMissing.missingExternalDecl

end Verso.Tests.BlueprintGraph.NodeStatus
