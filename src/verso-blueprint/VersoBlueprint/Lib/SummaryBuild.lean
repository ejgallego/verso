/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Lean.Elab.Command
import VersoBlueprint.Data
import VersoBlueprint.Environment
import VersoBlueprint.Lib.NodeFacts

namespace Informal.Commands

open Lean
open Informal Data Environment

structure PendingProofItem where
  label : Name
  kind : String
  leanObjects : List Name := []
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote PendingProofItem where
  quote s := mkCApp ``PendingProofItem.mk #[quote s.label, quote s.kind, quote s.leanObjects]

structure SorryItem where
  label : Name
  kind : String
  decl : Name
  isTheorem : Bool := false
  status : Data.ProvedStatus := .proved
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote SorryItem where
  quote s := mkCApp ``SorryItem.mk #[quote s.label, quote s.kind, quote s.decl, quote s.isTheorem, quote s.status]

structure MissingLeanDeclItem where
  label : Name
  kind : String
  written : Name
  canonical : Name
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote MissingLeanDeclItem where
  quote s := mkCApp ``MissingLeanDeclItem.mk #[quote s.label, quote s.kind, quote s.written, quote s.canonical]

structure IndexItem where
  label : Name
  kind : String
  leanObjects : List Name := []
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote IndexItem where
  quote s := mkCApp ``IndexItem.mk #[quote s.label, quote s.kind, quote s.leanObjects]

structure ParentTheoremGroup where
  parent : Name
  header : String := ""
  entries : List IndexItem := []
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote ParentTheoremGroup where
  quote s := mkCApp ``ParentTheoremGroup.mk #[quote s.parent, quote s.header, quote s.entries]

structure Summary where
  totalEntries : Nat := 0
  definitions : Nat := 0
  lemmas : Nat := 0
  theorems : Nat := 0
  corollaries : Nat := 0
  leanOnlyEntries : Nat := 0
  informalOnlyEntries : Nat := 0
  pendingInformalProofEntries : List PendingProofItem := []
  leanDecls : Nat := 0
  sorries : Nat := 0
  sorryDetails : List SorryItem := []
  missingLeanDecls : List MissingLeanDeclItem := []
  definitionIndex : List IndexItem := []
  theoremLikeIndex : List IndexItem := []
  theoremLikeByParent : List ParentTheoremGroup := []
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote Summary where
  quote s := mkCApp ``Summary.mk
    #[
      quote s.totalEntries,
      quote s.definitions,
      quote s.lemmas,
      quote s.theorems,
      quote s.corollaries,
      quote s.leanOnlyEntries,
      quote s.informalOnlyEntries,
      quote s.pendingInformalProofEntries,
      quote s.leanDecls,
      quote s.sorries,
      quote s.sorryDetails,
      quote s.missingLeanDecls,
      quote s.definitionIndex,
      quote s.theoremLikeIndex,
      quote s.theoremLikeByParent
    ]

def countDefSorries (decls : Array Data.LiterateDef) : Nat :=
  decls.foldl (init := 0) fun acc decl => acc + (if decl.provedStatus.isIncomplete then 1 else 0)

def countThmSorries (decls : Array Data.LiterateThm) : Nat :=
  decls.foldl (init := 0) fun acc decl => acc + (if decl.provedStatus.isIncomplete then 1 else 0)

def collectDefSorries (label : Name) (kind : String) (decls : Array Data.LiterateDef) (theoremNames : NameSet) :
    List SorryItem :=
  decls.foldl (init := []) fun acc decl =>
    if decl.provedStatus.isIncomplete then
      {
        label
        kind
        decl := decl.name
        isTheorem := theoremNames.contains decl.name
        status := decl.provedStatus
      } :: acc
    else
      acc

def collectThmSorries (label : Name) (kind : String) (decls : Array Data.LiterateThm) (theoremNames : NameSet) :
    List SorryItem :=
  decls.foldl (init := []) fun acc decl =>
    if decl.provedStatus.isIncomplete then
      {
        label
        kind
        decl := decl.name
        isTheorem := theoremNames.contains decl.name
        status := decl.provedStatus
      } :: acc
    else
      acc

def kindNeedsInformalProof (kind : Data.NodeKind) : Bool :=
  kind == Data.NodeKind.lemma || kind == Data.NodeKind.theorem || kind == Data.NodeKind.corollary

def addParentTheoremLikeItem (groups : NameMap (List IndexItem)) (parent : Name) (item : IndexItem) :
    NameMap (List IndexItem) :=
  groups.insert parent (item :: groups.getD parent [])

