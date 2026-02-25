/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import VersoManual

namespace Informal.Resolve

open Lean

def informalDomainName : Name := Name.mkSimple "Informal.Block.informal"
def informalCodeDomainName : Name := Name.mkSimple "Informal.Block.informalCode"
def informalPreviewDomainName : Name := Name.mkSimple "Informal.Block.informalPreview"
def bibliographyDomainName : Name := Name.mkSimple "Informal.Block.bpCitations"
def citationUsageDomainName : Name := Name.mkSimple "Informal.Inline.bpCite.usages"
def exampleDomainName : Name := ``Verso.Genre.Manual.example

def resolveDomainHref? (s : Verso.Genre.Manual.TraverseState) (domain : Name) (label : String) :
    Option String :=
  match s.resolveDomainObject domain label with
  | .ok dest => some dest.relativeLink
  | .error _ => none

def resolveDomainHrefs (s : Verso.Genre.Manual.TraverseState) (domain : Name) (label : String) :
    Array String :=
  match s.getDomainObject? domain label with
  | none => #[]
  | some obj =>
    let hrefs := obj.ids.toArray.filterMap fun id =>
      (s.externalTags[id]?).map (·.relativeLink)
    hrefs.qsort (fun a b => a < b)

def resolveExampleDeclHref? (s : Verso.Genre.Manual.TraverseState) (decl : Name) : Option String :=
  match resolveDomainHref? s exampleDomainName decl.toString with
  | some href => some href
  | none =>
    match s.domains.get? exampleDomainName with
    | none => none
    | some dom =>
      let pref := decl.toString ++ " (in "
      let cands := dom.objects.foldl (init := #[]) fun acc key _obj =>
        if key == decl.toString || key.startsWith pref then
          acc.push key
        else
          acc
      if cands.size = 1 then
        resolveDomainHref? s exampleDomainName cands[0]!
      else
        none

end Informal.Resolve
