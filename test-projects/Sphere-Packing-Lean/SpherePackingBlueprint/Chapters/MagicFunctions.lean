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


#doc (Manual) "Fourier Eigenfunctions with Double Zeroes" =>


:::group "magic_phi_construction"
Auxiliary modular expressions and integral formulas defining $`a`.
:::

:::group "magic_a_properties"
Schwartz, Fourier-eigenfunction, and double-zero properties of $`a`.
:::

:::group "magic_psi_construction"
Auxiliary forms and integral formulas defining $`b`.
:::

:::group "magic_b_properties"
Schwartz, Fourier-eigenfunction, and double-zero properties of $`b`.
:::

The strategy in this chapter matches the original blueprint and feeds into
the final inequality theorem for the optimal function.

:::definition "def:phi4-phi2-phi0" (parent := "magic_phi_construction")
Define the functions $`\phi_{-4}, \phi_{-2}, \phi_0` from $`E_2,E_4,E_6,\Delta`.
:::

:::proof "def:phi4-phi2-phi0"
Direct algebraic definitions.
:::

:::lemma_ "lemma:phi0-transform" (parent := "magic_phi_construction")
Transformation laws for $`\phi_0` under $`T` and $`S`.
:::

:::proof "lemma:phi0-transform"
Expand definitions and use transformation formulas from the modular-forms chapter.
:::

:::definition "def:a-definition" (lean := "MagicFunction.a.RealIntegrals.a',MagicFunction.a.RadialFunctions.a") (parent := "magic_phi_construction")
Define $`a` via six contour integrals built from $`\phi_0`.
:::

:::proof "def:a-definition"
Direct integral definition.
:::

:::lemma_ "lemma:mod-div-disc-bound" (lean := "MagicFunction.PolyFourierCoeffBound.DivDiscBoundOfPolyFourierCoeff") (parent := "magic_phi_construction")
Polynomial Fourier-coefficient growth implies growth bounds for ratios by $`\Delta`.
:::

:::proof "lemma:mod-div-disc-bound"
Use nonvanishing of $`\Delta` and coefficient growth.
:::

:::corollary "cor:phi0-bound" (parent := "magic_phi_construction")
Global bound for $`\phi_0(it)` on the positive imaginary axis.
:::

:::proof "cor:phi0-bound"
Combine q-expansions with {uses "lemma:mod-div-disc-bound"}[].
:::

:::corollary "cor:phi2-bound" (parent := "magic_phi_construction")
Global bound for $`\phi_{-2}(it)`.
:::

:::proof "cor:phi2-bound"
Same method as {uses "cor:phi0-bound"}[].
:::

:::corollary "cor:phi4-bound" (parent := "magic_phi_construction")
Global bound for $`\phi_{-4}(it)`.
:::

:::proof "cor:phi4-bound"
Same method as {uses "cor:phi0-bound"}[].
:::

:::lemma_ "lem:integral-bound" (parent := "magic_a_properties")
General contour-integral estimate used to bound each $`I_j` term.
:::

:::proof "lem:integral-bound"
Estimate the exponential kernel on vertical and horizontal paths.
:::

:::lemma_ "lem:bound-I1-I3-I5" (parent := "magic_a_properties")
Bounds for $`I_1, I_3, I_5`.
:::

:::proof "lem:bound-I1-I3-I5"
Apply {uses "lem:integral-bound"}[] and the $`\phi` growth bounds.
:::

:::lemma_ "lem:bound-I2-I4-I6" (parent := "magic_a_properties")
Bounds for $`I_2, I_4, I_6`.
:::

:::proof "lem:bound-I2-I4-I6"
Apply {uses "lem:integral-bound"}[] and the $`\phi` growth bounds.
:::

:::lemma_ "prop:a-schwartz" (lean := "MagicFunction.FourierEigenfunctions.a") (parent := "magic_a_properties")
$`a` is a radial Schwartz function.
:::

:::proof "prop:a-schwartz"
Combine the integral-term bounds with {uses "thm:smooth-fast-decay-schwartz"}[].
:::

:::lemma_ "prop:a-fourier" (lean := "MagicFunction.a.Fourier.eig_a") (parent := "magic_a_properties")
$`a` is a Fourier eigenfunction with eigenvalue $`+1`.
:::

:::proof "prop:a-fourier"
Use Gaussian Fourier transforms plus contour manipulations.
:::

:::corollary "cor:phi0-near-0-infty" (parent := "magic_a_properties")
Asymptotic control of $`\phi_0(it)` for $`t \to 0` and $`t \to \infty`.
:::

