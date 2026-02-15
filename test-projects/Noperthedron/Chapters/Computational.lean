/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Renshaw, Jason Reed, Adaptation to Verso by Emilio J. Gallego Arias
-/

import Verso
import VersoManual
import VersoBlueprint

open Verso.Genre Manual

/-

TODO:

Blocks:

:::prelude

:::theorem
   :::proof (nested)

:::definition

Roles:

{uses } / {ref }

-/

-- EJGA: Seems like a good idea for hybrid setups
set_option doc.verso true

set_option pp.rawOnError true

#doc (Manual) "Noperthedron" =>

# Main Theorems

-- Infer automatically
:::theorem "no_nopert_tight_view_pose"

There does not in fact exist a `{ref "noperthedron"}[noperthedron]` Rupert solution with

$$`
\begin{align*}
\theta_1,\theta_2&\in[0,2\pi/15] \subset [0,0.42], \\
\varphi_1&\in [0,\pi] \subset [0,3.15],\\
\varphi_2&\in [0,\pi/2] \subset [0,1.58],\\
\alpha &\in [-\pi/2,\pi/2] \subset [-1.58,1.58].
\end{align*}
`
:::

:::proof "no_nopert_tight_view_pose"

`{uses "thm:exists_solution_table" "thm:row_valid_imp_not_rupert"}[`todo`]`

By `{ref "thm:exists_solution_table"}[todo]`, there is a valid solution table
containing a valid row whose pose interval is a superset of
the 5-d interval above. By `{ref "thm:row_valid_imp_not_rupert"}[todo]`, this means
there is no Rupert solution in that interval.
:::

- Big string literal

```lean "no_nopert_tight_view_pose"
-- Insert code for formal version of the proof above.
-- Challenge, how to separate the proof and statement of the theorem!
def a := 3

#eval a
```
