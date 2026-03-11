/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintGraph.Shared

namespace Verso.Tests.BlueprintGraph.Legend

open Informal.Graph

def legendGroupByKey (groups : Array LegendGroup) (key : String) : Option LegendGroup :=
  groups.find? (·.key == key)

def legendItemByLabel (group : LegendGroup) (label : String) : Option LegendItem :=
  group.items.find? (·.label == label)

def defaultLegend : Array LegendGroup := graphLegendGroups false
def legendWithMathlib : Array LegendGroup := graphLegendGroups true
def groupLegend : Array LegendGroup := groupGraphLegendGroups

/-- info: true -/
#guard_msgs in
#eval
  let hasMathlibLabel : Bool :=
    defaultLegend.any fun group => (group.items.any (·.label == "In Mathlib"))
  let hasUpdatedWarning : Bool :=
    defaultLegend.any fun group => (group.items.any (·.label == "Associated Lean code incomplete"))
  let hasWarningMarkerTitle : Bool :=
    defaultLegend.any (·.title == "Warning Markers")
  let hasUpdatedDashedText : Bool :=
    defaultLegend.any fun group => (group.items.any (·.label == "Dashed: statement deps from box-shaped sources"))
  !hasMathlibLabel && hasUpdatedWarning && hasWarningMarkerTitle && hasUpdatedDashedText

/-- info: true -/
#guard_msgs in
#eval
  legendWithMathlib.any fun group => (group.items.any (·.label == "In Mathlib"))

/-- info: true -/
#guard_msgs in
#eval
  match legendGroupByKey defaultLegend "warning" with
  | none => false
  | some warningGroup =>
    match legendItemByLabel warningGroup "Associated Lean code incomplete" with
    | none => false
    | some item =>
      match item.swatch? with
      | none => false
      | some swatch =>
        swatch.background == definitionBackgroundColor &&
        swatch.borderWidth == 2 &&
        warningCodeIncompleteText == "Associated Lean code is incomplete" &&
        graphLegendGroupViewNote.length > 0

/-- info: true -/
#guard_msgs in
#eval
  match legendGroupByKey groupLegend "group-edge" with
  | none => false
  | some edgeGroup =>
    edgeGroup.items.any (·.label == groupEdgeMixedText) &&
    graphLegendGroupViewNote.contains "tab-shaped"

end Verso.Tests.BlueprintGraph.Legend
