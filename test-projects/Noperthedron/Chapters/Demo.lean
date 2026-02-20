/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Renshaw, Jason Reed, Adaptation to Verso by Emilio J. Gallego Arias
-/

import Verso
import VersoManual
import VersoBlueprint
import VersoBlueprint.Commands
import VersoBlueprint.Widget

-- FIXME: This should happen in a special verso code block
import Noperthedron.Basic
import Noperthedron.Bounding
import Noperthedron.PointSym
import Bibliography

--set_option trace.Elab.info true

open Verso.Genre Manual Informal

/-- hey -/
@[blueprint "l3b"] def l3b := 3

@[blueprint "l3"] def l3 := l3b

@[blueprint "l2a"] def l2a := 2

@[blueprint "l2"] def l2 := l2a

@[blueprint "l1c"] def l1c := 1

@[blueprint "l1b"] def l1b := l2

@[blueprint "l1a"] def l1a := (l1b, l1c)

@[blueprint "l1"] def l1 := l1a

-- EJGA: Seems like a good idea for hybrid setups
set_option doc.verso true

/-- hey -/
@[blueprint "l3c"] def l3db := 3

set_option pp.rawOnError true

set_option verso.blueprint.foldProofs false

-- set_option trace.Elab.info true

/-- This is some verso -/
@[blueprint "test"] def a := 3

@[blueprint "t1_aux"]
theorem t1_aux : True := by sorry


-- No warnings for line length (warning more globally?)
-- Look at ref manual, global options
set_option verso.code.warnLineLength 0

/-- Example of a Lean-only blueprint node registered via the attribute. -/
@[blueprint "example:lean_only_node"] def blueprintLeanOnlyNodeExample : Nat := 42

#doc (Manual) "Demo" =>

:::proof "l3c"

:::

:::theorem "t1"
Hello some math {uses "t1_aux"}[]
:::
:::proof "t1"
this is a proof
:::



```lean "t1"
theorem t1 : True := by exact t1_aux
```

:::theorem "t2"
{uses "t1"}[]
:::
