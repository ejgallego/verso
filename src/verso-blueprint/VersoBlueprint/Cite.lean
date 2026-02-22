/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import VersoManual.Bibliography
import VersoBlueprint.Resolve

open Lean Elab Command
open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse

namespace Informal.Cite

open Verso.Genre.Manual.Bibliography

syntax (name := bib) "bib" ppSpace str : attr

private def parseBibLabel (s : String) : Name :=
  let parts :=
    s.splitOn "."
    |>.map (fun p => p.trimAscii.toString)
    |>.filter (fun p => !p.isEmpty)
  if parts.isEmpty then
    Name.mkSimple s.trimAscii.toString
  else
    parts.foldl (init := Name.anonymous) Name.str

def normalizeLabel (label : String) : String :=
  (parseBibLabel label).toString

def citationAnchorId (label : String) : String :=
  let base := normalizeLabel label
  base.foldl (init := "") fun acc c =>
    if c.isAlphanum then
      acc.push c.toLower
    else
      acc.push '-'

initialize bibExt : PersistentEnvExtension (Name × Name) (Name × Name) (Lean.NameMap Name) ←
  registerPersistentEnvExtension {
    mkInitial := pure {}
    addImportedFn := fun es => do
      let out := es.foldl (init := ({} : Lean.NameMap Name)) fun acc entry =>
        entry.foldl (init := acc) fun acc (label, decl) =>
          acc.insert label decl
      pure out
    addEntryFn := fun st (label, decl) =>
      st.insert label decl
    exportEntriesFn := fun st =>
      st.toArray
  }

def lookupDecl? (env : Environment) (label : String) : Option Name :=
  let key := parseBibLabel label
  (bibExt.getState env).find? key

def allBibEntries (env : Environment) : List (String × Name) :=
  let entries : Array (String × Name) :=
    (bibExt.getState env).toArray.map fun (label, decl) => (label.toString, decl)
  let entries := Array.qsort entries (fun a b => a.1 < b.1)
  Array.toList entries

private def labelFromAttr (stx : Syntax) : CoreM Name := do
  match stx with
  | `(attr| bib $lbl:str) => pure (parseBibLabel lbl.getString)
  | _ => throwError "invalid syntax for '[bib]' attribute"

open Lean in
initialize
  registerBuiltinAttribute {
    name := `bib
    ref := by exact decl_name%
    applicationTime := .afterCompilation
    add := fun decl stx kind => do
      unless kind == AttributeKind.global do
        throwError "invalid attribute '[bib]', must be global"
      unless ((← getEnv).getModuleIdxFor? decl).isNone do
        throwError "invalid attribute '[bib]', declaration is in an imported module"
      let label ← labelFromAttr stx
      let decl := decl.eraseMacroScopes
      let prev? := (bibExt.getState (← getEnv)).find? label
      if let some prev := prev? then
        unless prev == decl do
          throwError "duplicate '[bib]' label '{label}': already assigned to '{prev}'"
      modifyEnv fun env =>
        bibExt.addEntry env (label, decl)
    descr := "Registers a Citable declaration with a bibliography label for Informal citation roles"
  }

inductive CitePartKind where
  | chapter
  | section
  | theorem
  | lemma
  | corollary
  | page
  | equation
  | figure
deriving Inhabited, Repr, BEq, FromJson, ToJson, Quote

def CitePartKind.parse? (s : String) : Option CitePartKind :=
  match s.trimAscii.toString.toLower with
  | "chapter" | "ch" => some .chapter
  | "section" | "sec" => some .section
  | "theorem" | "thm" => some .theorem
  | "lemma" | "lem" => some .lemma
  | "corollary" | "cor" => some .corollary
  | "page" | "p" | "pp" => some .page
  | "equation" | "eq" => some .equation
  | "figure" | "fig" => some .figure
  | _ => none

def CitePartKind.text : CitePartKind → String
  | .chapter => "Chapter"
  | .section => "Section"
  | .theorem => "Theorem"
  | .lemma => "Lemma"
  | .corollary => "Corollary"
  | .page => "p."
  | .equation => "Equation"
  | .figure => "Figure"

structure CiteConfig where
  citations : List (Verso.ArgParse.WithSyntax String)
  kind : Option CitePartKind := none
  index : Option String := none

section
variable [Monad m] [MonadInfoTree m] [MonadLiftT CoreM m] [MonadEnv m] [MonadError m] [MonadFileMap m]

private def stringOrName : ValDesc m String := {
  description := "citation label (identifier or string)"
  signature := .String ∪ .Ident
  get := fun
    | .str s => pure s.getString
    | .name n => pure n.getId.toString
    | other => throwError "Expected citation label, got {toMessageData other}"
}

