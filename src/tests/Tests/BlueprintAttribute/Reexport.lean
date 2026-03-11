/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintAttribute.Provider

namespace Verso.Tests.BlueprintAttribute.Reexport

def importedValue : Nat := Verso.Tests.BlueprintAttribute.Provider.exportedDefinition

end Verso.Tests.BlueprintAttribute.Reexport
