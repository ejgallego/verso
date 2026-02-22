/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import VersoBlueprint.Environment

namespace Informal.Graph

open Lean
open Informal Data Environment

/-- Upstream-compatible statement-track status (node border). -/
inductive StatementStatus where
  | blocked
  | ready
  | formalized
  | mathlib
deriving Inhabited, Repr, DecidableEq, ToJson, FromJson

/-- Upstream-compatible background status (proof-track for theorem-like nodes). -/
inductive ProofStatus where
  | none
  | ready
  | formalized
  | formalizedWithAncestors
deriving Inhabited, Repr, DecidableEq, ToJson, FromJson

structure WarningFlags where
  unknownRef : Bool := false
  leanOnlyNoStatement : Bool := false
  localSorries : Bool := false
  depsWithSorries : Bool := false
deriving Inhabited, Repr, ToJson, FromJson

structure GraphNode (Ref : Type) where
  label : Name
  deps : Array Name
  proofDeps : Array Name := #[]
  shape : String := "box"
  style : String := "filled"
  fillcolor : String
  color : String := "#6b7280"
  penwidth : String := "1.8"
  fontcolor : String := "#111827"
  peripheries : Nat := 1
  gradientangle? : Option String := none
  tooltip? : Option String := none
  ref? : Option Ref := none
deriving Inhabited, Repr, ToJson, FromJson

instance [Quote Ref] : Quote (GraphNode Ref) where
  quote n := Syntax.mkCApp ``GraphNode.mk
    #[
      quote n.label, quote n.deps, quote n.proofDeps, quote n.shape, quote n.style, quote n.fillcolor,
      quote n.color, quote n.penwidth, quote n.fontcolor, quote n.peripheries, quote n.gradientangle?,
      quote n.tooltip?, quote n.ref?
    ]

abbrev Graph (Ref : Type) := Array (GraphNode Ref)

def statementBorderBlockedColor : String := "#f59e0b"
def statementBorderReadyColor : String := "#2563eb"
def statementBorderFormalizedColor : String := "#16a34a"
def statementBorderMathlibColor : String := "#14532d"

def proofBackgroundNeutralColor : String := "#f8fafc"
def proofBackgroundReadyColor : String := "#dbeafe"
def proofBackgroundFormalizedColor : String := "#dcfce7"
def proofBackgroundFormalizedAncColor : String := "#166534"

def definitionBackgroundColor : String := "#ffffff"

def leanOnlyOverlayColor : String := "#ede9fe"
def localSorriesOverlayColor : String := "#fef3c7"

def unresolvedFillColor : String := "#fee2e2"
def unresolvedBorderColor : String := "#b91c1c"
def unresolvedFontColor : String := "#7f1d1d"

def warningDepsText : String := "Dependencies are not fully formalized"

