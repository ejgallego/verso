/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Lean
import Lean.Elab.Command
import Std.Data.HashSet
import VersoManual
import VersoBlueprint.Informal.Block
import VersoBlueprint.Informal.Group
import VersoBlueprint.PreviewCache
import VersoBlueprint.PreviewRender
import VersoBlueprint.Resolve

namespace Informal.PreviewManifest

open Lean Elab Command Term Meta
open Verso Doc
open Verso.Genre Manual

structure Entry where
  /-- Composite preview lookup key, currently `{label}--{facet}`. -/
  key : String
  /-- Canonical informal node label. -/
  label : Name
  /-- Which preview variant this entry contains: statement or proof. -/
  facet : PreviewCache.Facet
  /-- Kind (definition, lemma, theorem, corollary). -/
  kind : Option Informal.Data.NodeKind := none
  /-- Resolved display title for this preview entry. -/
  title : String
  /-- Canonical link target for the rendered informal node. -/
  href : Option String := none
  /-- Parent/group label for this informal node, if any. -/
  parent : Option Name := none
  /-- Resolved display title for the parent/group, if any. -/
  parentTitle : Option String := none
  /-- Informal nodes used by the statement. -/
  statementDeps : Array Name := #[]
  /-- Informal nodes used by the proof. -/
  proofDeps : Array Name := #[]
  /-- Resolved display name of the assigned owner, if available. -/
  ownerDisplayName : Option String := none
  /-- Normalized tags attached to this informal node. -/
  tags : Array String := #[]
  /-- Declared triage priority for this informal node, if any. -/
  priority : Option String := none
  /-- Declared effort estimate for this informal node, if any. -/
  effort : Option String := none
  /-- Rendered HTML body for this preview. -/
  html : String
deriving Inhabited, Repr, ToJson, FromJson

structure File where
  previews : Array Entry := #[]
deriving Inhabited, Repr, ToJson, FromJson

private structure SchemaState where
  seen : Std.HashSet Name := {}
  defs : Array (String × Json) := #[]

private def jsonSchemaRef (name : Name) : Json :=
  Json.mkObj [("$ref", Json.str s!"#/$defs/{name}")]

private def fieldKey (name : Name) : String :=
  name.getString!

private def fieldType (fieldName : Name) : MetaM Expr := do
  let info ← getConstInfo fieldName
  Meta.forallTelescopeReducing info.type fun _ body => pure body

private def docSummary (docs : String) : String :=
  match docs.trimAscii.toString.splitOn "\n\n" with
  | [] => ""
  | first :: _ => first.trimAscii.toString

private def schemaWithDescription (schema : Json) (docs : String) : Json :=
  let docs := docSummary docs
  if docs.isEmpty then
    schema
  else
    let combined :=
      match schema.getObjValAs? String "description" with
      | .ok existing =>
          let existing := existing.trimAscii.toString
          if existing.isEmpty then docs else s!"{docs} {existing}"
      | .error _ => docs
    schema.setObjVal! "description" (Json.str combined)

