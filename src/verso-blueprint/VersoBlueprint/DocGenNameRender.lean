/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.DocGenSingleDeclCompat
import VersoBlueprint.Vendor.DocGen4.ToHtmlFormat

open Lean Meta

namespace Informal

abbrev DocGenHtml := Verso.Output.Html

/--
Rendering backend for external declaration HTML snapshots.
- `docstring` uses VersoManual docstring metadata + highlighting and is the richer/default path.
- `docgen` keeps the lightweight doc-gen compatibility renderer.
-/
register_option verso.blueprint.externalCode.renderMode : String := {
  defValue := "docstring"
  descr := "External declaration render mode (`docstring` or `docgen`)"
}

inductive DocGenRenderError where
  | moduleUnavailable (decl : Name)
  | exception (decl : Name) (message : String)
  deriving Repr, Inhabited

deriving instance Lean.ToJson for DocGenRenderError
deriving instance Lean.FromJson for DocGenRenderError

instance : Lean.Quote DocGenRenderError where
  quote
    | .moduleUnavailable decl =>
        Lean.Syntax.mkApp (Lean.mkCIdent ``DocGenRenderError.moduleUnavailable) #[Lean.quote decl]
    | .exception decl message =>
        Lean.Syntax.mkApp (Lean.mkCIdent ``DocGenRenderError.exception) #[Lean.quote decl, Lean.quote message]

abbrev DocGenRender := Except DocGenRenderError DocGenHtml

def DocGenRenderError.message : DocGenRenderError → String
  | .moduleUnavailable decl => s!"module unavailable for {decl}"
  | .exception decl message => s!"{decl}: {message}"

private inductive ExternalRenderMode where
  | docstring
  | docgen

private def externalRenderMode (opts : Options) : ExternalRenderMode :=
  let raw :=
    opts.get
      verso.blueprint.externalCode.renderMode.name
      verso.blueprint.externalCode.renderMode.defValue
  match raw.trimAscii.toString.toLower with
  | "docgen" => .docgen
  | _ => .docstring

private partial def docgenHtmlToOutputHtml : DocGen4.Html → DocGenHtml
  | .element tag _inline attrs children =>
      .tag tag attrs (.seq (children.map docgenHtmlToOutputHtml))
  | .text s => .text true s
  | .raw s => .text false s

private def moduleNameForDecl? (env : Environment) (decl : Name) : Option Name := do
  let moduleIdx ← env.getModuleIdxFor? decl
  env.header.moduleNames[moduleIdx.toNat]?

private def kindDescription (env : Environment) (decl : Name) (cinfo : ConstantInfo) : String :=
  match cinfo with
  | .axiomInfo _ => "axiom"
  | .thmInfo _ => "theorem"
  | .opaqueInfo _ => "opaque"
  | .defnInfo info =>
      if info.hints.isAbbrev then "abbrev" else "def"
  | .inductInfo _ =>
      if isClass env decl then "class"
      else if isStructure env decl then "structure"
      else "inductive"
  | .ctorInfo _ => "constructor"
  | .quotInfo _ => "quot"
  | .recInfo _ => "recursor"

private def ppExprString (expr : Expr) : MetaM String := do
  return toString (← ppExpr expr)

private def fieldNames (env : Environment) (decl : Name) : Array String :=
  match getStructureInfo? env decl with
  | some info => info.fieldNames.map Name.toString
  | none => #[]

private def ctorNames (cinfo : ConstantInfo) : Array String :=
  match cinfo with
  | .inductInfo info => info.ctors.toArray.map Name.toString
  | _ => #[]

private def mkDeclHtmlInput
    (env : Environment) (moduleName : Name) (decl : Name) (cinfo : ConstantInfo) : MetaM DeclHtmlInput := do
  let typeText ← ppExprString cinfo.type
  let docString? ← liftM <| findDocString? env decl
  pure {
    moduleName := moduleName
    declName := decl
    kindDescription := kindDescription env decl cinfo
    typeText := typeText
    docString? := docString?
    fields := fieldNames env decl
    constructors := ctorNames cinfo
  }

