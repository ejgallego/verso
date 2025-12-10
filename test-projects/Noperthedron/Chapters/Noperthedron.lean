/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Renshaw, Jason Reed, Adaptation to Verso by Emilio J. Gallego Arias
-/

import Verso
import VersoManual
import VersoBlueprint
import VersoBlueprint.Commands
import VersoBlueprint.GraphViz

-- FIXME: This should happen in a special verso code block
import Noperthedron.Basic
import Noperthedron.Util
import Noperthedron.Bounding

open Verso.Genre Manual Informal

-- EJGA: Seems like a good idea for hybrid setups
set_option doc.verso true

set_option pp.rawOnError true

-- set_option trace.Elab.info true

-- No warnings for line length (warning more globally?)
-- Look at ref manual, global options
set_option verso.code.warnLineLength 0

#doc (Manual) "The Noperthedron" =>

```lean
open scoped Matrix

namespace Nopert

open Real
```

# Definition of the Noperthedron

:::definition (label := "")
We define three points $`C_1,C_2,C_3\in \mathbb{Q}^3`.
$$`
    C_1\coloneqq
        \frac{1}{259375205}
        \begin{pmatrix}
        {152024884} \\ 0 \\ {210152163}
        \end{pmatrix},
\qquad
    C_2\coloneqq \frac{1}{10^{10}}
        \begin{pmatrix}
        6632738028 \\ 6106948881 \\ 3980949609
        \end{pmatrix},
`
$$`
    C_3\coloneqq
        \frac{1}{10^{10}}
        \begin{pmatrix}
        8193990033 \\ 5298215096 \\ 1230614493
        \end{pmatrix}.
`
:::

```lean
def C1 : Fin 3 → ℚ := (1/259375205) * ![152024884, 0, 210152163]
def C2 : Fin 3 → ℚ := (1/10^10) * ![6632738028, 6106948881, 3980949609]
def C3 : Fin 3 → ℚ := (1/10^10) * ![8193990033, 5298215096, 1230614493]

noncomputable
def C1R : EuclideanSpace ℝ (Fin 3) := WithLp.toLp 2 (fun i => C1 i)

noncomputable
def C2R : EuclideanSpace ℝ (Fin 3) := WithLp.toLp 2 (fun i => C2 i)

noncomputable
def C3R : EuclideanSpace ℝ (Fin 3) := WithLp.toLp 2 (fun i => C3 i)
```

:::theorem (label := "c1_c2_c3_norms")

`\lean{Nopert.c1_norm_one, Nopert.c2_norm_bound, Nopert.c3_norm_bound, Nopert.C15}`

$`\| C_1 \| = 1`,
$`{98 \over 100} < \| C_2 \| < {99 \over 100}`, and
$`{98 \over 100} < \| C_3 \| < {99 \over 100}`.
:::

:::proof (label := "c1_c2_c3_norms")
Trivial arithmetic.
:::

```lean (label := "c1_c2_c3_norms")
theorem c2_norm_bound : ‖C2R‖ ∈ Set.Ioo (98/100) (99/100) := by
  rw [EuclideanSpace.norm_eq]
  constructor
  · refine lt_sqrt_of_sq_lt ?_
    simp only [Real.norm_eq_abs, sq_abs]
    unfold C2R C2
    simp only [Fin.sum_univ_three, Pi.mul_apply, Matrix.cons_val]
    norm_num
  · refine (sqrt_lt' (by norm_num)).mpr ?_
    simp only [Real.norm_eq_abs, sq_abs]
    unfold C2R C2
    simp only [Fin.sum_univ_three, Pi.mul_apply, Matrix.cons_val]
    norm_num

theorem c2_norm_le_one : ‖C2R‖ ≤ 1 := by
  grw [c2_norm_bound.2]
  norm_num

theorem c3_norm_bound : ‖C3R‖ ∈ Set.Ioo (98/100) (99/100) := by
  rw [EuclideanSpace.norm_eq]
  constructor
  · sorry
  · refine (sqrt_lt' (by norm_num)).mpr ?_
    simp only [Real.norm_eq_abs, sq_abs]
    unfold C3R C3
    simp only [Fin.sum_univ_three, Pi.mul_apply, Matrix.cons_val]
    norm_num

-- deps for c3_norm_bound:
--   { EuclideanSpace.norm_eq, lt_sqrt_of_sq_lt, Real.norm_eq_abs, C3R, C3,  }
-- deps we know: { }

theorem c3_norm_le_one : ‖C3R‖ ≤ 1 := by
  grw [c3_norm_bound.2]
  norm_num

/-- This is half of the C30 defined in \[SY25\]. In order
to see that this is pointsymmetric, it's convenient to
do explicit pointsymmetrization later. -/
noncomputable
def C15 (pt : ℝ³) : Finset ℝ³ :=
  Finset.range 15 |> .image fun (k : ℕ)  =>
    RzL (2 * π * (k : ℝ) / 15) pt
```

:::theorem (label := "lem:radius_noperthedron_one")
`\lean{Nopert.noperthedron_radius_one}`
The radius of the Noperthedron is one.
:::

:::proof (label := "lem:radius_noperthedron_one")

By {uses (label := "c1_c2_c3_norms")}[the definition of C-norms], we can ....

`\uses{c1_c2_c3_norms, thm:pointsymmetrize_pres_radius, thm:polyhedron_radius_def, lemma:half_nopert_verts_norm_le_one}`

By `\cref{c1_c2_c3_norms}`, `\cref{thm:pointsymmetrize_pres_radius}`, `\cref{thm:polyhedron_radius_def}`,
and `\cref{lemma:half_nopert_verts_norm_le_one}`.
:::