private partial def schemaForType (ty : Expr) : StateT SchemaState MetaM Json := do
  let ty ← Meta.whnf ty
  let args := Expr.getAppArgs ty
  match Expr.getAppFn ty with
  | .const ``String _ =>
      pure <| Json.mkObj [("type", Json.str "string")]
  | .const ``Name _ =>
      pure <| Json.mkObj [
        ("type", Json.str "string"),
        ("description", Json.str "Lean `Name`, encoded as a JSON string")
      ]
  | .const ``Bool _ =>
      pure <| Json.mkObj [("type", Json.str "boolean")]
  | .const ``Nat _ =>
      pure <| Json.mkObj [("type", Json.str "integer")]
  | .const ``Int _ =>
      pure <| Json.mkObj [("type", Json.str "integer")]
  | .const ``Float _ =>
      pure <| Json.mkObj [("type", Json.str "number")]
  | .const ``Array _ =>
      let itemSchema ← schemaForType args[0]!
      pure <| Json.mkObj [("type", Json.str "array"), ("items", itemSchema)]
  | .const ``List _ =>
      let itemSchema ← schemaForType args[0]!
      pure <| Json.mkObj [("type", Json.str "array"), ("items", itemSchema)]
  | .const ``Option _ =>
      let itemSchema ← schemaForType args[0]!
      pure <| Json.mkObj [
        ("anyOf", Json.arr #[
          itemSchema,
          Json.mkObj [("type", Json.str "null")]
        ])
      ]
  | .const name _ =>
      let st ← get
      if st.seen.contains name then
        return jsonSchemaRef name
      modify fun st => { st with seen := st.seen.insert name }
      let env ← getEnv
      if let some info := getStructureInfo? env name then
        let mut properties : List (String × Json) := []
        let mut required : Array Json := #[]
        for fieldInfo in info.fieldInfo do
          let schema ← schemaForType (← fieldType fieldInfo.projFn)
          let docs? ← findDocString? env fieldInfo.projFn
          let schema :=
            match docs? with
            | some docs => schemaWithDescription schema docs
            | none => schema
          let key := fieldKey fieldInfo.fieldName
          properties := properties.concat (key, schema)
          required := required.push (Json.str key)
        let schema := Json.mkObj [
          ("type", Json.str "object"),
          ("properties", Json.mkObj properties),
          ("required", Json.arr required),
          ("additionalProperties", Json.bool false)
        ]
        modify fun st => { st with defs := st.defs.push (name.toString, schema) }
        pure <| jsonSchemaRef name
      else
        match env.find? name with
        | some (.inductInfo info) =>
            let mut enumVals : Array Json := #[]
            for ctorName in info.ctors do
              let ctorInfo ← getConstInfoCtor ctorName
              unless ctorInfo.numFields == 0 do
                throwError "Schema generation currently supports only nullary inductives, but '{name}' has constructor '{ctorName}' with fields"
              enumVals := enumVals.push (Json.str ctorName.getString!)
            let schema := Json.mkObj [
              ("type", Json.str "string"),
              ("enum", Json.arr enumVals)
            ]
            modify fun st => { st with defs := st.defs.push (name.toString, schema) }
            pure <| jsonSchemaRef name
        | _ =>
            throwError "Unsupported schema type: {ty}"
  | _ =>
      throwError "Unsupported schema type: {ty}"

syntax (name := previewManifestSchema) "previewManifestSchema%" : term

@[term_elab previewManifestSchema]
def elabPreviewManifestSchema : TermElab := fun _ _ => do
  let rootTy := Lean.mkConst ``Informal.PreviewManifest.File
  let (_rootRef, st) ← Meta.liftMetaM <| (schemaForType rootTy).run {}
  let defs := st.defs.qsort (fun a b => a.1 < b.1)
  let schema : Json := Json.mkObj [
    ("$schema", Json.str "https://json-schema.org/draft/2020-12/schema"),
    ("$ref", Json.str s!"#/$defs/{``Informal.PreviewManifest.File}"),
    ("$defs", Json.mkObj defs.toList)
  ]
  let schemaText := schema.render.pretty 80
  return mkStrLit schemaText

def schemaString : String :=
  previewManifestSchema%

def schemaJson : Json :=
  match Json.parse schemaString with
  | .ok json => json
  | .error err => panic! s!"Invalid generated preview manifest schema: {err}"

private def outDirForMode (cfg : Verso.Genre.Manual.Config) (mode : Mode) : System.FilePath :=
  cfg.destination / (match mode with | .single => "html-single" | .multi => "html-multi")

private def blockInfo? (state : TraverseState) (label : Name) : Option Informal.BlockData :=
  match state.getDomainObject? Resolve.informalDomainName label.toString with
  | none => none
  | some obj =>
    match fromJson? (α := Informal.BlockData) obj.data with
    | .ok blockData => some (blockData.withResolvedNumbering state)
    | .error _ => none

private def blockTitle (state : TraverseState) (label : Name) (blockData? : Option Informal.BlockData := none) : String :=
  match blockData? <|> blockInfo? state label with
  | some blockData => blockData.displayTitle state
  | none => label.toString

private def blockHref (state : TraverseState) (label : Name) : Option String :=
  Resolve.resolveDomainHref? state Resolve.informalDomainName label.toString