private def runHighlightedHtml
    (html : Verso.Code.HighlightHtmlM Verso.Genre.Manual DocGenHtml) : DocGenHtml :=
  let ctx : Verso.Code.HighlightHtmlM.Context Verso.Genre.Manual := {
    linkTargets := {}
    traverseContext := { logError := fun _ => pure () }
    definitionIds := {}
    options := {}
  }
  ((html.run ctx).run {}).1

private def highlightedToHtml (h : SubVerso.Highlighting.Highlighted) : DocGenHtml :=
  runHighlightedHtml (h.toHtml (g := Verso.Genre.Manual))

private def signatureToHtml (sig : Verso.Genre.Manual.Signature) : DocGenHtml :=
  runHighlightedHtml sig.toHtml

private def plainDocstringHtml (docs? : Option String) : DocGenHtml :=
  open Verso.Output.Html in
  match docs? with
  | none => .empty
  | some docs =>
    {{<pre class="docstring">{{.text true docs}}</pre>}}

private def kindClassOfDeclType : Verso.Genre.Manual.Block.Docstring.DeclType → String
  | .theorem => "theorem"
  | .axiom _ => "axiom"
  | .opaque _ => "opaque"
  | .def _ => "def"
  | .structure true .. => "class"
  | .structure false .. => "structure"
  | .inductive .. => "inductive"
  | .ctor .. => "constructor"
  | .recursor _ => "recursor"
  | .quotPrim _ => "primitive"
  | .other => "def"

private def kindClassOfKindDescription (kind : String) : String :=
  match kind with
  | "def" | "abbrev" => "def"
  | "theorem" => "theorem"
  | "axiom" => "axiom"
  | "opaque" => "opaque"
  | "class" => "class"
  | "structure" => "structure"
  | "inductive" | "constructor" | "recursor" => "inductive"
  | _ => "def"

private def renderNamedocsWrapper
    (decl : Name) (kindClass : String) (label : String) (signature : DocGenHtml) (body : DocGenHtml) : DocGenHtml :=
  open Verso.Output.Html in
  {{
    <div class={{s!"declaration decl {kindClass}"}} data-decl={{decl.toString}}>
      <div class="namedocs">
        <span class="label">{{.text true label}}</span>
        <pre class="signature hl lean block">{{signature}}</pre>
        <div class="text">{{body}}</div>
      </div>
    </div>
  }}

private def visibilityHtml (v : Verso.Genre.Manual.Block.Docstring.Visibility) : DocGenHtml :=
  open Verso.Output.Html in
  match v with
  | .public => .empty
  | .private => {{<span class="keyword">"private"</span>" "}}
  | .protected => .empty

private def renderDocNameCtor (docName : Verso.Genre.Manual.Block.Docstring.DocName) : DocGenHtml :=
  open Verso.Output.Html in
  {{
    <div class="constructor">
      <pre class="name-and-type hl lean">{{highlightedToHtml docName.signature}}</pre>
      <div class="docs">{{plainDocstringHtml docName.docstring?}}</div>
    </div>
  }}

private def renderFieldSignature (field : Verso.Genre.Manual.Block.Docstring.FieldInfo) : DocGenHtml :=
  open Verso.Output.Html in
  let inheritedInfo : DocGenHtml :=
    if field.fieldFrom.isEmpty then
      .empty
    else
      let inheritedRows : Array DocGenHtml :=
        field.fieldFrom.toArray.map fun parent =>
          {{<li><code>{{.text true parent.name.toString}}</code></li>}}
      {{
        <div class="inheritance docs">
          "Inherited from "
          <ol>{{inheritedRows}}</ol>
        </div>
      }}
  {{
    <section class="subdocs">
      <pre class="name-and-type hl lean">
        {{visibilityHtml field.visibility}}{{highlightedToHtml field.fieldName}} " : " {{highlightedToHtml field.type}}
      </pre>
      {{inheritedInfo}}
      <div class="docs">{{plainDocstringHtml field.docString?}}</div>
    </section>
  }}