Rotations about the $`x, y, z` axes $`R_x,R_y,R_z:`  $`\mathbb{R}\to \mathbb{R}^{3\times 3}`
are defined in the usual way:
$$`
      R_x(\alpha)\coloneqq
        \begin{pmatrix}
            1 & 0 & 0\\
            0 & \cos\alpha & -\sin\alpha\\
            0 & \sin\alpha & \cos\alpha
        \end{pmatrix},
        \hspace{1cm}
        R_y(\alpha)\coloneqq
        \begin{pmatrix}
            \cos\alpha & 0 & -\sin\alpha\\
            0 & 1 & 0\\
            \sin\alpha & 0 & \cos\alpha
        \end{pmatrix},
`
$$`
        R_z(\alpha)\coloneqq
        \begin{pmatrix}
            \cos\alpha & -\sin\alpha &0\\
            \sin\alpha & \cos\alpha &0\\
            0 & 0 & 1
        \end{pmatrix}.
`

Where Steininger and Yurkevich define a 30-element set $`C_{30}`:

$$`
    \mathcal{C}_{30} \coloneqq \left\{(-1)^\ell R_z\left(\frac{2\pi k}{15}\right) \colon k=0,\dots,14; \ell=0,1\right\}.
`
of rotations, we instead define

:::definition (label := "def:C15")
  `\lean{Nopert.C15}`

$$`
    \mathcal{C}_{15} \coloneqq \left\{ R_z\left(\frac{2\pi k}{15}\right) \colon k=0,\dots,14 \right\}.
`
:::

without point-symmetricness "baked in" as it is in $`C_{30}`. It's more convenient for the formalization to apply $`C_{15}` to the points $`C_1, C_2, C_3`, and then point-symmetrize that set afterwards.

:::definition (label := "def:pointsymmetric")

`\lean{PointSym}`
A set $`S \subseteq \R^3` is `{\em point-symmetric}` if $`x \in S` implies $`-x \in S`.
:::

:::definition (label := "def:pointsymmetrize")
  `\lean{pointsymmetrize}`

The _pointsymmetrization_ of a collection of vertices $`v_1, \ldots, v_n \in \R^3`
is $`v_1, \ldots, v_n, -v_1, \ldots, -v_n`.
:::

We write $`\mathcal{C}_{15} \cdot P = \{c P \,\text{ for } \, c \in \mathcal{C}_{15}\}` for the orbit of $`P` under the action of $`\mathcal{C}_{15}`.

:::definition (label := "def:noperthedron")

`\lean{halfNopertVerts, nopertVerts, nopert}`
`\uses{def:pointsymmetrize,def:C15}`

The Noperthedron is polyhedron given by the vertex set that is the
pointsymmetrization of
$$`
\mathcal{C}_{15} \cdot C_1 \cup \mathcal{C}_{15} \cdot C_2 \cup \mathcal{C}_{15} \cdot C_3
`
:::

:::theorem (label := "half_nopert_verts_norm_le_one")
  `\lean{half_nopert_verts_norm_le_one}`
The norm of any vertex in the prepointsymmetrized version of the Noperthedron is no more than 1.
:::

:::proof (label := "half_nopert_verts_norm_le_one")
Evident from definitions.
:::

:::theorem (label := "lemma:pointsymmetrization_is_pointsym")
`\lean{pointsymmetrize_is_pointsym}`
The pointsymmetrization of any set is point-symmetric.
:::

:::proof (label := "lemma:pointsymmetrization_is_pointsym")
Evident from definitions.
:::

:::theorem (label := "lemma:nopert_point_symmetric")
  `\lean{nopert_point_symmetric}`
  `\uses{def:pointsymmetric, def:noperthedron}`
The noperthedron is point-symmetric.
:::

:::proof (label := "lemma:nopert_point_symmetric")
Follows from Lemma~{uses (label := "lemma:pointsymmetrization_is_pointsym")}[]
:::

# Refined Rupert's property for the Noperthedron

:::theorem (label := "lem:symmetries")
`\lean{Tightening.lemma7_1,Tightening.lemma7_2,Tightening.lemma7_3}`

Let $`\PPP = \NOP`, then for all $`\theta, \varphi, \alpha \in \R`, the following three identities hold (as sets):

$$`
\begin{align*}
    M({\theta+2\pi/15,\varphi})\cdot \PPP &=M(\theta, \phi) \cdot \PPP,\\
    R(\alpha+\pi)M(\theta, \phi) \cdot \PPP &=R(\alpha)M(\theta, \phi) \cdot \PPP,\\
    \begin{pmatrix}
        1&0\\
        0&-1
    \end{pmatrix}
    M(\theta, \phi) \cdot \PPP&=
    M({\theta+\pi/15,\pi-\varphi}) \cdot \PPP.
\end{align*}
`
:::

:::theorem (label := "lem:symmetries")
See `\cite{polyhedron.without.rupert}`, Lemma 7.
:::

:::corollary (label := "cor:rupert_tightening")
`\lean{Tightening.rupert_tightening}`

If the noperthedron is Rupert, then there exists a solution with

$$`
\begin{align*}
\theta_1,\theta_2&\in[0,2\pi/15] \subset [0,0.42], \\
\varphi_1&\in [0,\pi] \subset [0,3.15],\\
\varphi_2&\in [0,\pi/2] \subset [0,1.58],\\
\alpha &\in [-\pi/2,\pi/2] \subset [-1.58,1.58].
\end{align*}
`
:::

:::proof (label := "cor:rupert_tightening")

{uses (label:="lem:symmetries")}[]

See `{citep polyhedron.without.rupert}[]`, Lemma 8.
:::

```lean
#bp_summary
#bp_graph
#show_graph «lem:radius_noperthedron_one»
```