:::proof "cor:phi0-near-0-infty"
Derive from {uses "cor:phi0-bound"}[], {uses "cor:phi2-bound"}[], and {uses "cor:phi4-bound"}[].
:::

:::lemma_ "prop:a-double-zeros" (parent := "magic_a_properties")
$`a` has double zeroes at lattice vectors with norm larger than $`\sqrt{2}`.
:::

:::proof "prop:a-double-zeros"
Use the alternative integral form and asymptotic cancellation.
:::

:::lemma_ "prop:a0" (lean := "MagicFunction.a.SpecialValues.a_zero") (parent := "magic_a_properties")
Evaluate $`a(0)` exactly.
:::

:::proof "prop:a0"
Extract the constant term from the convergent integral representation.
:::

:::definition "def:h" (parent := "magic_psi_construction")
Define the intermediate modular expression $`h` used to build $`\psi_I,\psi_T,\psi_S`.
:::

:::proof "def:h"
Direct algebraic definition.
:::

:::definition "def:psiI-psiT-psiS" (parent := "magic_psi_construction")
Define $`\psi_I,\psi_T,\psi_S` via slash-operator combinations of $`h`.
:::

:::proof "def:psiI-psiT-psiS"
Direct from slash-action formulas.
:::

:::lemma_ "lemma:psi-new" (parent := "magic_psi_construction")
Explicit closed forms for $`\psi_I,\psi_T,\psi_S` in terms of $`H_2,H_3,H_4,\Delta`.
:::

:::proof "lemma:psi-new"
Algebraic elimination using theta identities.
:::

:::lemma_ "lemma:psiI-psiT-psiS-fourier" (parent := "magic_psi_construction")
Leading Fourier terms for $`\psi_I` and $`\psi_T`.
:::

:::proof "lemma:psiI-psiT-psiS-fourier"
Expand the explicit formulas from {uses "lemma:psi-new"}[].
:::

:::definition "def:b-definition" (parent := "magic_psi_construction")
Define $`b` via six contour integrals built from $`\psi_I,\psi_T,\psi_S`.
:::

:::proof "def:b-definition"
Direct integral definition.
:::

:::lemma_ "lemma:psi-bound" (parent := "magic_b_properties")
Exponential growth/decay bounds for $`\psi_I,\psi_T,\psi_S` on the relevant contours.
:::

:::proof "lemma:psi-bound"
From q-expansions and transformation formulas.
:::

:::lemma_ "lemma:bound-J1-J3-J5" (parent := "magic_b_properties")
Bounds for $`J_1,J_3,J_5`.
:::

:::proof "lemma:bound-J1-J3-J5"
Apply {uses "lemma:psi-bound"}[] and contour estimates.
:::

:::lemma_ "lemma:bound-J2-J4-J6" (parent := "magic_b_properties")
Bounds for $`J_2,J_4,J_6`.
:::

:::proof "lemma:bound-J2-J4-J6"
Apply {uses "lemma:psi-bound"}[] and contour estimates.
:::

:::lemma_ "prop:b-schwartz" (lean := "MagicFunction.FourierEigenfunctions.b") (parent := "magic_b_properties")
$`b` is a radial Schwartz function.
:::

:::proof "prop:b-schwartz"
Use the $`J_j` bounds and {uses "thm:smooth-fast-decay-schwartz"}[].
:::

:::lemma_ "prop:b-fourier" (lean := "MagicFunction.b.Fourier.eig_b") (parent := "magic_b_properties")
$`b` is a Fourier eigenfunction with eigenvalue $`-1`.
:::

:::proof "prop:b-fourier"
Contour deformation plus Gaussian transform identities.
:::

:::corollary "cor:psiI-near-0-infty" (parent := "magic_b_properties")
Asymptotic control of $`\psi_I(it)` near zero and infinity.
:::

:::proof "cor:psiI-near-0-infty"
Derive from {uses "lemma:psi-bound"}[] and transformation formulas.
:::

:::lemma_ "prop:b-double-zeros" (parent := "magic_b_properties")
$`b` has double zeroes at lattice vectors with norm larger than $`\sqrt{2}`.
:::

:::proof "prop:b-double-zeros"
Use {uses "cor:psiI-near-0-infty"}[] and the alternative integral expression.
:::

:::lemma_ "prop:b0" (lean := "MagicFunction.b.SpecialValues.b_zero") (parent := "magic_b_properties")
Evaluate $`b(0)` exactly.
:::

:::proof "prop:b0"
Read the constant term from the convergent integral form.
:::
