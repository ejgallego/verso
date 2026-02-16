/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Renshaw, Jason Reed, Adaptation to Verso by Emilio J. Gallego Arias
-/

import Verso
import VersoManual
import VersoBlueprint

open Verso.Genre Manual Informal

-- EJGA: Seems like a good idea for hybrid setups
set_option doc.verso true

set_option pp.rawOnError true

#doc (Manual) "Preliminaries" =>

TODO: This whole chapter needs organization, it's just a grab bag of miscellaneous results for now.

# Rupert Sets

:::theorem "thm:rupert_iff_rupert_set" (lean := "rupert_iff_rupert_set")
The following are equivalent:
- The convex polyhedron with vertex set $`v` is Rupert.
- The convex closure of $`v` is a Rupert set.
:::

:::proof "thm:rupert_iff_rupert_set"
TODO: import this from the other repo
:::

# Poses

TODO

:::theorem "thm:pose_of_matrix_pose" (lean := "pose_of_matrix_pose,converted_pose_rupert_iff")
Given a pose with zero offset, there exists a 5-parameter pose that is equivalent to it.
:::

:::proof "thm:pose_of_matrix_pose"
By putting the pose into a canonical form as a Z rotation followed by a Y followed by a Z.
:::

# Pointsymmetry and Rupertness

:::theorem "thm:rupert_implies_rot_rupert" (lean := "rupert_implies_rot_rupert")
If a set is point symmetric and convex, then it being Rupert implies
it being purely rotationally Rupert.
:::

:::proof "thm:rupert_implies_rot_rupert"
TODO: informalize proof
:::

:::theorem "thm:polyhedron_radius_iff" (lean := "polyhedron_radius_iff")
Suppose $`S` is a finite set of points in $`\mathbb{R}^n`.
The radius of the polyhedron $`S` is $`r` iff:
- there is a vector $`v \in S` with $`\|v\| = r`
- all vectors $`v \in S` have $`\|v\| \le r`
:::

:::proof "thm:polyhedron_radius_iff"
Immediate from definition.
:::

:::theorem "thm:pointsymmetrize_pres_radius" (lean := "pointsymmetrize_pres_radius")
Pointsymmetrization preserves radius.
:::

:::proof "thm:pointsymmetrize_pres_radius"
Using {uses "thm:polyhedron_radius_iff"}[].
Because the reflection of a point about the origin preserves its norm.
:::