def statementDeps (node : Data.Node) : Array Name :=
  ((node.statement.map (·.deps)).getD #[]).map (fun d => (d : Name))

def proofDeps (node : Data.Node) : Array Name :=
  ((node.proof.map (·.deps)).getD #[]).map (fun d => (d : Name))

def allDeps (node : Data.Node) : Array Name :=
  statementDeps node ++ proofDeps node

def isTheoremLikeKind (kind : Data.NodeKind) : Bool :=
  kind == Data.NodeKind.lemma || kind == Data.NodeKind.theorem || kind == Data.NodeKind.corollary

structure ExternalCodeStatus where
  hasTypeSorry : Name → Bool := fun _ => false
  hasProofSorry : Name → Bool := fun _ => false

def nodeExternalDecls (node : Data.Node) : Array Name :=
  match node.code with
  | some (.external decls) => decls.map (·.canonical)
  | _ => #[]

def nodeHasAssociatedCode (node : Data.Node) : Bool :=
  node.code.isSome

def nodeHasTypeSorries (external : ExternalCodeStatus) (node : Data.Node) : Bool :=
  let localHas :=
    match node.code with
    | some (.literate code) =>
      code.definedDefs.any (·.hasTypeSorry) || code.definedTheorems.any (·.hasTypeSorry)
    | _ => false
  localHas || (nodeExternalDecls node).any external.hasTypeSorry

def nodeHasProofSorries (external : ExternalCodeStatus) (node : Data.Node) : Bool :=
  let localHas :=
    match node.code with
    | some (.literate code) =>
      code.definedTheorems.any (·.hasProofSorry)
    | _ => false
  localHas || (nodeExternalDecls node).any external.hasProofSorry

def nodeHasSorries (external : ExternalCodeStatus) (node : Data.Node) : Bool :=
  nodeHasTypeSorries external node || nodeHasProofSorries external node

def nodeLocalStatementFormalized (external : ExternalCodeStatus) (node : Data.Node) : Bool :=
  nodeHasAssociatedCode node && !nodeHasTypeSorries external node

def nodeLocalProofFormalized (external : ExternalCodeStatus) (node : Data.Node) : Bool :=
  nodeHasAssociatedCode node && !nodeHasProofSorries external node

def nodeLocalFormalized (external : ExternalCodeStatus) (node : Data.Node) : Bool :=
  if isTheoremLikeKind node.kind then
    nodeLocalProofFormalized external node
  else if node.kind == Data.NodeKind.definition then
    nodeLocalStatementFormalized external node
  else
    false

def eraseDups (xs : Array Name) : Array Name :=
  xs.foldl (init := #[]) fun acc x => if acc.contains x then acc else acc.push x

/-- Placeholder branch for future `(lean := "...")` Mathlib integration. -/
def nodeInMathlib (_state : Environment.State) (_label : Name) (_node : Data.Node) : Bool :=
  false

inductive DepTraversal where
  | statement
  | proof
  | both
deriving Inhabited, Repr

def depsForTraversal (mode : DepTraversal) (node : Data.Node) : Array Name :=
  match mode with
  | .statement => statementDeps node
  | .proof => proofDeps node
  | .both => allDeps node

partial def depsClosureComplete (external : ExternalCodeStatus) (state : Environment.State) (mode : DepTraversal)
    (roots : Array Name) (visited : NameSet := {}) : Bool :=
  roots.all fun dep =>
    if visited.contains dep then
      true
    else
      match state.data.get? dep with
      | none => false
      | some node =>
        if !nodeLocalFormalized external node then
          false
        else
          let visited := visited.insert dep
          depsClosureComplete external state mode (depsForTraversal mode node) visited

def nodeAncestorsFormalized (external : ExternalCodeStatus) (state : Environment.State) (node : Data.Node) : Bool :=
  depsClosureComplete external state .both (allDeps node)

def statementStatus (external : ExternalCodeStatus) (state : Environment.State) (label : Name)
    (node : Data.Node) : StatementStatus :=
  if nodeInMathlib state label node then
    .mathlib
  else if nodeLocalStatementFormalized external node then
    .formalized
  else if depsClosureComplete external state .statement (statementDeps node) then
    .ready
  else
    .blocked

def proofStatus (external : ExternalCodeStatus) (state : Environment.State) (_label : Name)
    (node : Data.Node) : ProofStatus :=
  if !isTheoremLikeKind node.kind then
    if nodeLocalStatementFormalized external node then
      if nodeAncestorsFormalized external state node then .formalizedWithAncestors else .formalized
    else if depsClosureComplete external state .statement (statementDeps node) then
      .ready
    else
      .none
  else if nodeLocalProofFormalized external node then
    if nodeAncestorsFormalized external state node then .formalizedWithAncestors else .formalized
  else
    let stmtDepsDone := depsClosureComplete external state .statement (statementDeps node)
    let proofDepsDone := depsClosureComplete external state .proof (proofDeps node)
    if stmtDepsDone && proofDepsDone then .ready else .none

def nodeWarnings (external : ExternalCodeStatus) (state : Environment.State) (_label : Name)
    (node : Data.Node) : WarningFlags :=
  let localProofDone := nodeLocalProofFormalized external node
  let ancestorDepsDone := nodeAncestorsFormalized external state node
  {
    unknownRef := false
    leanOnlyNoStatement := nodeHasAssociatedCode node && node.statement.isNone
    localSorries := nodeHasAssociatedCode node && node.statement.isSome && nodeHasSorries external node
    depsWithSorries := isTheoremLikeKind node.kind && localProofDone && !ancestorDepsDone
  }

def statementStatusBorderColor : StatementStatus → String
  | .blocked => statementBorderBlockedColor
  | .ready => statementBorderReadyColor
  | .formalized => statementBorderFormalizedColor
  | .mathlib => statementBorderMathlibColor

def proofStatusFillColor (kind : Data.NodeKind) : ProofStatus → String
  | .none =>
    if isTheoremLikeKind kind then proofBackgroundNeutralColor else definitionBackgroundColor
  | .ready => proofBackgroundReadyColor
  | .formalized => proofBackgroundFormalizedColor
  | .formalizedWithAncestors => proofBackgroundFormalizedAncColor

def proofStatusFontColor : ProofStatus → String
  | .formalizedWithAncestors => "#ffffff"
  | _ => "#111827"

def kindShape (kind : Data.NodeKind) : String :=
  if isTheoremLikeKind kind then "ellipse" else "box"

def StatementStatus.toText : StatementStatus → String
  | .blocked => "blocked"
  | .ready => "ready"
  | .formalized => "formalized"
  | .mathlib => "mathlib"

def ProofStatus.toText : ProofStatus → String
  | .none => "none"
  | .ready => "ready"
  | .formalized => "formalized"
  | .formalizedWithAncestors => "formalized + ancestors"

def warningTooltipParts (warnings : WarningFlags) : List String :=
  (if warnings.leanOnlyNoStatement then ["Lean code present but informal statement is missing"] else []) ++
  (if warnings.localSorries then ["Associated Lean code still contains sorries"] else []) ++
  (if warnings.depsWithSorries then [warningDepsText] else [])

def mkStyledNode (kind : Data.NodeKind) (label : Name) (deps proofDeps : Array Name)
    (statement : StatementStatus) (proof : ProofStatus) (warnings : WarningFlags)
    (ref? : Option Ref) : GraphNode Ref :=
  if warnings.unknownRef then
    {
      label
      deps
      proofDeps
      shape := "box"
      style := "filled"
      fillcolor := unresolvedFillColor
      color := unresolvedBorderColor
      penwidth := "2.2"
      fontcolor := unresolvedFontColor
      peripheries := 1
      gradientangle? := none
      tooltip? := some s!"Unknown reference: {label}"
      ref?
    }
  else
    let shape := kindShape kind
    let baseFill := proofStatusFillColor kind proof
    let overlayColor? :=
      if warnings.leanOnlyNoStatement then some leanOnlyOverlayColor
      else if warnings.localSorries then some localSorriesOverlayColor
      else none
    let fillcolor :=
      match overlayColor? with
      | some overlay => s!"{baseFill}:{overlay}"
      | none => baseFill
    let gradientangle? := overlayColor?.map (fun _ => "90")
    let peripheries := if warnings.depsWithSorries then 2 else 1
    let tooltipParts :=
      [s!"Statement: {statement.toText}", s!"Proof: {proof.toText}"] ++ warningTooltipParts warnings
    let tooltip? :=
      if tooltipParts.isEmpty then none else some (String.intercalate " | " tooltipParts)
    {
      label
      deps
      proofDeps
      shape
      style := "filled"
      fillcolor
      color := statementStatusBorderColor statement
      penwidth := "2.2"
      fontcolor := proofStatusFontColor proof
      peripheries
      gradientangle?
      tooltip?
      ref?
    }

def expandLabels (state : Environment.State) (roots : Array Name) : Array Name :=
  Id.run <| do
    let mut queue : Array Name := eraseDups roots
    let mut enqueued : NameSet := queue.foldl (init := {}) fun acc label => acc.insert label
    let mut seen : NameSet := {}
    let mut idx : Nat := 0
    while idx < queue.size do
      let label := queue[idx]!
      idx := idx + 1
      if seen.contains label then
        continue
      seen := seen.insert label
      match state.data.get? label with
      | none => pure ()
      | some node =>
        for dep in allDeps node do
          if !enqueued.contains dep then
            queue := queue.push dep
            enqueued := enqueued.insert dep
    return queue

def mkNode (external : ExternalCodeStatus) (state : Environment.State)
    (resolveRef? : Name → Option Ref) (label : Name) : GraphNode Ref :=
  match state.data.get? label with
  | some node =>
    let deps := statementDeps node
    let nodeProofDeps := proofDeps node
    let statement := statementStatus external state label node
    let proof := proofStatus external state label node
    let warnings := nodeWarnings external state label node
    let ref? := resolveRef? label
    mkStyledNode node.kind label deps nodeProofDeps statement proof warnings ref?
  | none =>
    let unresolvedWarnings : WarningFlags := { unknownRef := true }
    mkStyledNode Data.NodeKind.definition label #[] #[] .blocked .none unresolvedWarnings none

def build (state : Environment.State) (roots : Array Name) (resolveRef? : Name → Option Ref := fun _ => none) :
    Graph Ref :=
  let labels := expandLabels state roots
  let external : ExternalCodeStatus := {}
  labels.map (mkNode external state resolveRef?)

def buildWithExternal (state : Environment.State) (roots : Array Name)
    (external : ExternalCodeStatus) (resolveRef? : Name → Option Ref := fun _ => none) : Graph Ref :=
  let labels := expandLabels state roots
  labels.map (mkNode external state resolveRef?)

def escapeDotString (s : String) : String :=
  let s := s.replace "\\" "\\\\"
  s.replace "\"" "\\\""

def Graph.toDot (g : Graph Ref) (header : String)
    (refAttrs? : Option (Ref → Option String) := none) : String :=
  let known : NameSet := g.foldl (init := {}) fun acc node => acc.insert node.label
  let defLike : NameSet := g.foldl (init := {}) fun acc node =>
    if node.shape == "box" then acc.insert node.label else acc
  let lines :=
    g.foldl (init := #[header]) fun acc node =>
      let attrs :=
        let base : Array String := #[
          s!"label=\"{escapeDotString (toString node.label)}\"",
          s!"shape=\"{escapeDotString node.shape}\"",
          s!"style=\"{escapeDotString node.style}\"",
          s!"fillcolor=\"{escapeDotString node.fillcolor}\"",
          s!"color=\"{escapeDotString node.color}\"",
          s!"penwidth=\"{escapeDotString node.penwidth}\"",
          s!"fontcolor=\"{escapeDotString node.fontcolor}\"",
          s!"peripheries={node.peripheries}"
        ]
        let base :=
          match node.gradientangle? with
          | some gradientangle => base.push s!"gradientangle={gradientangle}"
          | none => base
        let base :=
          match node.tooltip? with
          | some tooltip => base.push s!"tooltip=\"{escapeDotString tooltip}\""
          | none => base
        match node.ref?, refAttrs? with
        | some ref, some mkAttrs =>
          match mkAttrs ref with
          | some extra => (String.intercalate ", " base.toList) ++ ", " ++ extra
          | none => String.intercalate ", " base.toList
        | _, _ => String.intercalate ", " base.toList
      let (stmtDeps, seenDeps) :=
        node.deps.foldl (init := ((#[] : Array Name), ({} : NameSet))) fun (deps, seen) dep =>
          if seen.contains dep then
            (deps, seen)
          else
            (deps.push dep, seen.insert dep)
      let (proofDeps, _seenAllDeps) :=
        node.proofDeps.foldl (init := ((#[] : Array Name), seenDeps)) fun (deps, seen) dep =>
          if seen.contains dep then
            (deps, seen)
          else
            (deps.push dep, seen.insert dep)
      let acc := acc.push s!"  \"{node.label}\" [{attrs}];"
      let acc := stmtDeps.foldl (init := acc) fun acc dep =>
        if known.contains dep then
          if defLike.contains dep then
            acc.push s!"  \"{dep}\" -> \"{node.label}\" [style=dashed, penwidth=1.2];"
          else
            acc.push s!"  \"{dep}\" -> \"{node.label}\";"
        else
          acc
      proofDeps.foldl (init := acc) fun acc dep =>
        if known.contains dep then
          acc.push s!"  \"{dep}\" -> \"{node.label}\" [style=dotted, penwidth=1.2];"
        else
          acc
  let lines := lines.push "}"
  lines.foldl (init := "") fun acc line =>
    if acc.isEmpty then line else acc ++ "\n" ++ line

end Informal.Graph
