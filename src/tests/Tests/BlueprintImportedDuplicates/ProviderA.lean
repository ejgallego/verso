/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import VersoBlueprint
import VersoManual

open Verso.Genre
open Verso.Genre.Manual
open Informal

set_option doc.verso true

namespace Verso.Tests.BlueprintImportedDuplicates.ProviderA

@[blueprint "dup.imported.node"]
def importedNodeA : Nat := 1

#docs (Manual) importedDuplicatesProviderA "Imported Duplicates Provider A" :=
:::::::
:::group "dup.imported.group"
Imported group from provider A.
:::

:::author "dup.imported.author" (name := "Imported Author A")
:::
:::::::

end Verso.Tests.BlueprintImportedDuplicates.ProviderA