private def renderParentsSection
    (parents : Array Verso.Genre.Manual.Block.Docstring.ParentInfo) : Option DocGenHtml :=
  open Verso.Output.Html in
  if parents.isEmpty then
    none
  else
    let rows :=
      parents.map fun parent =>
        {{<li><code class="hl lean inline">{{highlightedToHtml parent.parent}}</code></li>}}
    some {{
      <h1>"Extends"</h1>
      <ul class="extends">{{rows}}</ul>
    }}

private def hasClassAttr (attrs : Array (String × String)) (cls : String) : Bool :=
  attrs.any fun (k, v) => k == "class" && v == cls

private def hasClassWord (attrs : Array (String × String)) (word : String) : Bool :=
  attrs.any fun (k, v) =>
    k == "class" && (v.splitOn " ").any (· == word)

private def dropDocgenHeader
    (children : Array DocGen4.Html) : Array DocGen4.Html :=
  children.filter fun child =>
    match child with
    | .element "div" _ attrs _ => !(hasClassAttr attrs "decl_header")
    | _ => true

private def renderDeclHtmlDocstringFromInfoE
    (_moduleName : Name) (decl : Name) (_cinfo : ConstantInfo) : MetaM DocGenRender :=
  open Verso.Output.Html in do
  let env ← getEnv
  let declType ←
    withOptions (verso.docstring.allowMissing.set · true) <|
      Verso.Genre.Manual.Block.Docstring.DeclType.ofName decl
  let signature ← Verso.Genre.Manual.Signature.forName decl
  let docs? ← liftM <| findDocString? env decl

  let ctorSection? : Option DocGenHtml :=
    match declType with
    | .structure isClass ctor? _ _ _ _ =>
      ctor?.map fun ctor =>
        let title := if isClass then "Instance Constructor" else "Constructor"
        {{
          <h1>{{.text true title}}</h1>
          {{renderDocNameCtor ctor}}
        }}
    | _ => none

  let methodsOrFieldsSection? : Option DocGenHtml :=
    match declType with
    | .structure isClass _ _ fieldInfo _ _ =>
      let rows := fieldInfo.filter (fun f => f.subobject?.isNone) |>.map renderFieldSignature
      if rows.isEmpty then
        none
      else
        let title := if isClass then "Methods" else "Fields"
        some {{
          <h1>{{.text true title}}</h1>
          {{rows}}
        }}
    | _ => none

  let parentsSection? : Option DocGenHtml :=
    match declType with
    | .structure _ _ _ _ parents _ => renderParentsSection parents
    | _ => none

  let inductiveCtorsSection? : Option DocGenHtml :=
    match declType with
    | .inductive ctors _ _ =>
      if ctors.isEmpty then
        none
      else
        let rows := ctors.map renderDocNameCtor
        some {{
          <h1>"Constructors"</h1>
          {{rows}}
        }}
    | _ => none

  let mut sections : Array DocGenHtml := #[]
  if let some s := ctorSection? then
    sections := sections.push s
  if let some s := parentsSection? then
    sections := sections.push s
  if let some s := methodsOrFieldsSection? then
    sections := sections.push s
  if let some s := inductiveCtorsSection? then
    sections := sections.push s

  let label := declType.label
  let label := if label.isEmpty then "declaration" else label
  let kindClass := kindClassOfDeclType declType
  let signatureHtml := signatureToHtml signature

  let body : DocGenHtml :=
    if sections.isEmpty then
      plainDocstringHtml docs?
    else
      {{ {{plainDocstringHtml docs?}} {{sections}} }}
  pure <| .ok <| renderNamedocsWrapper decl kindClass label signatureHtml body

