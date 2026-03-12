/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import VersoBlueprint

namespace Verso.Tests.BlueprintAttribute.Provider

/-- Exported theorem used to verify `@[blueprint]` persistence across imports. -/
@[blueprint "attr.exported.theorem"]
theorem exportedTheorem : True := by
  trivial

/-- Exported definition used to verify `@[blueprint]` persistence across imports. -/
@[blueprint "attr.exported.definition"]
def exportedDefinition : Nat := 7

@[blueprint "attr.exported.undocumented"]
def exportedUndocumentedDefinition : Nat := 11

end Verso.Tests.BlueprintAttribute.Provider