def buildSummary : CoreM Summary := do
  let env ← getEnv
  let externalAdapter := Informal.NodeFacts.ExternalDeclAdapter.ofEnv env
  let state := informalExt.getState env
  let entries := state.data.toArray
  let parentChildren := state.data.parentChildren
  let groupHeaders := state.groups
  let summary := entries.foldl (init := ({} : Summary)) fun acc (label, node) =>
      let hasStatement := node.statement.isSome
      let hasProof := node.proof.isSome
      let hasCode := node.code.isSome
      let (leanDecls, sorries, leanObjects, sorryDetails, missingLeanDecls) :=
        match node.code with
        | none => (0, 0, ([] : List Name), ([] : List SorryItem), ([] : List MissingLeanDeclItem))
        | some .userOk =>
          (0, 0, ([] : List Name), ([] : List SorryItem), ([] : List MissingLeanDeclItem))
        | some (.external decls) =>
          let leanObjects := (decls.map (·.canonical)).toList
          let missingDecls :=
            decls.foldl (init := []) fun acc decl =>
              if !decl.presentAtRegistration then
                {
                  label
                  kind := toString node.kind
                  written := decl.written
                  canonical := decl.canonical
                } :: acc
              else
                acc
          let incompleteDecls :=
            decls.foldl (init := #[]) fun acc decl =>
              if !decl.presentAtRegistration then
                acc
              else
                let status := externalAdapter.provedStatus decl.canonical
                if status.isIncomplete then
                  acc.push (decl.canonical, status)
                else
                  acc
          let sorryDetails :=
            incompleteDecls.toList.map fun (decl, status) =>
              {
                label
                kind := toString node.kind
                decl
                isTheorem := externalAdapter.isTheoremLike decl
                status
              }
          (decls.size, incompleteDecls.size, leanObjects, sorryDetails, missingDecls)
        | some (.literate code) =>
          let theoremNames : NameSet := code.definedTheorems.foldl (init := {}) fun acc (d : Data.LiterateThm) => acc.insert d.name
          let leanObjects := (code.definedDefs.map (·.name) ++ code.definedTheorems.map (·.name)).toList
          let leanDecls := code.definedDefs.size + code.definedTheorems.size
          let sorries := countDefSorries code.definedDefs + countThmSorries code.definedTheorems
          let sorryDetails :=
            collectDefSorries label (toString node.kind) code.definedDefs theoremNames ++
            collectThmSorries label (toString node.kind) code.definedTheorems theoremNames
          (leanDecls, sorries, leanObjects, sorryDetails, ([] : List MissingLeanDeclItem))
      let pendingInformalProofEntries : List PendingProofItem :=
        if hasCode && ((kindNeedsInformalProof node.kind && !hasProof) || !hasStatement) then
          { label, kind := toString node.kind, leanObjects } :: acc.pendingInformalProofEntries
        else
          acc.pendingInformalProofEntries
      let definitionIndex : List IndexItem :=
        if node.kind == Data.NodeKind.definition then
          { label, kind := toString node.kind, leanObjects } :: acc.definitionIndex
        else
          acc.definitionIndex
      let theoremLikeIndex : List IndexItem :=
        if kindNeedsInformalProof node.kind then
          { label, kind := toString node.kind, leanObjects } :: acc.theoremLikeIndex
        else
          acc.theoremLikeIndex
      let acc := { acc with
        totalEntries := acc.totalEntries + 1
        leanOnlyEntries := acc.leanOnlyEntries + (if hasCode && !hasStatement then 1 else 0)
        informalOnlyEntries := acc.informalOnlyEntries + (if hasStatement && !hasCode then 1 else 0)
        pendingInformalProofEntries
        leanDecls := acc.leanDecls + leanDecls
        sorries := acc.sorries + sorries
        sorryDetails := sorryDetails ++ acc.sorryDetails
        missingLeanDecls := missingLeanDecls ++ acc.missingLeanDecls
        definitionIndex
        theoremLikeIndex
      }
      match node.kind with
      | Data.NodeKind.definition => { acc with definitions := acc.definitions + 1 }
      | Data.NodeKind.lemma => { acc with lemmas := acc.lemmas + 1 }
      | Data.NodeKind.theorem => { acc with theorems := acc.theorems + 1 }
      | Data.NodeKind.corollary => { acc with corollaries := acc.corollaries + 1 }
  let theoremLikeByParent : List ParentTheoremGroup :=
    let grouped := entries.foldl (init := ({} : NameMap (List IndexItem))) fun acc (label, node) =>
      if kindNeedsInformalProof node.kind then
        let leanObjects : List Name :=
          match node.code with
          | some (.external decls) => (decls.map (·.canonical)).toList
          | some (.literate code) =>
            (code.definedDefs.map (·.name) ++ code.definedTheorems.map (·.name)).toList
          | _ => []
        match node.parent with
        | some parent =>
          let item : IndexItem := { label, kind := toString node.kind, leanObjects }
          addParentTheoremLikeItem acc parent item
        | none => acc
      else
        acc
    grouped.toArray.toList.foldr (init := []) fun (parent, items) acc =>
      if (parentChildren.getD parent #[]).size <= 1 then
        acc
      else
        let header := groupHeaders.getD parent parent.toString
        { parent, header, entries := items.reverse } :: acc
  return { summary with theoremLikeByParent }

end Informal.Commands
