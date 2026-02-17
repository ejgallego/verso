/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import VersoBlueprint.Environment

namespace Informal.Graph

open Lean
open Informal Data Environment

structure GraphNode (Ref : Type) where
  label : Name
  deps : Array Name
  proofDeps : Array Name := #[]
  fillcolor : String
  ref? : Option Ref := none
deriving Inhabited, Repr, ToJson, FromJson

instance [Quote Ref] : Quote (GraphNode Ref) where
  quote n := Syntax.mkCApp ``GraphNode.mk #[quote n.label, quote n.deps, quote n.proofDeps, quote n.fillcolor, quote n.ref?]

abbrev Graph (Ref : Type) := Array (GraphNode Ref)

def definitionNodeColor : String := "#bfdbfe"
def leanOnlyDefNodeColor : String := "#e9d5ff"
def leanOkNodeColor : String := "#d4f4dd"
def sorryNodeColor : String := "#fff3bf"
def informalNodeColor : String := "#f3f4f6"
def unresolvedDepNodeColor : String := "#fee2e2"

def nodeHasSorries (node : Data.Node) : Bool :=
  match node.code with
  | none => false
  | some code => code.definedDefs.any (·.hasSorry) || code.definedTheorems.any (·.hasSorry)

def nodeColor (node : Data.Node) : String :=
  if node.code.isSome && node.statement.isNone then
    leanOnlyDefNodeColor
  else if node.kind == Data.NodeKind.definition then
    definitionNodeColor
  else if node.code.isSome then
    if nodeHasSorries node then sorryNodeColor
    else if node.proof.isSome then leanOkNodeColor
    else sorryNodeColor
  else
    informalNodeColor

def eraseDups (xs : Array Name) : Array Name :=
  xs.foldl (init := #[]) fun acc x => if acc.contains x then acc else acc.push x

def expandLabels (state : Environment.State) (roots : Array Name) : Array Name :=
  eraseDups <| roots.foldl (init := roots) fun acc label =>
    match state.data.get? label with
    | none => acc
    | some node =>
      let stmtDeps : Array Name := ((node.statement.map (·.deps)).getD #[]).map (fun d => (d : Name))
      let prfDeps : Array Name := ((node.proof.map (·.deps)).getD #[]).map (fun d => (d : Name))
      acc ++ stmtDeps ++ prfDeps

def mkNode (state : Environment.State) (resolveRef? : Name → Option Ref) (label : Name) : GraphNode Ref :=
  match state.data.get? label with
  | some node =>
    {
      label
      deps := ((node.statement.map (·.deps)).getD #[]).map (fun d => (d : Name))
      proofDeps := ((node.proof.map (·.deps)).getD #[]).map (fun d => (d : Name))
      fillcolor := nodeColor node
      ref? := resolveRef? label
    }
  | none =>
    {
      label
      deps := #[]
      proofDeps := #[]
      fillcolor := unresolvedDepNodeColor
      ref? := none
    }

def build (state : Environment.State) (roots : Array Name) (resolveRef? : Name → Option Ref := fun _ => none) :
    Graph Ref :=
  let labels := expandLabels state roots
  labels.map (mkNode state resolveRef?)

def Graph.toDot (g : Graph Ref) (header : String)
    (refAttrs? : Option (Ref → Option String) := none) : String :=
  let known : NameSet := g.foldl (init := {}) fun acc node => acc.insert node.label
  let lines :=
    g.foldl (init := #[header]) fun acc node =>
      let attrs :=
        let base := s!"label=\"{node.label}\", fillcolor=\"{node.fillcolor}\""
        match node.ref?, refAttrs? with
        | some ref, some mkAttrs =>
          match mkAttrs ref with
          | some extra => base ++ ", " ++ extra
          | none => base
        | _, _ => base
      let acc := acc.push s!"  \"{node.label}\" [{attrs}];"
      let acc := node.deps.foldl (init := acc) fun acc dep =>
        if known.contains dep then
          acc.push s!"  \"{node.label}\" -> \"{dep}\";"
        else
          acc
      node.proofDeps.foldl (init := acc) fun acc dep =>
        if known.contains dep then
          acc.push s!"  \"{node.label}\" -> \"{dep}\" [style=dashed, penwidth=1.2];"
        else
          acc
  let lines := lines.push "}"
  lines.foldl (init := "") fun acc line =>
    if acc.isEmpty then line else acc ++ "\n" ++ line

end Informal.Graph
