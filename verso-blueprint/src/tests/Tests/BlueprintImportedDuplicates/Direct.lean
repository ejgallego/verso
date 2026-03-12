/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintImportedDuplicates.ProviderA
import Tests.BlueprintImportedDuplicates.ProviderB
import VersoBlueprint
import VersoManual

open Lean
open Informal
open Verso
open Verso.Genre.Manual

set_option doc.verso true

namespace Verso.Tests.BlueprintImportedDuplicates.Direct

/--
error: Duplicate imported blueprint node label '«dup.imported.node»'
---
error: Duplicate imported blueprint group label '«dup.imported.group»'
---
error: Duplicate imported blueprint author id '«dup.imported.author»'
---
info: Blueprint summary for 1 entries
-/
#guard_msgs in
#docs (Genre.Manual) directImportedDuplicateDoc "Direct Imported Duplicates" :=
:::::::
{bp_summary}
:::::::

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let conflicts ← Informal.Environment.importedConflicts
    pure <|
      conflicts.contains { kind := .node, label := Name.mkSimple "dup.imported.node" } &&
      conflicts.contains { kind := .group, label := Name.mkSimple "dup.imported.group" } &&
      conflicts.contains { kind := .author, label := Name.mkSimple "dup.imported.author" }

end Verso.Tests.BlueprintImportedDuplicates.Direct
