/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Renshaw, Jason Reed, Adaptation to Verso by Emilio J. Gallego Arias
-/

import Verso
import VersoManual
import VersoBlueprint
import Bibliography

open Verso.Genre Manual Informal

set_option doc.verso true
set_option pp.rawOnError true
set_option verso.code.warnLineLength 0

#doc (Manual) "Main Theorems" =>

```texPrelude
% These are defined by KaTeX already
% \newcommand{\Q}{\mathbb{Q}}
% \newcommand{\R}{\mathbb{R}}
% \newcommand{\N}{\mathbb{N}}
\newcommand{\PPP}{\mathbf{P}}
\newcommand{\OOO}{\mathbf{O}}
\newcommand{\PP}{\mathcal{P}}
\newcommand{\QQ}{\mathcal{Q}}
\newcommand{\id}{\mathrm{Id}}
\newcommand{\spanp}{\mathrm{span}^+}

\newcommand{\NOP}{\mathbf{NOP}}
\newcommand{\RUP}{\mathbf{RUP}}
\newcommand{\RID}{\mathbf{RID}}

\newcommand{\Circ}{\mathrm{Disc}}
\newcommand{\Sect}{\mathrm{Sect}}

\newcommand{\dd}{\mathrm{d}}

\newcommand{\thetab}{\overline{\theta}}
\newcommand{\phib}{\overline{\varphi}}
\newcommand{\alphab}{\overline{\alpha}}
\newcommand{\Mib}{\overline{M_1}}
\newcommand{\Miib}{\overline{M_2}}
\newcommand{\Xib}{\overline{X_1}}
\newcommand{\Xiib}{\overline{X_2}}

\newcommand{\ssin}{\sin_{\mathbb{Q}}}
\newcommand{\scos}{\cos_{\mathbb{Q}}}
```

:::theorem "thm:no_nopert_tight_pose" (lean := "no_nopert_tight_pose")
Using {uses "def:noperthedron"}[].

There does not in fact exist a noperthedron Rupert solution with

$$`
\begin{align*}
\theta_1,\theta_2&\in[0,2\pi/15] \subset [0,0.42], \\
\varphi_1&\in [0,\pi] \subset [0,3.15],\\
\varphi_2&\in [0,\pi/2] \subset [0,1.58],\\
\alpha &\in [-\pi/2,\pi/2] \subset [-1.58,1.58].
\end{align*}
`
:::

:::proof "thm:no_nopert_tight_pose" (leanok := true)
Using {uses "thm:exists_solution_table"}[] and {uses "thm:row_valid_imp_not_rupert"}[].

By {uses "thm:exists_solution_table"}[this theorem], there is a valid solution table
containing a valid row whose pose interval is a superset of
the 5-dimensional interval above. By {uses "thm:row_valid_imp_not_rupert"}[this theorem],
there is no Rupert solution in that interval.
:::

:::theorem "thm:no_nopert_pose" (lean := "no_nopert_pose")
There is no 5-parameter pose that makes the noperthedron have the Rupert property.
:::

:::proof "thm:no_nopert_pose" (leanok := true)
Using {uses "thm:no_nopert_tight_pose"}[] and {uses "cor:rupert_tightening"}[].

Theorem {uses "thm:no_nopert_tight_pose"}[] rules out tight poses,
and {uses "cor:rupert_tightening"}[] reduces the general case to the tight case.
:::

:::theorem "thm:no_nopert_rot_pose" (lean := "no_nopert_rot_pose")
There is no purely rotational pose that makes the noperthedron have the Rupert property.
:::

:::proof "thm:no_nopert_rot_pose" (leanok := true)
Using {uses "thm:pose_of_matrix_pose"}[] and {uses "thm:no_nopert_pose"}[].

A purely rotational pose can be converted to an equivalent 5-parameter pose
via {uses "thm:pose_of_matrix_pose"}[], which contradicts {uses "thm:no_nopert_pose"}[].
:::

:::theorem "thm:no_nopert_matrix_pose" (lean := "no_nopert_matrix_pose")
There is no pose that makes the noperthedron have the Rupert property.
:::

:::proof "thm:no_nopert_matrix_pose" (leanok := true)
Using {uses "lemma:nopert_point_symmetric"}[], {uses "thm:no_nopert_rot_pose"}[], and {uses "thm:rupert_implies_rot_rupert"}[].

By {uses "thm:rupert_implies_rot_rupert"}[], it is enough to show point symmetry.
By {uses "lemma:nopert_point_symmetric"}[], the noperthedron is point symmetric.
This would force a purely rotational Rupert pose, contradicting {uses "thm:no_nopert_rot_pose"}[].
:::

:::theorem "thm:nopert_not_rupert_set" (lean := "nopert_not_rupert_set")
Using {uses "def:noperthedron"}[].

The noperthedron is not a Rupert set.
:::

:::proof "thm:nopert_not_rupert_set" (leanok := true)
Using {uses "thm:no_nopert_matrix_pose"}[].
By {uses "thm:no_nopert_matrix_pose"}[this theorem], no pose makes the noperthedron Rupert.
:::

:::theorem "thm:nopert_not_rupert" (lean := "nopert_not_rupert")
The noperthedron is not a Rupert polyhedron.
:::

:::proof "thm:nopert_not_rupert" (leanok := true)
Using {uses "thm:rupert_iff_rupert_set"}[] and {uses "thm:nopert_not_rupert_set"}[].

By {uses "thm:rupert_iff_rupert_set"}[], it suffices to show that the convex hull of
noperthedron vertices is not a Rupert set, which is exactly
{uses "thm:nopert_not_rupert_set"}[the previous theorem].
:::
