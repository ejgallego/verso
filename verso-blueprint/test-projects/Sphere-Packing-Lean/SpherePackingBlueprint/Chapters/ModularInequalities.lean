import Verso
import VersoManual
import VersoBlueprint
import SpherePackingBlueprint.ToolchainWorkarounds
import SpherePackingBlueprint.Bibliography

open Verso.Genre
open Verso.Genre.Manual hiding citep citet citehere
open Informal

set_option doc.verso true
set_option pp.rawOnError true


#doc (Manual) "Proof of the Optimal Function Inequalities" =>


:::group "fg_setup"
Auxiliary functions $`F,G` and reformulation of inequalities.
:::

:::group "fg_differential"
Differential equations and monotonicity control.
:::

:::group "g_theorem"
Assembly of the final theorem producing the optimal function.
:::

This chapter follows the inequality strategy refined in {citet Lee}[].

:::lemma_ "prop:ineqA" (parent := "fg_setup")
Positivity of the first integral kernel $`A(t)` on $`(0,\infty)`.
:::

:::proof "prop:ineqA"
Equivalent to the first $`F \pm cG` inequality.
:::

:::lemma_ "prop:ineqB" (parent := "fg_setup")
Positivity of the second integral kernel $`B(t)` on $`(0,\infty)`.
:::

:::proof "prop:ineqB"
Equivalent to the second $`F \pm cG` inequality.
:::

:::definition "def:FG-definition" (lean := "F,G") (parent := "fg_setup")
Define the core expressions $`F` and $`G` from Eisenstein/theta combinations.
:::

:::proof "def:FG-definition"
Direct algebraic definitions.
:::

:::lemma_ "lemma:F-G-phi-psi-identities" (parent := "fg_setup")
Relate $`\phi_0` and $`\psi_S` to $`F/\Delta` and $`G/\Delta`.
:::

:::proof "lemma:F-G-phi-psi-identities"
Substitute definitions and simplify.
:::

:::lemma_ "lemma:ineqABnew-equiv" (parent := "fg_setup")
The positivity of $`A,B` is equivalent to positivity of $`F \pm (18/\pi^2)G` on the imaginary axis.
:::

:::proof "lemma:ineqABnew-equiv"
Combine {uses "lemma:F-G-phi-psi-identities"}[] with discriminant positivity.
:::

:::lemma_ "lemma:F-G-pos" (lean := "F_imag_axis_pos, G_imag_axis_pos") (parent := "fg_setup")
$`F(it)` and $`G(it)` are positive for $`t > 0`.
:::

:::proof "lemma:F-G-pos"
From theta/discriminant positivity and Ramanujan identities.
:::

:::corollary "cor:ineqAnew" (lean := "FG_inequality_1") (parent := "fg_setup")
First strict inequality $`F + (18/\pi^2)G > 0`.
:::

:::proof "cor:ineqAnew"
Use {uses "lemma:F-G-pos"}[] with the reformulation lemma.
:::

:::lemma_ "lemma:FG-de" (lean := "MLDE_F, MLDE_G") (parent := "fg_differential")
Differential equations satisfied by $`F` and $`G` under Serre-derivative operators.
:::

:::proof "lemma:FG-de"
Apply {uses "thm:ramanujan-formula"}[] and {uses "thm:serre-der-prod-rule"}[].
:::

:::corollary "cor:MLDE-pos" (parent := "fg_differential")
A positivity-compatible differential inequality for the ratio expression used in the monotonicity step.
:::

:::proof "cor:MLDE-pos"
Combine {uses "lemma:FG-de"}[] with {uses "thm:anti-serre-der-pos"}[].
:::

:::lemma_ "lemma:Qlim" (lean := "FmodG_rightLimitAt_zero") (parent := "fg_differential")
Compute the right-limit near zero of the normalized quotient $`Q`.
:::

:::proof "lemma:Qlim"
Use modular transformations and q-expansions.
:::

:::lemma_ "lemma:log-der-inf" (parent := "fg_differential")
Asymptotic control of the logarithmic derivative as $`t \to \infty`.
:::

:::proof "lemma:log-der-inf"
From q-series derivative estimates.
:::

:::lemma_ "prop:Qdec" (lean := "FmodG_strictAntiOn") (parent := "fg_differential")
The quotient function $`Q` is strictly decreasing on $`(0,\infty)`.
:::

:::proof "prop:Qdec"
Use {uses "cor:MLDE-pos"}[] and boundary behavior from
{uses "lemma:Qlim"}[] and {uses "lemma:log-der-inf"}[].
:::

:::corollary "cor:ineqBnew" (lean := "FG_inequality_2") (parent := "fg_differential")
Second strict inequality $`F - (18/\pi^2)G > 0`.
:::

:::proof "cor:ineqBnew"
Apply monotonicity from {uses "prop:Qdec"}[].
:::

:::theorem "thm:g1" (parent := "g_theorem")
Construct $`g` as an explicit linear combination of $`a` and $`b` such that:
- $`g` is radial Schwartz,
- $`g` has the required sign conditions,
- $`g(0) = \widehat{g}(0) = 1`.
:::

:::proof "thm:g1"
Combine {uses "prop:a-fourier"}[], {uses "prop:b-fourier"}[],
{uses "prop:a-double-zeros"}[], {uses "prop:b-double-zeros"}[],
{uses "prop:ineqA"}[], {uses "prop:ineqB"}[],
{uses "prop:a0"}[], and {uses "prop:b0"}[].
:::