private def renderDeclHtmlDocgenFromInfoE
    (moduleName : Name) (decl : Name) (cinfo : ConstantInfo) : MetaM DocGenRender := do
  let env ← getEnv
  let input ← mkDeclHtmlInput env moduleName decl cinfo
  let kindClass := kindClassOfKindDescription input.kindDescription
  let label := if input.kindDescription.isEmpty then "declaration" else input.kindDescription
  let signature ← Verso.Genre.Manual.Signature.forName decl
  let raw := docInfoToHtml input
  let body : DocGenHtml :=
    match raw with
    | .element "div" _ attrs children =>
      if hasClassWord attrs "declaration" then
        let children := dropDocgenHeader children
        .seq (children.map docgenHtmlToOutputHtml)
      else
        docgenHtmlToOutputHtml raw
    | _ =>
      docgenHtmlToOutputHtml raw
  pure <| .ok <| renderNamedocsWrapper decl kindClass label (signatureToHtml signature) body

/--
Render one declaration directly from known declaration facts.
Errors represent rendering failures only; declaration lookup is handled by callers.
-/
def renderDeclHtmlDirectFromInfoE
    (moduleName : Name) (decl : Name) (cinfo : ConstantInfo) : MetaM DocGenRender := do
  try
    match externalRenderMode (← getOptions) with
    | .docstring => renderDeclHtmlDocstringFromInfoE moduleName decl cinfo
    | .docgen => renderDeclHtmlDocgenFromInfoE moduleName decl cinfo
  catch ex =>
    return .error (.exception decl (← ex.toMessageData.toString))

/--
String compatibility wrapper over `renderDeclHtmlDirectFromInfoE`.
Core external-rendering dataflow should use typed HTML payloads.
-/
def renderDeclHtmlStringDirectFromInfoE
    (moduleName : Name) (decl : Name) (cinfo : ConstantInfo) : MetaM (Except DocGenRenderError String) := do
  return (← renderDeclHtmlDirectFromInfoE moduleName decl cinfo).map (·.asString)

/-- Render one declaration directly from the in-memory `Environment` (no database, no source parsing). -/
def renderDeclHtmlNodeDirect? (decl : Name) : MetaM (Option DocGenHtml) := do
  let decl := decl.eraseMacroScopes
  try
    let env ← getEnv
    let some cinfo := env.find? decl
      | return none
    let some moduleName := moduleNameForDecl? env decl
      | return none
    match ← renderDeclHtmlDirectFromInfoE moduleName decl cinfo with
    | .ok html => return some html
    | .error err =>
      logError m!"DocGen direct rendering failed for {decl}: {err.message}"
      return none
  catch ex =>
    logError m!"DocGen direct rendering failed for {decl}: {← ex.toMessageData.toString}"
    return none

/-- String wrapper over `renderDeclHtmlNodeDirect?`. -/
def renderDeclHtmlStringDirect? (decl : Name) : MetaM (Option String) := do
  match ← renderDeclHtmlNodeDirect? decl with
  | some html => return some html.asString
  | none => return none

/--
Optional fallback path for non-`MetaM` contexts.
With the dependency removed, this currently returns `none`.
-/
def renderDeclHtmlNodeFromDb? (_dbPath : System.FilePath) (_decl : Name) : IO (Option DocGenHtml) := do
  IO.eprintln "[doc-gen db] fallback unavailable: doc-gen4 dependency removed"
  return none

/-- Smoke demo targets: theorem/def (`Nat.add`), structure (`Prod`), and a missing name. -/
def docGenNameRenderSmokeDecls : Array Name := #[`Nat.add, `Prod, `No.Such.Declaration]

/-- Measure textual payload length in rendered declaration HTML. -/
def DocGenHtml.textLength : DocGenHtml → Nat
  | .text _ s => s.length
  | .tag _ _ content => textLength content
  | .seq contents => contents.foldl (fun acc child => acc + textLength child) 0

/-- Smoke demo helper for quick direct-path checks. -/
def runDocGenNameRenderSmokeDirect : MetaM (Array (Name × Option DocGenHtml)) := do
  docGenNameRenderSmokeDecls.mapM fun decl => do
    let rendered? ← renderDeclHtmlNodeDirect? decl
    if let some html := rendered? then
      logInfo m!"[doc-gen direct smoke] {decl}: rendered ({DocGenHtml.textLength html} chars)"
    else
      logInfo m!"[doc-gen direct smoke] {decl}: none"
    pure (decl, rendered?)

end Informal
