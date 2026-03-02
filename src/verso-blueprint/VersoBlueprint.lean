/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias, David Thrane Christiansen
-/

-- XXX VersoManual is not module yet
-- module

-- Blueprint library extending the Verso `Manual` genre.

import Lean.Elab.InfoTree.Types

import VersoManual

import VersoBlueprint.Data
import VersoBlueprint.Environment
import VersoBlueprint.Attribute
import VersoBlueprint.Cite
import VersoBlueprint.Commands
import VersoBlueprint.Commands.ShowGraph
import VersoBlueprint.Lean
import VersoBlueprint.NameParsing
import VersoBlueprint.PreviewCache
import VersoBlueprint.Resolve
import VersoBlueprint.StyleSwitcher
import VersoBlueprint.TexPrelude
import VersoBlueprint.Widget
import VersoBlueprint.Profiling

set_option doc.verso true

open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse
open Lean.Doc.Syntax
open Lean Elab

namespace Informal

/- "Informal" Verso objects:

  - An informal verso object is identified by a label, and lives in the `informal` Verso domain.
  - For IO (Informal Object), we associate a `Data` entry, which mainly captures other objects the IO depends on
  - Objects are declared via directives / code blocks
  - Dependencies are declared via the {uses ...}`...` role, which _must_ be inside a directive.

Elaboration, traversal, and rendering are standard, using {ref VersoManual} helpers for custom blocks and inlines.

-/

/-- Domain for informal-like objects; each informal object is
  characterized by its canonical name declared by the user. -/
def _informal : Domain := {}

/-- Name used in {name}`TraverseState.domains` for informal objects. -/
def informalDomain : Name := Resolve.informalDomainName

/-- Name used in {name}`TraverseState.domains` for informal Lean code blocks. -/
def informalCodeDomain : Name := Resolve.informalCodeDomainName

/-- Name used in {name}`TraverseState.domains` for informal preview payloads. -/
def informalPreviewDomain : Name := Resolve.informalPreviewDomainName

/--
If enabled, unresolved or ambiguous external Lean names in `(lean := "...")` are treated as
errors instead of warnings.
-/
register_option verso.blueprint.externalCode.strictResolve : Bool := {
  defValue := false
  descr := "Treat unresolved or ambiguous `(lean := ...)` external references as errors"
}

/-- Maximum pretty-printed type preview length for external declaration metadata (`0` = unlimited). -/
register_option verso.blueprint.externalCode.previewLimit.type : Nat := {
  defValue := 1200
  descr := "Maximum external declaration type preview length (`0` disables truncation)"
}

/-- Maximum pretty-printed value preview length for external declaration metadata (`0` = unlimited). -/
register_option verso.blueprint.externalCode.previewLimit.value : Nat := {
  defValue := 1200
  descr := "Maximum external declaration value preview length (`0` disables truncation)"
}

/-- Maximum source declaration preview length for external declaration metadata (`0` = unlimited). -/
register_option verso.blueprint.externalCode.previewLimit.decl : Nat := {
  defValue := 1600
  descr := "Maximum external declaration source preview length (`0` disables truncation)"
}

/-- Maximum source RHS preview length for external declaration metadata (`0` = unlimited). -/
register_option verso.blueprint.externalCode.previewLimit.rhs : Nat := {
  defValue := 1200
  descr := "Maximum external declaration RHS preview length (`0` disables truncation)"
}

/-- Configuration for directives / code-blocks. Q: should we allow non-labelled informal objects? -/
structure Config where
  label : Data.Label
  labelSyntax : Syntax := Syntax.missing
  lean : Option String := none
  leanok : Option Bool := none
  parent : Option Data.Parent := none
  externalCode : Array Data.ExternalRef := #[]
  invalidExternalCode : Array String := #[]
--  hide : Bool := false

section
variable [Monad m] [MonadInfoTree m] [MonadLiftT CoreM m] [MonadEnv m] [MonadError m] [MonadFileMap m]

private def splitExternalCodeRefs (s : String) : Array String :=
  NameParsing.splitCsvNormalized s

