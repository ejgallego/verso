/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintImportedDuplicates.ProviderA
import Tests.BlueprintImportedDuplicates.ProviderB

namespace Verso.Tests.BlueprintImportedDuplicates.Reexport

def importedValue : Nat :=
  Verso.Tests.BlueprintImportedDuplicates.ProviderA.importedNodeA +
  Verso.Tests.BlueprintImportedDuplicates.ProviderB.importedNodeB

end Verso.Tests.BlueprintImportedDuplicates.Reexport