private def blockKind? (blockData? : Option Informal.BlockData) : Option Informal.Data.NodeKind :=
  match blockData? with
  | some blockData =>
      match blockData.kind with
      | Informal.Data.InProgressKind.statement kind => some kind
      | Informal.Data.InProgressKind.proof => none
  | none => none

private def groupTitle? (state : TraverseState) (parent : Name) : Option String :=
  match state.getDomainObject? Resolve.informalGroupDomainName parent.toString with
  | none => none
  | some obj =>
    match fromJson? (α := Informal.GroupBlockData) obj.data with
    | .ok groupData =>
        let header := groupData.header.trimAscii.toString
        if header.isEmpty then none else some header
    | .error _ => none

private def blockParentTitle? (state : TraverseState) (blockData? : Option Informal.BlockData) : Option String :=
  blockData?.bind fun blockData =>
    blockData.parent.map fun parent =>
      (groupTitle? state parent).getD parent.toString

private def buildEntries
    (impls : ExtensionImpls)
    (logError : String → IO Unit)
    (state : TraverseState) : IO (Array Entry) := do
  let some domain := state.domains.get? Resolve.informalPreviewDomainName
    | return #[]
  let mut entries := #[]
  for (_key, obj) in domain.objects.toArray do
    match fromJson? (α := PreviewCache.Entry) obj.data with
    | .error err =>
      logError s!"Preview manifest: malformed preview entry {obj.canonicalName}: {err}"
    | .ok entry =>
      if entry.blocks.isEmpty then
        continue
      let html ← Output.Html.asString <$> Informal.renderManualBlocksHtmlWithState entry.blocks impls state
      if html.trimAscii.isEmpty then
        continue
      let blockData? := blockInfo? state entry.label
      let key := PreviewCache.key entry.label entry.facet
      let manifestEntry : Entry := {
        key
        label := entry.label
        facet := entry.facet
        kind := blockKind? blockData?
        title := blockTitle state entry.label blockData?
        href := blockHref state entry.label
        parent := blockData?.bind (·.parent)
        parentTitle := blockParentTitle? state blockData?
        statementDeps := blockData?.map (·.statementDeps) |>.getD #[]
        proofDeps := blockData?.map (·.proofDeps) |>.getD #[]
        ownerDisplayName := blockData?.bind (·.ownerDisplayName)
        tags := blockData?.map (·.tags) |>.getD #[]
        priority := blockData?.bind (·.priority)
        effort := blockData?.bind (·.effort)
        html
      }
      entries := entries.push manifestEntry
  pure <| entries.qsort (fun a b => a.key < b.key)

/--
Emit the canonical `bp-previews.json` manifest.

Block preview bodies are expected to be consumed from the manifest rather than
embedded as page-local label preview templates.
-/
def emitSharedPreviewManifest : ExtraStep := fun mode logError cfg state _text => do
  let impls ← read
  let previews ← buildEntries impls logError state
  let outDir := outDirForMode cfg mode
  let dataDir := outDir / "-verso-data"
  IO.FS.createDirAll dataDir
  let json := (toJson ({ previews } : File)).compress
  IO.FS.writeFile (dataDir / "bp-previews.json") json

initialize Verso.Genre.Manual.registerExtraStep emitSharedPreviewManifest

def dumpSchemaFlag : String := "--dump-schema"

def handleDumpSchemaFlag (args : List String) : IO (Option UInt32 × List String) := do
  if args.contains dumpSchemaFlag then
    IO.println schemaString
    pure (some 0, args.filter (· != dumpSchemaFlag))
  else
    pure (none, args)

def manualMainWithSharedPreviewManifest
    (text : Part Manual)
    (options : List String)
    (extensionImpls : ExtensionImpls)
    (config : RenderConfig := {})
    (extraSteps : List ExtraStep := []) : IO UInt32 := do
  let (dumped?, options) ← handleDumpSchemaFlag options
  if let some code := dumped? then
    return code
  manualMain text (extensionImpls := extensionImpls) (options := options) (config := config)
    (extraSteps := extraSteps)

end Informal.PreviewManifest
