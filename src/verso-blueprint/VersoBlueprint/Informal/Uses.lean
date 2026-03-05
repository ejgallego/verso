/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import VersoManual
import VersoBlueprint.Environment
import VersoBlueprint.Informal.Block
import VersoBlueprint.Profiling
import VersoBlueprint.Widget

open Verso Doc Elab
open Verso.Genre Manual
open _root_.Lean _root_.Lean.Elab
open _root_.Lean.Doc.Syntax

namespace Informal

structure InlineData where
  label : Data.Label
  block : Option BlockData
deriving FromJson, ToJson, Quote

inline_extension Inline.informal (data : InlineData) where
  data := toJson data
  traverse _id data contents := do
    let .ok info@{ label, block } := fromJson? (α := InlineData) data
      | logError s!"Malformed data in Inline.informal traversal: {data}"
        pure none
    if block.isSome then
      pure none
    else
      let some obj := (← get).getDomainObject? informalDomain label.toString
        | pure none
      let .ok bdata := fromJson? (α := BlockData) obj.data
        | logError s!"Malformed informal domain data for {label}: {obj.data}"
          pure none
      pure <| some (.other (Inline.informal { info with block := some bdata }) contents)
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun goI _id data inlines => do
      let .ok { label, block } := fromJson? (α := InlineData) data
        | HtmlT.logError "Malformed data in Inline.informal traversal"
          pure .empty
      let st ← HtmlT.state
      let resolvedBlock : Option BlockData :=
        match block with
        | some b => some b
        | none =>
          match st.getDomainObject? informalDomain label.toString with
          | none => none
          | some obj =>
            match fromJson? (α := BlockData) obj.data with
            | .ok b => some b
            | .error _ => none
      let href : Option String :=
        match st.resolveDomainObject informalDomain label.toString with
        | .ok dest => some dest.relativeLink
        | .error _ => none
      match resolvedBlock, inlines.isEmpty with
      | none, true =>
        return {{ <span> "[??]" </span> }}
      | none, false =>
        return {{ <span> {{ ← inlines.mapM goI }} </span> }}
      | some block, true =>
        let labelText := s!"{label}"
        let titleText :=
          match block.kind with
          | .proof => s!"Proof {block.count}"
          | .statement kind => s!"{kind} {block.count}"
        if let some href := href then
          return {{ <span> <a href={{href}} title={{labelText}}> {{titleText}} </a> </span> }}
        else
          return {{ <span title={{labelText}}> {{titleText}} </span> }}
      | some _block, false =>
        let labelText := s!"{label}"
        if let some href := href then
          return {{ <span> <a href={{href}} title={{labelText}}> {{ ← inlines.mapM goI }} </a> </span> }}
        else
          return {{ <span> {{ ← inlines.mapM goI }} </span> }}
  toTeX := none

private def Data.Node.toBlockInfo (node : Data.Node) (label : Data.Label) : BlockData :=
  { kind := .statement node.kind, label, count := node.count }

private def usesImpl : RoleExpanderOf Config
  | cfg, contents => do
    let contents ← contents.mapM elabInline
    let label := cfg.label
    let node ← Environment.getNode? label
    let useRef ← getRef
    Environment.addDep useRef label
    -- Activate the widget if we can resolve the reference
    if node.isSome then
      activateForLabelDoc label useRef
    let data : InlineData := { label, block := node.map (fun n => n.toBlockInfo label) }
    ``(Inline.other (Inline.informal $(quote data)) #[$contents,*])

@[role]
def uses : RoleExpanderOf Config
  | cfg, contents => do
    Profile.withDocElab "role" "uses" <| usesImpl cfg contents

end Informal