private def parseExternalCodeList (lean : Option String) : Array Data.ExternalRef × Array String :=
  match lean with
  | none => (#[], #[])
  | some s =>
    (splitExternalCodeRefs s).foldl (init := (#[], #[])) fun (acc, invalid) ref =>
      match NameParsing.parseNameE ref with
      | .ok name =>
        let extRef := Data.ExternalRef.ofName name .directiveLean
        if acc.any (fun entry => entry.canonical == extRef.canonical) then
          (acc, invalid)
        else
          (acc.push extRef, invalid)
      | .error err =>
        (acc, invalid.push s!"{ref} ({err})")

private def pushExternalRefDedup (acc : Array Data.ExternalRef) (ref : Data.ExternalRef) : Array Data.ExternalRef :=
  match acc.findIdx? (fun entry => entry.canonical == ref.canonical) with
  | some idx =>
    let current := acc[idx]!
    let merged : Data.ExternalRef := {
      current with
      presentAtRegistration := current.presentAtRegistration && ref.presentAtRegistration
    }
    acc.set! idx merged
  | none =>
    acc.push ref

private def parsedExternalRef (ref : Data.ExternalRef) : Data.ExternalRef :=
  { ref with canonical := ref.written.eraseMacroScopes }

private def resolvedExternalRef (ref : Data.ExternalRef) (resolved : Name) : Data.ExternalRef :=
  { written := ref.written, canonical := resolved.eraseMacroScopes, origin := ref.origin }

private def markExternalRefPresence [MonadEnv m] (ref : Data.ExternalRef) : m Data.ExternalRef := do
  let env ← getEnv
  let canonical := ref.canonical.eraseMacroScopes
  return {
    ref with
    canonical
    presentAtRegistration := (env.find? canonical).isSome
  }

private def resolveExternalNameCandidates [MonadResolveName m] [MonadOptions m]
    [MonadLog m] [AddMessageContext m]
    (name : Name) : m (Array Name) := do
  let resolved ← Lean.resolveGlobalName name (enableLog := false)
  return resolved.foldl (init := #[]) fun acc (candidate, fieldList) =>
    if fieldList.isEmpty && !acc.contains candidate then
      acc.push candidate
    else
      acc

private def resolveExternalCodeList [MonadResolveName m] [MonadOptions m] [MonadEnv m]
    [MonadLog m] [AddMessageContext m] [MonadError m]
    (label : Name) (refs : Array Data.ExternalRef) : m (Array Data.ExternalRef) := do
  let strictResolve :=
    (← getOptions).get
      verso.blueprint.externalCode.strictResolve.name
      verso.blueprint.externalCode.strictResolve.defValue
  refs.foldlM (init := #[]) fun acc ref => do
    let candidates ← resolveExternalNameCandidates ref.written
    match candidates.toList with
    | [] =>
      let msg := m!"Label {label}: external Lean name '{ref.written}' could not be resolved in current namespace/open declarations"
      if strictResolve then
        throwError msg
      else
        logWarning m!"{msg}; keeping parsed name"
        let ref ← markExternalRefPresence (parsedExternalRef ref)
        return pushExternalRefDedup acc ref
    | [resolved] =>
      let ref ← markExternalRefPresence (resolvedExternalRef ref resolved)
      return pushExternalRefDedup acc ref
    | many =>
      let msg := m!"Label {label}: external Lean name '{ref.written}' is ambiguous ({String.intercalate ", " (many.map toString)})"
      if strictResolve then
        throwError msg
      else
        logWarning m!"{msg}; keeping parsed name"
        let ref ← markExternalRefPresence (parsedExternalRef ref)
        return pushExternalRefDedup acc ref

def Config.parse  : ArgParse m Config :=
  (fun (labelArg : Verso.ArgParse.WithSyntax String) lean leanok parent =>
    let (externalCode, invalidExternalCode) := parseExternalCodeList lean
    {
      label := Name.mkSimple labelArg.val
      labelSyntax := labelArg.syntax
      lean := lean
      leanok := leanok
      parent := parent.map Name.mkSimple
      externalCode := externalCode
      invalidExternalCode := invalidExternalCode
    }) <$> .positional `label (.withSyntax .string) <*> .named `lean .string true
        <*> .named `leanok .bool true <*> .named `parent .string true

instance : FromArgs Config m where
  fromArgs := Config.parse

structure GroupConfig where
  label : Data.Label
  labelSyntax : Syntax := Syntax.missing

def GroupConfig.parse : ArgParse m GroupConfig :=
  (fun (labelArg : Verso.ArgParse.WithSyntax String) =>
    {
      label := Name.mkSimple labelArg.val
      labelSyntax := labelArg.syntax
    }) <$> .positional `label (.withSyntax .string)

instance : FromArgs GroupConfig m where
  fromArgs := GroupConfig.parse

end

structure SourceLoc where
  line : Nat
  column : Nat
deriving Repr, Inhabited, FromJson, ToJson, Quote

def SourceLoc.ofPosition (pos : Lean.Position) : SourceLoc :=
  { line := pos.line, column := pos.column }

structure SourceRange where
  start : SourceLoc
  «end» : SourceLoc
deriving Repr, Inhabited, FromJson, ToJson, Quote

def SourceRange.ofDeclarationRange (range : Lean.DeclarationRange) : SourceRange :=
  { start := SourceLoc.ofPosition range.pos, «end» := SourceLoc.ofPosition range.endPos }

inductive ExternalDeclProvenance where
  | inWorkspace (moduleName : Name) (sourcePath : String)
  | outWorkspace (moduleName : Name) (sourcePath? : Option String := none)
  | unknown
deriving Repr, Inhabited, FromJson, ToJson, Quote

def ExternalDeclProvenance.moduleName? : ExternalDeclProvenance → Option Name
  | .inWorkspace moduleName _ => some moduleName
  | .outWorkspace moduleName _ => some moduleName
  | .unknown => none

def ExternalDeclProvenance.sourcePath? : ExternalDeclProvenance → Option String
  | .inWorkspace _ sourcePath => some sourcePath
  | .outWorkspace _ sourcePath? => sourcePath?
  | .unknown => none

def ExternalDeclProvenance.label : ExternalDeclProvenance → String
  | .inWorkspace _ _ => "in workspace"
  | .outWorkspace _ _ => "out workspace"
  | .unknown => "unknown provenance"

structure ExternalDeclStatus where
  decl : Name
  canonical : Name
  present : Bool := false
  provenance : ExternalDeclProvenance := .unknown
  range? : Option SourceRange := none
  selectionRange? : Option SourceRange := none
  kind? : Option String := none
  typePretty? : Option String := none
  valuePretty? : Option String := none
  sourceDeclPretty? : Option String := none
  sourceBodyPretty? : Option String := none
  provedStatus : Data.ProvedStatus := .proved
deriving Repr, Inhabited, FromJson, ToJson, Quote

inductive BlockCodeStatus where
  | none
  | userOk
  | external (decls : Array ExternalDeclStatus)
deriving Repr, Inhabited, FromJson, ToJson, Quote

private def truncatePreview (limit : Nat) (s : String) : String :=
  if limit == 0 || s.length <= limit then
    s
  else
    (s.take limit).toString ++ "…"

private def externalTypePreviewLimit (opts : Lean.Options) : Nat :=
  opts.get
    verso.blueprint.externalCode.previewLimit.type.name
    verso.blueprint.externalCode.previewLimit.type.defValue

private def externalValuePreviewLimit (opts : Lean.Options) : Nat :=
  opts.get
    verso.blueprint.externalCode.previewLimit.value.name
    verso.blueprint.externalCode.previewLimit.value.defValue

private def externalDeclPreviewLimit (opts : Lean.Options) : Nat :=
  opts.get
    verso.blueprint.externalCode.previewLimit.decl.name
    verso.blueprint.externalCode.previewLimit.decl.defValue

private def externalRhsPreviewLimit (opts : Lean.Options) : Nat :=
  opts.get
    verso.blueprint.externalCode.previewLimit.rhs.name
    verso.blueprint.externalCode.previewLimit.rhs.defValue

private def externalDeclKindText (info : ConstantInfo) : String :=
  match info with
  | .defnInfo _ => "definition"
  | .thmInfo _ => "theorem"
  | .axiomInfo _ => "axiom"
  | .opaqueInfo _ => "opaque"
  | .quotInfo _ => "quotient"
  | .inductInfo _ => "inductive"
  | .ctorInfo _ => "constructor"
  | .recInfo _ => "recursor"

private def moduleNameForDecl? (env : Lean.Environment) (decl : Name) : Option Name := do
  let moduleIdx ← env.getModuleIdxFor? decl
  env.allImportedModuleNames[moduleIdx.toNat]?

private def sourcePathForModule? (moduleName : Name) : IO (Option System.FilePath) := do
  let srcSearchPath ← Lean.getSrcSearchPath
  srcSearchPath.findModuleWithExt "lean" moduleName

private def workspacePathPrefix (workspaceRoot : System.FilePath) : String :=
  let root := workspaceRoot.toString
  let sep := System.FilePath.pathSeparator.toString
  if root.endsWith sep then root else root ++ sep

private def isPathInWorkspace (workspaceRoot sourcePath : System.FilePath) : Bool :=
  let root := workspaceRoot.toString
  let rootPrefix := workspacePathPrefix workspaceRoot
  let src := sourcePath.toString
  src == root || src.startsWith rootPrefix

private def mkProvenance (workspaceRoot : System.FilePath)
    (moduleName? : Option Name) (sourcePath? : Option System.FilePath) : ExternalDeclProvenance :=
  match moduleName? with
  | none => .unknown
  | some moduleName =>
    match sourcePath? with
    | some sourcePath =>
      if isPathInWorkspace workspaceRoot sourcePath then
        .inWorkspace moduleName sourcePath.toString
      else
        .outWorkspace moduleName (some sourcePath.toString)
    | none =>
      .outWorkspace moduleName none

private def readDeclarationSource? (sourcePath : System.FilePath)
    (range : Lean.DeclarationRange) : IO (Option String) := do
  try
    if !(← sourcePath.pathExists) then
      return none
    let source ← IO.FS.readFile sourcePath
    let fileMap := source.toFileMap
    let start := fileMap.ofPosition range.pos
    let stop := fileMap.ofPosition range.endPos
    if stop < start then
      return none
    let snippet := (String.Pos.Raw.extract fileMap.source start stop).trimAscii.toString
    if snippet.isEmpty then
      return none
    return some snippet
  catch _ =>
    return none

private def rhsFromDeclarationSource? (declSrc : String) : Option String :=
  match declSrc.splitOn ":=" with
  | [] => none
  | [_] => none
  | _ :: rhsParts =>
    let rhs := (String.intercalate ":=" rhsParts).trimAscii.toString
    if rhs.isEmpty then
      none
    else
      some rhs

private def prettyExprPreview (env : Lean.Environment) (opts : Lean.Options) (expr : Lean.Expr)
    (limit : Nat := 1200) : CoreM String := do
  if expr.approxDepth.toNat > 220 then
    return "<omitted: expression too large for preview>"
  try
    let fmt ← liftM <| Lean.PrettyPrinter.ppExprLegacy env {} {} opts expr
    return truncatePreview limit ((toString fmt).trimAscii.toString)
  catch _ =>
    return truncatePreview limit (toString expr)

private def externalDeclStatus (env : Lean.Environment) (opts : Lean.Options)
    (workspaceRoot : System.FilePath)
    (decl : Data.ExternalRef) : CoreM ExternalDeclStatus := do
  let typePreviewLimit := externalTypePreviewLimit opts
  let valuePreviewLimit := externalValuePreviewLimit opts
  let declPreviewLimit := externalDeclPreviewLimit opts
  let rhsPreviewLimit := externalRhsPreviewLimit opts
  let canonical := decl.canonical
  if !decl.presentAtRegistration then
    return { decl := decl.written, canonical, present := false }
  match env.find? canonical with
  | none =>
    return { decl := decl.written, canonical, present := false }
  | some info =>
    let ranges? ← findDeclarationRanges? canonical
    let moduleName? := moduleNameForDecl? env canonical
    let sourcePath? ←
      match moduleName? with
      | some moduleName => liftM <| sourcePathForModule? moduleName
      | none => pure none
    let provenance := mkProvenance workspaceRoot moduleName? sourcePath?
    let sourceDecl? ←
      match sourcePath?, ranges? with
      | some sourcePath, some ranges =>
        liftM <| readDeclarationSource? sourcePath ranges.range
      | _, _ => pure none
    let sourceDeclPretty? := sourceDecl?.map (truncatePreview declPreviewLimit)
    let sourceBodyPretty? := (rhsFromDeclarationSource? =<< sourceDecl?) |>.map (truncatePreview rhsPreviewLimit)
    let typePretty ← prettyExprPreview env opts info.type typePreviewLimit
    let valuePretty? ←
      match info.value? (allowOpaque := true) with
      | none => pure none
      | some value => some <$> prettyExprPreview env opts value valuePreviewLimit
    return {
      decl := decl.written
      canonical
      present := true
      provenance
      range? := ranges?.map (fun ranges => SourceRange.ofDeclarationRange ranges.range)
      selectionRange? := ranges?.map (fun ranges => SourceRange.ofDeclarationRange ranges.selectionRange)
      kind? := some (externalDeclKindText info)
      typePretty? := some typePretty
      valuePretty?
      sourceDeclPretty?
      sourceBodyPretty?
      provedStatus := _root_.Informal.Data.ConstantInfo.blueprintProvedStatus info (allowOpaque := true)
    }
def BlockCodeStatus.ofCodeRef (env : Lean.Environment) (codeRef? : Option Data.CodeRef) : CoreM BlockCodeStatus := do
  match codeRef? with
  | some .userOk => return .userOk
  | some (.external decls) =>
    let opts ← getOptions
    let workspaceRoot ← liftM <| IO.FS.realPath (← IO.currentDir)
    let decls ← decls.mapM (externalDeclStatus env opts workspaceRoot)
    return .external decls
  | _ => return .none

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

structure ExternalHoverDecl where
  decl : Name
  href : Option String := none
  present : Bool := false
  provenance : ExternalDeclProvenance := .unknown
  range? : Option SourceRange := none
  selectionRange? : Option SourceRange := none
  kind? : Option String := none
  typePretty? : Option String := none
  valuePretty? : Option String := none
  sourceDeclPretty? : Option String := none
  sourceBodyPretty? : Option String := none
  provedStatus : Data.ProvedStatus := .proved

structure ComputedData where
  proved : Bool := false
  codeHref : Option String := none
  codeHover : Option CodeHoverData := none
  manualStatus : Bool := false
  externalDecls : Array ExternalHoverDecl := #[]
  hasStatementSorries : Bool := false
  hasProofSorries : Bool := false

private def provedStatusHasSorry (status : Data.ProvedStatus) : Bool :=
  status.isIncomplete

private def provedStatusLocationText (status : Data.ProvedStatus) : String :=
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

private def provedStatusContainsSorry (status : Data.ProvedStatus) : Bool :=
  match status with
  | .containsSorry _ => true
  | _ => false

def mkCodeHoverData
    (label : Data.Label)
    (definedDefs definedTheorems : Array CodeDeclData)
    (hrefOf : Name → Option String) : CodeHoverData :=
  let toDecl (d : CodeDeclData) : CodeHoverDecl :=
    { text := toString d.name, href := hrefOf d.name }
  let toSorry (d : CodeDeclData) : CodeHoverDecl :=
    let kind :=
      match d.provedStatus with
      | .axiomLike => "axiom-like (no body)"
      | .containsSorry _ => provedStatusLocationText d.provedStatus
      | .proved => "unknown"
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
          let kind :=
            match d.provedStatus with
            | .axiomLike => "axiom-like (no body)"
            | .containsSorry _ => provedStatusLocationText d.provedStatus
            | .proved => "unknown"
          s!"{d.name} [{kind}]"
    s!"{label}\nLean definitions: {defs}\nLean theorems/lemmas: {thms}\nSorries: {sorries}"

private def sortDeclsByCommand (decls : Array CodeDeclData) : Array CodeDeclData :=
  decls.qsort (fun a b =>
    a.commandIndex < b.commandIndex ||
    (a.commandIndex == b.commandIndex && a.name.toString < b.name.toString))

private def codeDeclSorryLocation (decl : CodeDeclData) : String :=
  provedStatusLocationText decl.provedStatus

private def externalDeclHasSorry (decl : ExternalHoverDecl) : Bool :=
  provedStatusHasSorry decl.provedStatus

private def externalDeclSorryLocation (decl : ExternalHoverDecl) : String :=
  provedStatusLocationText decl.provedStatus

private def externalDeclStatement? (decl : ExternalHoverDecl) : Option String :=
  match decl.sourceDeclPretty? with
  | some sourceDecl => some sourceDecl
  | none =>
    match decl.typePretty? with
    | none => none
    | some typePretty =>
      let keyword :=
        match decl.kind? with
        | some "definition" => "def"
        | some "theorem" => "theorem"
        | some "axiom" => "axiom"
        | some "opaque" => "opaque"
        | some "inductive" => "inductive"
        | some "constructor" => "constructor"
        | some "recursor" => "recursor"
        | some "quotient" => "quotient"
        | _ => "def"
      let head := s!"{keyword} {decl.decl} : {typePretty}"
      if decl.kind? == some "definition" then
        match decl.valuePretty? with
        | some valuePretty => some s!"{head} :=\n  {valuePretty}"
        | none => some head
      else
        some head

private def externalPanelStatus (decls : Array ExternalHoverDecl) : String × String × String :=
  let total := decls.size
  let found := decls.foldl (init := 0) fun acc decl => acc + (if decl.present then 1 else 0)
  let missing := total - found
  let withGaps := decls.foldl (init := 0) fun acc decl => acc + (if externalDeclHasSorry decl then 1 else 0)
  if missing > 0 then
    ("bp_external_status_missing", "●", s!"External Lean references: {found}/{total} present ({missing} missing)")
  else if withGaps > 0 then
    ("bp_external_status_sorry", "●", s!"External Lean references: all present, {withGaps} incomplete")
  else
    ("bp_external_status_ok", "●", s!"External Lean references: all {total} present")

private def progressSegmentClass (missing hasSorry : Bool) : String :=
  if missing then
    "bp_code_progress_segment bp_code_progress_segment_missing"
  else if hasSorry then
    "bp_code_progress_segment bp_code_progress_segment_sorry"
  else
    "bp_code_progress_segment bp_code_progress_segment_ok"

private def codePanelSummary (data : BlockData) : String :=
  if data.isProof then
    "Code for proof"
  else
    s!"Code for {data.kind} {data.count}"

def blueprintCss : String := r##"
.bp_wrapper {
  scroll-margin-top: 1rem;
  margin: 0.85rem 0;
}

.bp_heading {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  font-style: normal;
  font-weight: bold;
}

.bp_caption {
  display: inline;
}

.bp_label {
  margin-left: 0.5rem;
}

span[class$="_thmlabel"]::after {
  content: ".";
}

.bp_extras {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  margin-left: auto;
}

.bp_code_link {
  display: inline;
  font-size: 0.8rem;
  color: inherit;
  text-decoration: none;
}

.bp_code_hover_wrap,
.bp_code_link_wrap {
  position: relative;
  display: inline-flex;
  align-items: center;
  padding-bottom: 0.45rem;
  margin-bottom: -0.45rem;
}

.bp_code_hover_wrap::after,
.bp_code_link_wrap::after {
  content: "";
  position: absolute;
  left: -0.25rem;
  right: -0.25rem;
  top: 100%;
  height: 0.45rem;
}

.bp_code_hover {
  position: absolute;
  left: 50%;
  top: 100%;
  transform: translateX(-50%);
  min-width: 20rem;
  max-width: min(34rem, 75vw);
  z-index: 20;
  border: 1px solid #cbd5e1;
  border-radius: 0.45rem;
  padding: 0.45rem 0.55rem;
  background: #ffffff;
  box-shadow: 0 8px 20px rgba(15, 23, 42, 0.15);
  display: none;
  font-size: 0.78rem;
  font-style: normal;
  font-weight: 400;
}

.bp_code_hover_wrap:is(:hover, :focus-within) > .bp_code_hover,
.bp_code_link_wrap:is(:hover, :focus-within) > .bp_code_hover {
  display: block;
}

.bp_code_hover_title {
  font-weight: 700;
  margin-bottom: 0.3rem;
}

.bp_code_hover_section {
  margin-top: 0.28rem;
}

.bp_code_hover_label {
  font-weight: 600;
  color: #334155;
}

.bp_code_hover_list {
  margin: 0.12rem 0 0;
  padding-left: 1.1rem;
}

.bp_code_hover_list code {
  font-size: 0.76rem;
}

.bp_code_hover_none {
  color: #64748b;
  font-style: italic;
}

.bp_code_block summary {
  display: flex;
  align-items: center;
  gap: 0.55rem;
}

.bp_code_summary_text {
  white-space: nowrap;
}

.bp_code_summary_indicator {
  margin-left: auto;
  display: inline-flex;
  align-items: center;
}

.bp_code_progress {
  display: inline-flex;
  min-width: 9rem;
  max-width: 24rem;
  width: min(24rem, 40vw);
  height: 0.64rem;
  border-radius: 999px;
  overflow: hidden;
  border: 1px solid #94a3b8;
  background: linear-gradient(180deg, #f8fafc, #e2e8f0);
  box-shadow: inset 0 1px 1px rgba(15, 23, 42, 0.08);
}

.bp_code_progress_segment {
  min-width: 0.22rem;
}

.bp_code_progress_segment + .bp_code_progress_segment {
  border-left: 1px solid rgba(15, 23, 42, 0.35);
}

.bp_code_progress_segment_ok {
  background: #16a34a;
}

.bp_code_progress_segment_sorry {
  background: #eab308;
}

.bp_code_progress_segment_missing {
  background: #dc2626;
}

.bp_external_status_icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 0.95rem;
  height: 0.95rem;
  border-radius: 999px;
  font-size: 0.68rem;
  line-height: 1;
  color: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.22);
}

.bp_external_status_ok {
  background: #16a34a;
}

.bp_external_status_sorry {
  background: #ca8a04;
}

.bp_external_status_missing {
  background: #dc2626;
}

.bp_code_expand_hint {
  color: #64748b;
  font-size: 0.74rem;
  white-space: nowrap;
}

.bp_code_expand_hint::before {
  content: "expand";
}

details[open] > summary .bp_code_expand_hint::before {
  content: "collapse";
}

.bp_code_panel {
  margin: 0;
}

.bp_code_panel_wrapper {
  margin-top: 0.5rem;
}

.bp_code_panel_wrapper .bp_code_block > summary {
  cursor: pointer;
}

.bp_decl_target {
  background: rgba(59, 130, 246, 0.18);
  border-radius: 0.18rem;
  box-shadow: 0 0 0 0.12rem rgba(59, 130, 246, 0.22);
  animation: bp-decl-target-pulse 1.8s ease-out;
}

.bp_decl_target_block {
  border-radius: 0.3rem;
  box-shadow: 0 0 0 0.18rem rgba(59, 130, 246, 0.2);
  background: linear-gradient(180deg, rgba(59, 130, 246, 0.08), rgba(59, 130, 246, 0.04));
  animation: bp-decl-block-pulse 2.2s ease-out;
}

@keyframes bp-decl-target-pulse {
  0% {
    background: rgba(59, 130, 246, 0.28);
    box-shadow: 0 0 0 0.2rem rgba(59, 130, 246, 0.3);
  }
  100% {
    background: rgba(59, 130, 246, 0.1);
    box-shadow: 0 0 0 0.08rem rgba(59, 130, 246, 0.16);
  }
}

@keyframes bp-decl-block-pulse {
  0% {
    background: rgba(59, 130, 246, 0.14);
    box-shadow: 0 0 0 0.28rem rgba(59, 130, 246, 0.24);
  }
  100% {
    background: rgba(59, 130, 246, 0.04);
    box-shadow: 0 0 0 0.14rem rgba(59, 130, 246, 0.16);
  }
}

.bp_code_link:hover {
  text-decoration: underline;
}

.bp_status_mark {
  font-size: 0.78rem;
  font-weight: 600;
}

.bp_external_badge {
  font-size: 0.74rem;
  font-weight: 600;
  border: 1px solid #cbd5e1;
  border-radius: 0.3rem;
  padding: 0.08rem 0.35rem;
  background: #f8fafc;
}

.bp_external_decl_ok {
  color: #166534;
}

.bp_external_decl_sorry {
  color: #a16207;
}

.bp_external_decl_missing {
  color: #b91c1c;
}

.bp_external_decl_meta {
  margin-top: 0.12rem;
  color: #334155;
  font-size: 0.72rem;
}

.bp_external_decl_item {
  margin-top: 0.18rem;
}

.bp_external_decl_head {
  display: inline-flex;
  align-items: baseline;
  gap: 0.35rem;
  flex-wrap: wrap;
}

.bp_external_decl_details {
  margin-top: 0.12rem;
}

.bp_external_decl_details summary {
  cursor: pointer;
  font-size: 0.72rem;
  color: #334155;
}

.bp_external_decl_preview {
  margin-top: 0.2rem;
  border-left: 2px solid #e2e8f0;
  padding-left: 0.45rem;
}

.bp_external_decl_preview summary {
  cursor: pointer;
  font-size: 0.72rem;
  color: #1e293b;
}

.bp_external_decl_preview pre {
  margin: 0.2rem 0 0;
  max-height: 8.5rem;
  overflow: auto;
  white-space: pre-wrap;
  font-size: 0.7rem;
  line-height: 1.35;
}

.bp_external_decl_stmt {
  margin: 0.22rem 0 0;
  padding: 0.36rem 0.5rem;
  border-left: 2px solid #cbd5e1;
  background: #f8fafc;
  white-space: pre-wrap;
  font-size: 0.74rem;
  line-height: 1.35;
  color: #0f172a;
}

.bp_content {
  padding-left: 0.65rem;
}

.bp_content > :first-child {
  margin-top: 0;
}

.bp_content > :last-child {
  margin-bottom: 0;
}

.bp-proof-tail-hidden {
  display: none;
}

.bp-proof-gap-hidden {
  display: none;
}

.bp-proof-by-toggle {
  cursor: pointer;
  text-decoration: underline dotted;
  text-decoration-thickness: 1px;
}

.bp-proof-by-toggle::after {
  content: " ...";
  color: #64748b;
}

.bp-proof-by-toggle.bp-proof-open::after {
  content: "";
}

div.theorem-style-plain div[class$="_thmheading"] {
  font-style: normal;
  font-weight: bold;
}

div.theorem-style-plain div[class$="_thmcontent"] {
  font-style: italic;
  font-weight: normal;
}

div.theorem-style-definition div[class$="_thmheading"] {
  font-style: normal;
  font-weight: bold;
}

div.theorem_thmcontent {
  border-left: 0.15rem solid black;
}

div.proposition_thmcontent {
  border-left: 0.15rem solid black;
}

div.lemma_thmcontent {
  border-left: 0.1rem solid black;
}

div.corollary_thmcontent {
  border-left: 0.1rem solid black;
}

div.proof_content {
  border-left: 0.08rem solid grey;
}

.bp_wrapper:target {
  animation: bp-target-pulse 1.6s ease-out;
  box-shadow: 0 0 0 0.18rem rgba(37, 99, 235, 0.22);
  border-radius: 0.35rem;
}

@keyframes bp-target-pulse {
  0% {
    background-color: rgba(37, 99, 235, 0.14);
    box-shadow: 0 0 0 0.28rem rgba(37, 99, 235, 0.28);
  }
  100% {
    background-color: transparent;
    box-shadow: 0 0 0 0.18rem rgba(37, 99, 235, 0.22);
  }
}
"##

def blueprintStyleSwitcherCss : String := StyleSwitcher.css

def blueprintStyleSwitcherJs : String := StyleSwitcher.jsInteractive

private def mkCodePanel
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

def toHtml (data : BlockData) (cdata : ComputedData) (_domain : Json) (attrs : Array (String × String))
    (content : Array Output.Html) : Output.Html :=
  open Verso.Output.Html in
  let sourcePosText (pos : SourceLoc) : String :=
    s!"{pos.line}:{pos.column}"
  let sourceRangeText (range : SourceRange) : String :=
    s!"{sourcePosText range.start}-{sourcePosText range.end}"
  let listItems (items : Array CodeHoverDecl) : Output.Html :=
    if items.isEmpty then
      {{<li class="bp_code_hover_none">"none"</li>}}
    else
      .seq <| items.map fun item =>
        let txt := {{<code>{{.text true item.text}}</code>}}
        {{<li>{{if let some href := item.href then {{<a href={{href}}>{{txt}}</a>}} else txt}}</li>}}
  let codeHover : Output.Html :=
    match cdata.codeHover with
    | none => .empty
    | some hover => {{
      <div class="bp_code_hover" role="tooltip">
        <div class="bp_code_hover_title">{{.text true s!"{hover.label}"}}</div>
        <div class="bp_code_hover_section">
          <span class="bp_code_hover_label">"Lean definitions"</span>
          <ul class="bp_code_hover_list">
            {{listItems hover.definedDefs}}
          </ul>
        </div>
        <div class="bp_code_hover_section">
          <span class="bp_code_hover_label">"Lean theorems/lemmas"</span>
          <ul class="bp_code_hover_list">
            {{listItems hover.definedTheorems}}
          </ul>
        </div>
        <div class="bp_code_hover_section">
          <span class="bp_code_hover_label">"Sorries"</span>
          <ul class="bp_code_hover_list">
            {{listItems hover.sorries}}
          </ul>
        </div>
      </div>
    }}
  let externalHoverListItems (items : Array ExternalHoverDecl) : Output.Html :=
    if items.isEmpty then
      {{<li class="bp_code_hover_none">"none"</li>}}
    else
      .seq <| items.map fun item =>
        let declTxt := {{<code>{{.text true s!"{item.decl}"}}</code>}}
        let declNode :=
          if let some href := item.href then
            {{<a href={{href}}>{{declTxt}}</a>}}
          else
            declTxt
        let hasSorry := externalDeclHasSorry item
        let statusTxt :=
          if item.present then
            if hasSorry then
              if provedStatusContainsSorry item.provedStatus then
                s!"(has Lean declaration; contains sorry {externalDeclSorryLocation item})"
              else
                s!"(has Lean declaration; {externalDeclSorryLocation item})"
            else
              "(has Lean declaration)"
          else
            "(missing Lean declaration)"
        let statusClass :=
          if !item.present then "bp_external_decl_missing"
          else if hasSorry then "bp_external_decl_sorry"
          else "bp_external_decl_ok"
        let hasProvenanceDetails : Bool :=
          match item.provenance with
          | .unknown => false
          | _ => true
        let provenanceLabel := item.provenance.label
        let moduleName? := item.provenance.moduleName?
        let sourcePath? := item.provenance.sourcePath?
        let sourceInfo? : Option String :=
          match moduleName?, (item.selectionRange?.map sourceRangeText <|> item.range?.map sourceRangeText) with
          | some moduleName, some rangeTxt => some s!"{moduleName} @ {rangeTxt}"
          | some moduleName, none => some s!"{moduleName}"
          | none, some rangeTxt => some s!"{rangeTxt}"
          | none, none => none
        let sorryInfo? : Option String :=
          if hasSorry then
            if provedStatusContainsSorry item.provedStatus then
              some s!"Contains sorry ({externalDeclSorryLocation item})"
            else
              some "Axiom-like declaration (no body)"
          else
            none
        {{
          <li class="bp_external_decl_item">
            <div class="bp_external_decl_head">
              {{declNode}}
              <span class={{statusClass}}>{{.text true statusTxt}}</span>
              {{if hasProvenanceDetails then {{<span class="bp_external_badge">{{.text true provenanceLabel}}</span>}} else .empty}}
            </div>
            {{if let some kind := item.kind? then {{<div class="bp_external_decl_meta">"kind: " <code>{{.text true kind}}</code></div>}} else .empty}}
            {{if let some sourceInfo := sourceInfo? then {{<div class="bp_external_decl_meta">"source: " <code>{{.text true sourceInfo}}</code></div>}} else .empty}}
            {{if let some sourcePath := sourcePath? then {{<div class="bp_external_decl_meta">"source path: " <code>{{.text true sourcePath}}</code></div>}} else .empty}}
            {{if let some sorryInfo := sorryInfo? then {{<div class="bp_external_decl_meta bp_external_decl_missing">{{.text true sorryInfo}}</div>}} else .empty}}
          </li>
        }}
  let externalPanelListItems (items : Array ExternalHoverDecl) : Output.Html :=
    if items.isEmpty then
      {{<li class="bp_code_hover_none">"none"</li>}}
    else
      .seq <| items.map fun item =>
        let declTxt := {{<code>{{.text true s!"{item.decl}"}}</code>}}
        let declNode :=
          if let some href := item.href then
            {{<a href={{href}}>{{declTxt}}</a>}}
          else
            declTxt
        let hasSorry := externalDeclHasSorry item
        let statusTxt :=
          if item.present then
            if hasSorry then
              if provedStatusContainsSorry item.provedStatus then
                s!"contains sorry {externalDeclSorryLocation item}"
              else
                externalDeclSorryLocation item
            else
              "complete"
          else
            "missing declaration"
        let statusClass :=
          if !item.present then "bp_external_decl_missing"
          else if hasSorry then "bp_external_decl_sorry"
          else "bp_external_decl_ok"
        let statementNode :=
          if let some stmt := externalDeclStatement? item then
            {{<pre class="bp_external_decl_stmt hl lean block"><code>{{.text true stmt}}</code></pre>}}
          else if item.present then
            {{<pre class="bp_external_decl_stmt bp_code_hover_none">"statement unavailable (pretty-printer failed)"</pre>}}
          else
            {{<pre class="bp_external_decl_stmt bp_code_hover_none">"statement unavailable (declaration not found)"</pre>}}
        {{
          <li class="bp_external_decl_item">
            <div class="bp_external_decl_head">
              {{declNode}} " " <span class={{statusClass}}>{{.text true statusTxt}}</span>
            </div>
            {{statementNode}}
          </li>
        }}
  let externalHover : Output.Html :=
    if cdata.externalDecls.isEmpty then
      .empty
    else
      {{
        <div class="bp_code_hover" role="tooltip">
          <div class="bp_code_hover_title">"External Lean references"</div>
          <div class="bp_code_hover_section">
            <ul class="bp_code_hover_list">
              {{externalHoverListItems cdata.externalDecls}}
            </ul>
          </div>
        </div>
      }}
  let manualHover : Output.Html :=
    if cdata.manualStatus then
      {{
        <div class="bp_code_hover" role="tooltip">
          <div class="bp_code_hover_title">"Lean status"</div>
          <div class="bp_code_hover_section">
            <span class="bp_code_hover_none">"Marked complete via (leanok := true)."</span>
          </div>
        </div>
      }}
    else
      .empty
  let hasExternal := !cdata.externalDecls.isEmpty
  let hasInline := cdata.codeHref.isSome || cdata.codeHover.isSome
  let hasCodeEntry := hasExternal || hasInline || cdata.manualStatus
  let codeEntryHover : Output.Html :=
    if hasExternal then
      externalHover
    else if cdata.codeHover.isSome then
      codeHover
    else if cdata.manualStatus then
      manualHover
    else
      .empty
  let codeEntryTitle : String :=
    if hasExternal then
      let total := cdata.externalDecls.size
      let found := cdata.externalDecls.foldl (init := 0) fun acc decl => acc + (if decl.present then 1 else 0)
      let withGaps := cdata.externalDecls.foldl (init := 0) fun acc decl => acc + (if externalDeclHasSorry decl then 1 else 0)
      if found == total then
        if withGaps == 0 then
          s!"External Lean references (all present: {found}/{total})"
        else
          s!"External Lean references (all present: {found}/{total}; incomplete: {withGaps})"
      else
        s!"External Lean references ({found}/{total} present)"
    else if cdata.manualStatus then
      "Marked complete via (leanok := true)"
    else
      "Lean declarations"
  let codeEntry : Output.Html :=
    if !hasCodeEntry then
      .empty
    else
      let linkNode : Output.Html :=
        if let some href := cdata.codeHref then
          {{<a class="bp_code_link" href={{href}} title={{codeEntryTitle}}>"L∃∀N"</a>}}
        else
          {{<span class="bp_code_link" title={{codeEntryTitle}}>"L∃∀N"</span>}}
      {{<span class="bp_code_link_wrap">{{linkNode}}{{codeEntryHover}}</span>}}
  let externalStatusIndicator : Output.Html :=
    if !hasExternal then
      .empty
    else
      let (iconClass, iconText, iconTitle) := externalPanelStatus cdata.externalDecls
      let icon :=
        {{<span class={{s!"bp_external_status_icon {iconClass}"}} title={{iconTitle}}>{{.text true iconText}}</span>}}
      {{<span class="bp_code_hover_wrap bp_code_summary_indicator">{{icon}}{{externalHover}}</span>}}
  let externalCodePanel : Output.Html :=
    if !hasExternal || data.isProof then
      .empty
    else
      mkCodePanel (codePanelSummary data) codeEntryTitle externalStatusIndicator
        {{<ul class="bp_code_hover_list">{{externalPanelListItems cdata.externalDecls}}</ul>}}
  let kindText := if data.isProof then "Proof" else s!"{data.kind}"
  let labelTextNum := s!"{data.count}"
  let labelText := s!"{data.label}"
  let showLabel := !data.isProof
  let (kindCss, wrapperCss, headingCss, captionCss, labelCss, contentCss) :=
    if data.isProof then
      ("proof", "proof_wrapper bp_kind_proof",
        "proof_heading", "proof_caption", "proof_label", "proof_content")
    else
      match data.kind with
      | .definition =>
        ("definition", "definition_thmwrapper theorem-style-definition bp_kind_definition",
          "definition_thmheading", "definition_thmcaption", "definition_thmlabel", "definition_thmcontent")
      | .theorem =>
        ("theorem", "theorem_thmwrapper theorem-style-plain bp_kind_theorem",
          "theorem_thmheading", "theorem_thmcaption", "theorem_thmlabel", "theorem_thmcontent")
      | .lemma =>
        ("lemma", "lemma_thmwrapper theorem-style-plain bp_kind_lemma",
          "lemma_thmheading", "lemma_thmcaption", "lemma_thmlabel", "lemma_thmcontent")
      | .corollary =>
        ("corollary", "corollary_thmwrapper theorem-style-plain bp_kind_corollary",
          "corollary_thmheading", "corollary_thmcaption", "corollary_thmlabel", "corollary_thmcontent")
  let wrapperClass := s!"bp_wrapper {kindCss}_thmwrapper {wrapperCss}"
  let headingClass := s!"bp_heading {headingCss}"
  let captionClass := s!"bp_caption {captionCss}"
  let labelClass := s!"bp_label {labelCss}"
  let contentClass := s!"bp_content {contentCss}"
  let statusMark : Output.Html :=
    if hasExternal then
      let total := cdata.externalDecls.size
      let found := cdata.externalDecls.foldl (init := 0) fun acc decl => acc + (if decl.present then 1 else 0)
      let missing := total - found
      let withGaps := cdata.externalDecls.foldl (init := 0) fun acc decl => acc + (if externalDeclHasSorry decl then 1 else 0)
      let (title, mark) :=
        if missing > 0 then
          (s!"External Lean names: {found} present, {missing} missing", "✗")
        else if withGaps > 0 then
          (s!"External Lean names ({total}) are present, but {withGaps} are incomplete", "⚠")
        else
          (s!"External Lean names ({total}) are present", "✓")
      {{ <span class="bp_status_mark" title={{title}}>{{.text true mark}}</span> }}
    else if cdata.manualStatus then
      {{ <span class="bp_status_mark" title="Marked complete via (leanok := true)">"✓ (manually set)"</span> }}
    else if cdata.codeHref.isNone then
      .empty
    else
      let (hasSorriesHere, whereTxt) :=
        if data.isProof then
          (cdata.hasProofSorries, "proof")
        else
          (cdata.hasStatementSorries, "statement")
      let mark := if hasSorriesHere then "✗" else "✓"
      let title := if hasSorriesHere then s!"Contains sorries in {whereTxt}" else s!"No sorries in {whereTxt}"
      {{ <span class="bp_status_mark" title={{title}}>{{.text true mark}}</span> }}
  let informalBlock : Output.Html := {{
    <div class={{wrapperClass}} title={{labelText}} {{attrs}}>
      <div class={{headingClass}}>
        <span class={{captionClass}} title={{labelText}}> {{.text true kindText}} </span>
        {{ if showLabel then {{<span class={{labelClass}}> {{.text true labelTextNum}} </span>}} else .empty }}
        <div class="bp_extras thm_header_extras">
          {{statusMark}}
          {{codeEntry}}
        </div>
        <div class="bp_hiddenextras thm_header_hidden_extras"> </div>
      </div>
      <div class={{contentClass}}> {{ content }} </div>
    </div>
  }}
  .seq #[informalBlock, externalCodePanel]

/- Informal custom blocks -/
block_extension Block.informal (data : BlockData) where
  -- for TOC
  -- localContentItem _ _ _ := none
  data := toJson data
  traverse id data _contents := do
    -- XXX: (maybe) lift the Except into the main monad error thread
    match fromJson? (α := BlockData) data with
    | .error err =>
      logError s!"Malformed data ({err}): {data}"
      pure none
    | .ok blockData =>
      let label := blockData.label
      let previewKey := PreviewCache.keyOf label blockData.isProof
      let previewData := toJson (PreviewCache.Entry.ofBlocks label blockData.isProof _contents)
      if let .some _d := (← get).getDomainObject? informalPreviewDomain previewKey then
        modify λ s => s.saveDomainObjectData informalPreviewDomain previewKey previewData
      else
        let path ← (·.path) <$> read
        let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-preview-{previewKey}"
        modify λ s => s.saveDomainObject informalPreviewDomain previewKey id
        modify λ s => s.saveDomainObjectData informalPreviewDomain previewKey previewData
      if let .some _d := (← get).getDomainObject? informalDomain label.toString then
        return none
      else
        let path ← (·.path) <$> read
        let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-{label}"
        modify λ s => s.saveDomainObject informalDomain label.toString id
        modify λ s => s.saveDomainObjectData informalDomain label.toString (toJson blockData)
        return none
  toTeX := none
  extraCss := ([blueprintCss, blueprintStyleSwitcherCss] : List String)
  extraJs := ([blueprintStyleSwitcherJs] : List String)
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB id data blocks => do
      match fromJson? (α := BlockData) data with
      | .error err =>
        HtmlT.logError s!"Malformed data ({err}): {data}"
        pure .empty
      | .ok data =>
        let s ← HtmlT.state
        let attrs := s.htmlId id
        let dentry : Json := ((s.getDomainObject? informalDomain data.label.toString).map (·.data)).getD (.str "")
        let codeHref : Option String :=
          match s.resolveDomainObject informalCodeDomain data.label.toString with
          | .ok dest => some dest.relativeLink
          | .error _ => none
        let codeData? : Option CodeBlockData :=
          match s.getDomainObject? informalCodeDomain data.label.toString with
          | none => none
          | some obj =>
            match fromJson? (α := CodeBlockData) obj.data with
            | .ok cdata => some cdata
            | .error _ => none
        let getDeclHref (decl : Name) : Option String :=
          Resolve.resolveExampleDeclHref? s decl
        let codeHover : Option CodeHoverData := codeData?.map (fun cdata =>
          mkCodeHoverData data.label cdata.definedDefs cdata.definedTheorems getDeclHref)
        let externalDecls : Array ExternalHoverDecl :=
          match data.codeStatus with
          | .external decls =>
            decls.map fun decl =>
              let href :=
                match getDeclHref decl.canonical with
                | some href => some href
                | none => getDeclHref decl.decl
              {
                decl := decl.decl
                href
                present := decl.present
                provenance := decl.provenance
                range? := decl.range?
                selectionRange? := decl.selectionRange?
                kind? := decl.kind?
                typePretty? := decl.typePretty?
                valuePretty? := decl.valuePretty?
                sourceDeclPretty? := decl.sourceDeclPretty?
                sourceBodyPretty? := decl.sourceBodyPretty?
                provedStatus := decl.provedStatus
              }
          | _ => #[]
        let manualStatus : Bool :=
          match data.codeStatus with
          | .userOk => true
          | _ => false
        let hasSorries : Bool :=
          match codeData? with
          | none => false
          | some cdata => (cdata.definedDefs ++ cdata.definedTheorems).any (provedStatusHasSorry ∘ (·.provedStatus))
        let hasStatementSorries : Bool :=
          match codeData? with
          | none => false
          | some cdata =>
            (cdata.definedDefs ++ cdata.definedTheorems).any (fun decl => decl.provedStatus.hasTypeGap)
        let hasProofSorries : Bool :=
          match codeData? with
          | none => false
          | some cdata =>
            (cdata.definedDefs ++ cdata.definedTheorems).any (fun decl => decl.provedStatus.hasProofGap)
        let cdata := {
          proved := codeData?.isSome && !hasSorries
          codeHref
          codeHover
          manualStatus
          externalDecls
          hasStatementSorries
          hasProofSorries
        }
        return toHtml data cdata dentry attrs (← blocks.mapM goB)

block_extension Block.informalCode (data : CodeBlockData) where
  data := toJson data
  traverse id data _contents := do
    let .ok cdata@{ label, definedDefs := _, definedTheorems := _, foldProofs := _ } := fromJson? (α := CodeBlockData) data
      | logError s!"Malformed data: {data}"
        pure none
    if let .some _d := (← get).getDomainObject? informalCodeDomain label.toString then
      pure none
    else
      let path ← (·.path) <$> read
      let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-code-{label}"
      modify λ s => s.saveDomainObject informalCodeDomain label.toString id
      modify λ s => s.saveDomainObjectData informalCodeDomain label.toString (toJson cdata)
      pure none
  toTeX := none
  extraCss := ([blueprintCss, blueprintStyleSwitcherCss] : List String)
  extraJs := ([blueprintStyleSwitcherJs] : List String)
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB id data blocks => do
      let .ok { label, definedDefs, definedTheorems, foldProofs } := fromJson? (α := CodeBlockData) data
        | HtmlT.logError s!"Malformed data: {data}"
          pure .empty
      let s ← HtmlT.state
      let attrs := s.htmlId id
      let summaryText :=
        match s.getDomainObject? informalDomain label.toString with
        | some obj =>
          match fromJson? (α := BlockData) obj.data with
          | .ok b => codePanelSummary b
          | .error _ => "Code"
        | none => "Code"
      let orderedDecls := sortDeclsByCommand (definedDefs ++ definedTheorems)
      let getDeclHref (decl : Name) : Option String :=
        Resolve.resolveExampleDeclHref? s decl
      let summaryHoverData := mkCodeHoverData label definedDefs definedTheorems getDeclHref
      let listItems (items : Array CodeHoverDecl) : Output.Html :=
        if items.isEmpty then
          {{<li class="bp_code_hover_none">"none"</li>}}
        else
          .seq <| items.map fun item =>
            let txt := {{<code>{{.text true item.text}}</code>}}
            {{<li>{{if let some href := item.href then {{<a href={{href}}>{{txt}}</a>}} else txt}}</li>}}
      let progressHover : Output.Html := {{
        <div class="bp_code_hover" role="tooltip">
          <div class="bp_code_hover_title">{{.text true s!"{summaryHoverData.label}"}}</div>
          <div class="bp_code_hover_section">
            <span class="bp_code_hover_label">"Lean definitions"</span>
            <ul class="bp_code_hover_list">
              {{listItems summaryHoverData.definedDefs}}
            </ul>
          </div>
          <div class="bp_code_hover_section">
            <span class="bp_code_hover_label">"Lean theorems/lemmas"</span>
            <ul class="bp_code_hover_list">
              {{listItems summaryHoverData.definedTheorems}}
            </ul>
          </div>
          <div class="bp_code_hover_section">
            <span class="bp_code_hover_label">"Sorries"</span>
            <ul class="bp_code_hover_list">
              {{listItems summaryHoverData.sorries}}
            </ul>
          </div>
        </div>
      }}
      let progressBar : Output.Html :=
        if orderedDecls.isEmpty then
          .empty
        else
          let segments := orderedDecls.map fun decl =>
            let hasSorry := provedStatusHasSorry decl.provedStatus
            let cls := progressSegmentClass false hasSorry
            let weight := max decl.weight 1
            let title :=
              if hasSorry then
                if provedStatusContainsSorry decl.provedStatus then
                  s!"{decl.name}: contains sorry {codeDeclSorryLocation decl}"
                else
                  s!"{decl.name}: {codeDeclSorryLocation decl}"
              else
                s!"{decl.name}: complete"
            {{<span class={{cls}} title={{title}} style={{s!"flex: {weight} 1 0%"}}></span>}}
          let bar := {{<span class="bp_code_progress" aria-label="Lean declaration progress">{{segments}}</span>}}
          {{<span class="bp_code_hover_wrap bp_code_summary_indicator">{{bar}}{{progressHover}}</span>}}
      let summaryHover := codeHoverText label definedDefs definedTheorems
      let panelAttrs := attrs.push ("data-bp-proof-fold", if foldProofs then "on" else "off")
      let panelBody := .seq (← blocks.mapM goB)
      pure <| mkCodePanel summaryText summaryHover progressBar panelBody panelAttrs

private def expanderImpl (kind : Data.NodeKind) (isProof : Bool := false) : DirectiveExpanderOf Config
  | cfg, contents => do
    let blockRef ← getRef
    let label := cfg.label
    let kind? := if isProof then none else some kind
    let resolvedExternalCode ← resolveExternalCodeList label cfg.externalCode
    let hasExternal := !resolvedExternalCode.isEmpty
    let hasLeanok := cfg.leanok.getD false
    if !cfg.invalidExternalCode.isEmpty then
      logWarning m!"Label {label}: ignoring malformed names in '(lean := ...)' ({String.intercalate ", " cfg.invalidExternalCode.toList})"
    if hasExternal && hasLeanok then
      logError m!"Label {label} cannot use '(leanok := true)' together with '(lean := ...)'"
    let codeHint : Option Data.CodeRef :=
      if hasExternal then
        some (.external resolvedExternalCode)
      else if hasLeanok then
        some .userOk
      else
        none
    Environment.push label kind? isProof codeHint cfg.parent
    let contents ← contents.mapM elabBlock
    if !isProof then
      -- TODO: consolidate this widget-oriented elaboration cache with the traversal preview cache
      -- once we have a phase-safe representation that can serve both pipelines.
      Environment.setStatementElab contents
    let count ← Environment.pop blockRef
    let node? ← Environment.getNode? label
    let env ← getEnv
    let nodeCodeRef? := node?.bind (·.code)
    let nodeKind := node?.map (·.kind) |>.getD kind
    let codeStatus ← BlockCodeStatus.ofCodeRef env nodeCodeRef?
    -- Make the blueprint widget available when selecting this labeled block.
    activateForLabelDoc label blockRef
    let data : BlockData := { kind := nodeKind, label, count, isProof, codeStatus }
    ``(Block.other (Block.informal $(quote data)) #[$contents,*])

private def directiveName (kind : Data.NodeKind) (isProof : Bool): String :=
  if isProof then "proof" else (toString kind).toLower

private def expander (kind : Data.NodeKind) (isProof : Bool := false) : DirectiveExpanderOf Config
  | cfg, contents => do
    let label := (directiveName kind isProof)
    Profile.withDocElab "directive" label <|
      (expanderImpl kind isProof) cfg contents

private def collapseWhitespace (s : String) : String :=
  let s := s.replace "\n" " "
  let s := s.replace "\r" " "
  let s := s.replace "\t" " "
  String.intercalate " " <| (s.splitOn " ").filter (fun chunk => !chunk.isEmpty)

private def normalizeGroupChunk (s : String) : String :=
  let s := s.trimAscii.toString
  let s := s.replace "para{\"" ""
  let s := s.replace "para{" ""
  let s := s.replace "\"}" ""
  let s := s.replace "}" ""
  let s := s.replace "\"" ""
  s.trimAscii.toString

private def groupHeaderFromContents (contents : Array (TSyntax `block)) : String :=
  let raw := contents.foldl (init := "") fun acc block =>
    let chunk := normalizeGroupChunk <| (Syntax.reprint block.raw).getD ""
    if chunk.isEmpty then
      acc
    else if acc.isEmpty then
      chunk
    else
      acc ++ "\n" ++ chunk
  collapseWhitespace raw

private def groupExpanderImpl : DirectiveExpanderOf GroupConfig
  | cfg, contents => do
    let header := groupHeaderFromContents contents
    if header.isEmpty then
      logWarning m!"Group {cfg.label} has an empty body; using the group label as header text"
    Environment.registerGroup cfg.label (if header.isEmpty then cfg.label.toString else header)
    ``(Block.concat #[])

@[directive] def «definition» := expander .definition
@[directive] def «lemma_» := expander .lemma
@[directive] def «theorem» := expander .theorem
@[directive] def «corollary» := expander .corollary
@[directive] def «proof» := expander .lemma (isProof := true)
@[directive] def «group» : DirectiveExpanderOf GroupConfig
  | cfg, contents => do
    Profile.withDocElab "directive" "group" <|
      groupExpanderImpl cfg contents

/-- Interpreting Embedded Lean Code blocks -/
private def leanImpl : CodeBlockExpanderOf Config
  | cfg, contents => do
    let leanCfg : Lean.LeanBlockConfig := { Lean.defaultConfig with name := some (cfg.label : Lean.Name) }
    let res ← Lean.elabCommands leanCfg contents
    let codeBlock := res.block
    let definedDefs := res.definedDefs.map CodeDeclData.ofLiterateDef
    let definedTheorems := res.definedTheorems.map CodeDeclData.ofLiterateThm
    let data : CodeBlockData := {
      label := cfg.label
      definedDefs
      definedTheorems
      foldProofs := verso.blueprint.foldProofs.get (← getOptions)
    }
    let codeRef ← getRef
    Environment.registerCode cfg.label codeRef res.definedDefs res.definedTheorems
    activateForLabelDoc cfg.label codeRef
    ``(Block.other (Block.informalCode $(quote data)) #[$codeBlock])

@[code_block]
def lean : CodeBlockExpanderOf Config
  | cfg, contents => do
    Profile.withDocElab "code_block" "lean" <| leanImpl cfg contents

/-- Internal Lean setup blocks:
executed but not rendered and not tracked as blueprint code blocks. -/
private def internalImpl : CodeBlockExpanderOf Unit
  | _, contents => do
    let leanCfg : Lean.LeanBlockConfig := { Lean.defaultConfig with «show» := false, name := none }
    let _ ← Lean.elabCommands leanCfg contents
    ``(Block.concat #[])

@[code_block]
def internal : CodeBlockExpanderOf Unit
  | cfg, contents => do
    Profile.withDocElab "code_block" "internal" <| internalImpl cfg contents

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
        let titleText := s!"{block.kind} {block.count}"
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
  { kind := node.kind, label, count := node.count }

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

-- Extra stuff
private def rocqImpl : CodeBlockExpanderOf Unit
  | _cfg, contents => do
    ``(Block.code $contents)

@[code_block]
def rocq : CodeBlockExpanderOf Unit
  | cfg, contents => do
    Profile.withDocElab "code_block" "rocq" <| rocqImpl cfg contents

end Informal
