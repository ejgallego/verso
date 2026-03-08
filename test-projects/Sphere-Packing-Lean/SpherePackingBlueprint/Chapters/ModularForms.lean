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


#doc (Manual) "Modular Forms" =>


:::group "modular_forms_setup"
Congruence groups, slash operators, and modular forms.
:::

:::group "eisenstein_discriminant"
Eisenstein series, the discriminant form, and positivity/nonvanishing tools.
:::

:::group "theta_and_identities"
Theta constants and identities used in the magic-function construction.
:::

:::group "serre_derivative"
Serre derivative identities and differential inequalities.
:::

This chapter follows the modular-form pipeline from the original blueprint and
uses references such as {citet first.course}[].

:::definition "def:slash-operator" (parent := "modular_forms_setup")
Define the weight-$`k` slash action of $`\mathrm{SL}_2(\mathbb{Z})` on functions on the upper half-plane.
:::

:::proof "def:slash-operator"
Direct formula using the automorphy factor.
:::

:::lemma_ "lemma:slash-negI-even-weight" (lean := "modular_slash_negI_of_even") (parent := "modular_forms_setup")
For even weight, slash by $`-I` acts trivially.
:::

:::proof "lemma:slash-negI-even-weight"
Immediate from $`(-1)^{-k} = 1` for even $`k`.
:::

:::definition "def:Mk" (lean := "ModularForm") (parent := "modular_forms_setup")
Define modular forms of weight $`k` and level $`\Gamma`.
:::

:::proof "def:Mk"
Standard slash-invariance, holomorphy, and cusp-growth conditions.
:::

:::definition "def:Ek" (lean := "ModularForm.eisensteinSeries_MF") (parent := "eisenstein_discriminant")
Define Eisenstein series $`E_k` for even $`k \ge 4`.
:::

:::proof "def:Ek"
Classical series definition.
:::

:::lemma_ "lemma:Ek-is-modular-form" (lean := "EisensteinSeries.eisensteinSeries_SIF") (parent := "eisenstein_discriminant")
$`E_k` is a modular form and satisfies the expected $`S`-transformation law.
:::

:::proof "lemma:Ek-is-modular-form"
By absolute convergence and slash-invariance.
:::

:::lemma_ "lemma:Ek-Fourier" (lean := "E_k_q_expansion") (parent := "eisenstein_discriminant")
Fourier expansions of Eisenstein series.
:::

:::proof "lemma:Ek-Fourier"
Classical q-expansion theorem.
:::

:::definition "def:E2" (lean := "E₂_eq") (parent := "eisenstein_discriminant")
Define $`E_2` by q-expansion.
:::

:::proof "def:E2"
Direct definition.
:::

:::lemma_ "lemma:E2-transform-S" (lean := "E₂_transform") (parent := "eisenstein_discriminant")
$`E_2` is quasimodular and satisfies the $`S`-transformation defect term.
:::

:::proof "lemma:E2-transform-S"
Classical exercise in modular forms.
:::

:::definition "def:dedekind_eta" (lean := "η") (parent := "eisenstein_discriminant")
Define the Dedekind eta function.
:::

:::proof "def:dedekind_eta"
Direct infinite product definition.
:::

:::definition "def:disc-definition" (lean := "Δ") (parent := "eisenstein_discriminant")
Define the discriminant modular form $`\Delta`.
:::

:::proof "def:disc-definition"
Direct q-product definition.
:::

:::lemma_ "lemma:disc-cuspform" (lean := "Delta") (parent := "eisenstein_discriminant")
$`\Delta` is a weight-12 cusp form.
:::

:::proof "lemma:disc-cuspform"
Use the eta-transformation law.
:::

:::corollary "cor:disc-pos" (lean := "Delta_imag_axis_pos") (parent := "eisenstein_discriminant")
$`\Delta(it) > 0` on the positive imaginary axis.
:::

:::proof "cor:disc-pos"
By product positivity.
:::

:::corollary "cor:disc-nonvanishing" (lean := "Δ_ne_zero") (parent := "eisenstein_discriminant")
$`\Delta(z) \ne 0` on the upper half-plane.
:::