private def citePartKind : ValDesc m CitePartKind := {
  description := "citation sub-part kind (`lemma`, `section`, `theorem`, ...)"
  signature := .String ∪ .Ident
  get := fun
    | .name n =>
      let key := n.getId.toString
      match CitePartKind.parse? key with
      | some kind => pure kind
      | none => throwError "Unknown citation kind '{key}'"
    | .str s =>
      let key := s.getString
      match CitePartKind.parse? key with
      | some kind => pure kind
      | none => throwError "Unknown citation kind '{key}'"
    | other => throwError "Expected citation kind, got {toMessageData other}"
}

private def citePartIndex : ValDesc m String := {
  description := "citation sub-part index (`8`, `4.2`, ...)"
  signature := .Num ∪ .String ∪ .Ident
  get := fun
    | .num n => pure (toString n.getNat)
    | .str s => pure s.getString
    | .name n => pure n.getId.toString
}

partial def CiteConfig.parse : ArgParse m CiteConfig :=
  CiteConfig.mk
    <$> many1 (.positional `citation (.withSyntax stringOrName))
    <*> .named `kind citePartKind true
    <*> .named `index citePartIndex true
where
  many1 p := (· :: ·) <$> p <*> .many p

instance : FromArgs CiteConfig m where
  fromArgs := CiteConfig.parse

end

private def fallbackDecl? (env : Environment) (label : String) : Option Name :=
  let n := parseBibLabel label
  if env.find? n |>.isSome then some n else none

def resolveCitation (stx : Syntax) (label : String) : DocElabM (String × Name) := do
  let env ← getEnv
  if let some decl := lookupDecl? env label then
    return (normalizeLabel label, decl)
  if let some decl := fallbackDecl? env label then
    return (normalizeLabel label, decl)
  throwErrorAt stx "Unknown bibliography label '{label}'"

inductive CitationStyle where
  | textual
  | parenthetical
  | here
deriving Inhabited, Repr, BEq, FromJson, ToJson, Quote

structure CiteItem where
  label : String
  citation : Citable
deriving FromJson, ToJson

structure CiteInlineData where
  citations : List CiteItem := []
  style : CitationStyle := .parenthetical
  kind : Option CitePartKind := none
  index : Option String := none
deriving Inhabited, FromJson, ToJson

private partial def inlineToPlain : Doc.Inline Manual → String
  | .text s | .code s | .math _ s => s
  | .bold xs | .emph xs | .concat xs | .other _ xs | .link xs _ =>
    xs.toList.foldl (init := "") fun acc x => acc ++ inlineToPlain x
  | .linebreak .. => " "
  | .footnote _ xs => xs.toList.foldl (init := "") fun acc x => acc ++ inlineToPlain x
  | .image alt _ => alt

private def authorText (c : Citable) : String :=
  let last (x : Doc.Inline Manual) := inlineToPlain (Bibliography.lastName x)
  match c.authors.toList with
  | [] => "?"
  | [a] => last a
  | [a, b] => s!"{last a} and {last b}"
  | a :: _ => s!"{last a} et al."

private def joinHtml (sep : Verso.Output.Html) (xs : List Verso.Output.Html) : Verso.Output.Html :=
  match xs with
  | [] => .empty
  | x :: rest => rest.foldl (init := x) fun acc y => acc ++ sep ++ y

private def locatorText (kind : Option CitePartKind) (index : Option String) : Option String :=
  let index := index.map (·.trimAscii.toString)
  match kind, index with
  | Option.none, Option.none => Option.none
  | some k, Option.none => some k.text
  | Option.none, some i =>
    if i.isEmpty then Option.none else some i
  | some k, some i =>
    if i.isEmpty then
      some k.text
    else
      some s!"{k.text} {i}"

private def pieceText (style : CitationStyle) (c : Citable) : String :=
  let who := authorText c
  let year := c.year
  match style with
  | .textual => s!"{who} ({year})"
  | .parenthetical | .here => s!"{who}, {year}"

open Verso Doc Elab Genre Manual in
inline_extension Inline.bpCite (citations : List CiteItem) (style : CitationStyle := .parenthetical)
    (kind : Option CitePartKind := none) (index : Option String := none) where
  data := toJson ({ citations, style, kind, index } : CiteInlineData)
  traverse id data _contents := do
    let .ok cfg := fromJson? (α := CiteInlineData) data
      | logError "Malformed data in Inline.bpCite.traverse"
        return none
    let path ← (·.path) <$> read
    let tagBase :=
      match cfg.citations with
      | [] => "--bp-cite"
      | first :: _ => s!"--bp-cite-{citationAnchorId first.label}"
    let _ ← Verso.Genre.Manual.externalTag id path tagBase
    for item in cfg.citations do
      modify fun st =>
        st.saveDomainObject Resolve.citationUsageDomainName item.label id
    pure none
  toTeX :=
    open Verso.Output.TeX in
    some <| fun go _id data content => do
      let .ok cfg := fromJson? (α := CiteInlineData) data
        | TeX.logError "Malformed data in Inline.bpCite.toTeX"
          pure .empty
      let pieces := cfg.citations.map (fun item => pieceText cfg.style item.citation)
      let body := String.intercalate "; " pieces
      let loc? := locatorText cfg.kind cfg.index
      let textNote? ←
        if content.isEmpty then
          pure (Option.none : Option _)
        else
          some <$> content.mapM go
      let txt :=
        match cfg.style with
        | .parenthetical =>
          let core := match loc? with
            | Option.none => body
            | some loc => s!"{body}, {loc}"
          match textNote? with
          | Option.none => .raw s!"({core})"
          | some textNote => .raw s!"({core}, " ++ textNote ++ .raw ")"
        | .textual | .here =>
          let core := match loc? with
            | Option.none => body
            | some loc => s!"{body}, {loc}"
          match textNote? with
          | Option.none => .raw core
          | some textNote => .raw core ++ .raw ", " ++ textNote
      pure txt
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun goI id data content => do
      let .ok cfg := fromJson? (α := CiteInlineData) data
        | HtmlT.logError "Malformed data in Inline.bpCite.toHtml"
          pure .empty
      let st ← HtmlT.state
      let citeAnchorId? := st.externalTags[id]? |>.map (·.htmlId.toString)
      let wrapTarget (h : Output.Html) : Output.Html :=
        match citeAnchorId? with
        | some anchorId => {{<span id={{anchorId}}>{{h}}</span>}}
        | Option.none => h
      let mkLink (item : CiteItem) : Output.Html :=
        let base? :=
          match Resolve.resolveDomainHref? st Verso.Genre.Manual.sectionDomain "Contents--Blueprint-Bibliography" with
          | some href => some href
          | Option.none =>
            Resolve.resolveDomainHref? st Resolve.bibliographyDomainName item.label
        let href? := base?.map (fun href =>
          let cleanBase :=
            match href.splitOn "#" with
            | [] => href
            | first :: _ => first
          s!"{cleanBase}#bp-bib-{citationAnchorId item.label}")
        let txt := pieceText cfg.style item.citation
        match href? with
        | some href => {{<a href={{href}}>{{.text true txt}}</a>}}
        | Option.none => {{<span>{{.text true txt}}</span>}}
      let body := joinHtml {{<span>"; "</span>}} (cfg.citations.map mkLink)
      let locatorHtml? := (locatorText cfg.kind cfg.index).map (fun loc => {{<span>{{.text true loc}}</span>}})
      let htmlNote? : Option Html ←
        if content.isEmpty then
          pure Option.none
        else
          some <$> content.mapM goI
      match cfg.style with
      | .parenthetical =>
        let core :=
          match locatorHtml? with
          | Option.none => body
          | some loc => {{<span>{{body}} ", " {{loc}}</span>}}
        match htmlNote? with
        | Option.none => pure <| wrapTarget {{<span>"(" {{core}} ")"</span>}}
        | some htmlNote => pure <| wrapTarget {{<span>"(" {{core}} ", " {{htmlNote}} ")"</span>}}
      | .textual | .here =>
        let core :=
          match locatorHtml? with
          | Option.none => body
          | some loc => {{<span>{{body}} ", " {{loc}}</span>}}
        match htmlNote? with
        | Option.none => pure <| wrapTarget core
        | some htmlNote => pure <| wrapTarget {{<span>{{core}} ", " {{htmlNote}}</span>}}

end Informal.Cite

namespace Informal

open Verso.Genre.Manual.Bibliography

private def mkItems (config : Cite.CiteConfig) : DocElabM (Array (TSyntax `term)) := do
  let citations ← config.citations.mapM (fun c => Cite.resolveCitation c.syntax c.val)
  citations.toArray.mapM fun (label, decl) =>
    `(Informal.Cite.CiteItem.mk $(quote label) $(mkIdent decl))

@[role]
def citep : RoleExpanderOf Cite.CiteConfig
  | config, extra => do
    let items ← mkItems config
    ``(Verso.Doc.Inline.other
      (Informal.Cite.Inline.bpCite
        ([$items,*] : List Informal.Cite.CiteItem)
        Informal.Cite.CitationStyle.parenthetical
        $(quote config.kind)
        $(quote config.index))
      #[$(← extra.mapM elabInline),*])

@[role]
def citet : RoleExpanderOf Cite.CiteConfig
  | config, extra => do
    let items ← mkItems config
    ``(Verso.Doc.Inline.other
      (Informal.Cite.Inline.bpCite
        ([$items,*] : List Informal.Cite.CiteItem)
        Informal.Cite.CitationStyle.textual
        $(quote config.kind)
        $(quote config.index))
      #[$(← extra.mapM elabInline),*])

@[role]
def citehere : RoleExpanderOf Cite.CiteConfig
  | config, extra => do
    let items ← mkItems config
    ``(Verso.Doc.Inline.other
      (Informal.Cite.Inline.bpCite
        ([$items,*] : List Informal.Cite.CiteItem)
        Informal.Cite.CitationStyle.here
        $(quote config.kind)
        $(quote config.index))
      #[$(← extra.mapM elabInline),*])

end Informal
