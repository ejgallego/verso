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


#doc (Manual) "Sphere Packings" =>


:::group "sphere_setup"
Definitions of sphere packings, density, and the optimization target.
:::

:::group "sphere_scaling"
Scaling invariance of finite density and asymptotic density.
:::

:::group "periodic_packings"
Periodic and lattice packings as a reduced optimization class.
:::

:::group "sphere_main_statement"
Reduction from Cohn-Elkies bounds to the final dimension-8 theorem.
:::

The high-level plan follows {citet Via2017}[] and {citet ElkiesCohn}[].

:::definition "SpherePacking.balls" (lean := "SpherePacking.balls") (parent := "sphere_setup")
Given centers $`X \subseteq \mathbb{R}^d` and separation radius $`r > 0`,
define the packing $`\mathcal{P}(X)` as the union of open radius-$`r` balls at points of $`X`.
:::

:::proof "SpherePacking.balls"
This is the foundational geometric object used throughout the blueprint.
:::

:::definition "SpherePacking.finiteDensity" (lean := "SpherePacking.finiteDensity") (parent := "sphere_setup")
For $`R > 0`, the finite density is
$`\Delta_{\mathcal{P}}(R) = \mathrm{Vol}(\mathcal{P} \cap B_d(0,R)) / \mathrm{Vol}(B_d(0,R))`.
:::

:::proof "SpherePacking.finiteDensity"
Direct definition.
:::

:::definition "SpherePacking.density" (lean := "SpherePacking.density") (parent := "sphere_setup")
The packing density is the limit superior
$`\Delta_{\mathcal{P}} := \limsup_{R \to \infty} \Delta_{\mathcal{P}}(R)`.
:::

:::proof "SpherePacking.density"
Direct definition.
:::

:::definition "SpherePackingConstant" (lean := "SpherePackingConstant") (parent := "sphere_setup")
Define the sphere packing constant $`\Delta_d` as the supremum of densities over all sphere packings in $`\mathbb{R}^d`.
:::

:::proof "SpherePackingConstant"
Direct definition.
:::

:::definition "SpherePacking.scale" (lean := "SpherePacking.scale") (parent := "sphere_scaling")
For $`c > 0`, scaling a packing $`\mathcal{P}(X)` gives $`\mathcal{P}(cX)`.
:::

:::proof "SpherePacking.scale"
Direct definition.
:::

:::lemma_ "SpherePacking.scale_finiteDensity" (lean := "SpherePacking.scale_finiteDensity") (parent := "sphere_scaling")
Finite density is scale-covariant:
$`\Delta_{\mathcal{P}(cX)}(cR) = \Delta_{\mathcal{P}(X)}(R)`.
:::

:::proof "SpherePacking.scale_finiteDensity"
By scaling Lebesgue measure in dimension $`d`.
:::

:::lemma_ "SpherePacking.scale_density" (lean := "SpherePacking.scale_density") (parent := "sphere_scaling")
Asymptotic density is scale-invariant.
:::

:::proof "SpherePacking.scale_density"
Apply {uses "SpherePacking.scale_finiteDensity"}[] and pass to limit superior.
:::

:::lemma_ "SpherePacking.constant_eq_constant_normalized" (lean := "SpherePacking.constant_eq_constant_normalized") (parent := "sphere_scaling")
The same supremum can be computed over unit-separation packings.
:::

:::proof "SpherePacking.constant_eq_constant_normalized"
Use {uses "SpherePacking.scale_density"}[] to normalize every packing.
:::

:::definition "IsZLattice" (lean := "IsZLattice") (parent := "periodic_packings")
A $`\mathbb{Z}`-lattice in $`\mathbb{R}^d` is a discrete additive subgroup spanning the ambient space.
:::

:::proof "IsZLattice"
Standard lattice definition.
:::

:::definition "def:dual-lattice" (lean := "LinearMap.BilinForm.dualSubmodule") (parent := "periodic_packings")
Define the dual lattice with respect to the Euclidean bilinear pairing.
:::

:::proof "def:dual-lattice"
Direct linear-algebraic definition.
:::

:::definition "PeriodicSpherePacking" (lean := "PeriodicSpherePacking") (parent := "periodic_packings")
A periodic packing is a sphere packing with centers invariant under translation by a lattice.
:::

:::proof "PeriodicSpherePacking"
Direct structure-level definition.
:::

:::definition "def:Periodic-sphere-packing-constant" (lean := "PeriodicSpherePackingConstant") (parent := "periodic_packings")
Define the periodic sphere packing constant as the supremum over periodic packings.
:::

:::proof "def:Periodic-sphere-packing-constant"
Direct definition.
:::

:::theorem "thm:periodic-packing-optimal" (lean := "periodic_constant_eq_constant") (parent := "periodic_packings")
The periodic sphere packing constant equals the unrestricted sphere packing constant.
:::

:::proof "thm:periodic-packing-optimal"
Reduction by approximation of arbitrary packings with periodic ones.
:::

:::theorem "theorem:CE_Main" (parent := "sphere_main_statement")
Assuming the Cohn-Elkies optimal auxiliary function and the computed density of the $`E_8` packing,
we obtain the upper bound $`\Delta_8 \leq \Delta_{\mathcal{P}(E_8)}`.
:::

:::proof "theorem:CE_Main"
Apply the global Cohn-Elkies inequality to the normalized optimal function.
:::

:::corollary "corollary:upper-bound-E8" (parent := "sphere_main_statement")
The sphere packing constant in dimension 8 is bounded above by the $`E_8` lattice packing density.
:::

:::proof "corollary:upper-bound-E8"
Combine {uses "theorem:CE_Main"}[] with {uses "thm:periodic-packing-optimal"}[].
:::

:::corollary "MainTheorem" (lean := "SpherePacking.MainTheorem") (parent := "sphere_main_statement")
$`\Delta_8 = \Delta_{\mathcal{P}(E_8)}`.
:::

:::proof "MainTheorem"
Use {uses "corollary:upper-bound-E8"}[] and the matching lower bound from the explicit $`E_8` packing construction.
:::