:::proof "cor:disc-nonvanishing"
Follows from cusp-form product structure.
:::

:::definition "def:th00-th01-th10" (lean := "Θ₂, Θ₃, Θ₄") (parent := "theta_and_identities")
Define Jacobi theta constants $`\Theta_2,\Theta_3,\Theta_4`.
:::

:::proof "def:th00-th01-th10"
Direct theta-series definitions.
:::

:::definition "def:H2-H3-H4" (lean := "H₂, H₃, H₄") (parent := "theta_and_identities")
Define $`H_2 = \Theta_2^4`, $`H_3 = \Theta_3^4`, $`H_4 = \Theta_4^4`.
:::

:::proof "def:H2-H3-H4"
Direct algebraic definition.
:::

:::lemma_ "lemma:theta-transform-S-T" (lean := "H₂_T_action,H₃_T_action,H₄_T_action,H₂_S_action,H₃_S_action,H₄_S_action") (parent := "theta_and_identities")
Transformation laws of the theta quartics under $`S` and $`T`.
:::

:::proof "lemma:theta-transform-S-T"
Derived from Jacobi theta transformations.
:::

:::lemma_ "lemma:theta-modular" (lean := "H₂_MF,H₃_MF,H₄_MF") (parent := "theta_and_identities")
$`H_2,H_3,H_4` are modular forms of level 2.
:::

:::proof "lemma:theta-modular"
From slash invariance and boundedness at cusps.
:::

:::lemma_ "lemma:jacobi-identity" (lean := "jacobi_identity") (parent := "theta_and_identities")
Jacobi identity relating the theta quartics.
:::

:::proof "lemma:jacobi-identity"
Dimension and q-expansion comparison.
:::

:::lemma_ "lemma:lv1-lv2-identities" (parent := "theta_and_identities")
Identities expressing $`E_4,E_6,\Delta` in terms of $`H_2,H_3,H_4`.
:::

:::proof "lemma:lv1-lv2-identities"
Use uniqueness of low-weight level-1 forms and q-expansions.
:::

:::corollary "cor:theta-pos" (lean := "H₂_imag_axis_pos, H₄_imag_axis_pos") (parent := "theta_and_identities")
Positivity statements for theta quartics on the positive imaginary axis.
:::

:::proof "cor:theta-pos"
From theta-series positivity and transformations.
:::

:::definition "def:derivative" (lean := "D") (parent := "serre_derivative")
Define the normalized complex derivative operator on modular forms.
:::

:::proof "def:derivative"
Direct operator definition.
:::

:::definition "def:serre-der" (lean := "serre_D") (parent := "serre_derivative")
Define the Serre derivative.
:::

:::proof "def:serre-der"
Direct definition in terms of $`D` and $`E_2`.
:::

:::theorem "thm:serre-der-modularity" (lean := "serre_D_slash_invariant") (parent := "serre_derivative")
Serre derivative raises weight by 2 while preserving modularity.
:::

:::proof "thm:serre-der-modularity"
By slash-equivariance and cancellation of quasimodular defects.
:::

:::theorem "thm:ramanujan-formula" (lean := "ramanujan_E₂, ramanujan_E₄, ramanujan_E₆, ramanujan_E₂', ramanujan_E₄', ramanujan_E₆'") (parent := "serre_derivative")
Ramanujan differential equations for $`E_2,E_4,E_6`.
:::

:::proof "thm:ramanujan-formula"
Apply {uses "thm:serre-der-modularity"}[] and low-weight dimension constraints.
:::

:::theorem "thm:serre-der-prod-rule" (lean := "serre_D_mul") (parent := "serre_derivative")
Product rule for Serre derivatives.
:::

:::proof "thm:serre-der-prod-rule"
Direct computation from the definition.
:::

:::theorem "thm:anti-serre-der-pos" (parent := "serre_derivative")
Monotonicity criterion on the positive imaginary axis for anti-Serre-type differential operators.
:::

:::proof "thm:anti-serre-der-pos"
Combine Ramanujan identities with sign information from
{uses "cor:disc-pos"}[] and {uses "cor:theta-pos"}[].
:::
