import Verso
import VersoManual
import VersoBlueprint
import SpherePackingBlueprint.ToolchainWorkarounds

open Verso.Genre
open Verso.Genre.Manual hiding citep citet citehere
open Informal

set_option doc.verso true
set_option pp.rawOnError true


#doc (Manual) "The E8 Lattice" =>


:::group "e8_definitions"
Equivalent models of the $`E_8` lattice.
:::

:::group "e8_properties"
Basic structural and arithmetic properties of $`E_8`.
:::

:::group "e8_density"
Definition and density computation of the $`E_8` sphere packing.
:::

:::definition "E8-Set" (lean := "Submodule.E8") (parent := "e8_definitions")
Define $`E_8` as vectors in $`\mathbb{R}^8` with even coordinate sum and either all integer or all half-integer coordinates.
:::

:::proof "E8-Set"
Direct algebraic definition.
:::

:::definition "E8-Matrix" (lean := "E8Matrix") (parent := "e8_definitions")
Define the explicit basis matrix whose $`\mathbb{Z}`-span gives the same lattice.
:::

:::proof "E8-Matrix"
Direct matrix-level definition.
:::

:::theorem "E8-defs-equivalent" (lean := "span_E8Matrix") (parent := "e8_definitions")
The two definitions coincide: set-based characterization equals $`\mathbb{Z}`-span of the basis matrix.
:::

:::proof "E8-defs-equivalent"
Show each side contains the other by explicit coordinate arithmetic.
:::

:::lemma_ "E8-is-basis" (lean := "span_E8Matrix_eq_top") (parent := "e8_properties")
The $`E_8` basis matrix spans all of $`\mathbb{R}^8` over $`\mathbb{R}`.
:::

:::proof "E8-is-basis"
Prove the matrix is invertible.
:::

:::lemma_ "E8-Lattice" (lean := "E8Lattice") (parent := "e8_properties")
$`E_8` is a lattice in $`\mathbb{R}^8`.
:::

:::proof "E8-Lattice"
Use {uses "E8-defs-equivalent"}[] and subgroup closure.
:::

:::lemma_ "E8-vector-norms" (lean := "E8_norm_eq_sqrt_even") (parent := "e8_properties")
Every lattice vector has norm $`\sqrt{2n}` for some nonnegative integer $`n`.
:::

:::proof "E8-vector-norms"
Expand the norm-square as an even integral quadratic form.
:::

:::lemma_ "instDiscreteE8Lattice" (lean := "instDiscreteE8Lattice") (parent := "e8_properties")
$`E_8` is discrete.
:::

:::proof "instDiscreteE8Lattice"
The minimal nonzero norm gives an open neighborhood containing only zero.
:::

:::lemma_ "instLatticeE8" (lean := "instIsZLatticeE8Lattice") (parent := "e8_properties")
$`E_8` is a $`\mathbb{Z}`-lattice.
:::

:::proof "instLatticeE8"
Combine discreteness and spanning.
:::

:::definition "E8Packing" (lean := "E8Packing") (parent := "e8_density")
Define the $`E_8` sphere packing with separation $`\sqrt{2}` and centers $`E_8`.
:::

:::proof "E8Packing"
Direct construction from the lattice.
:::

:::lemma_ "E8Packing-covol" (lean := "E8Basis_volume") (parent := "e8_density")
The covolume of $`E_8` is $`1`.
:::

:::proof "E8Packing-covol"
Compute the determinant of the basis matrix.
:::

:::theorem "E8Packing-density" (lean := "E8Packing_density") (parent := "e8_density")
$`\Delta_{\mathcal{P}(E_8)} = \pi^4 / 384`.
:::

:::proof "E8Packing-density"
Apply {uses "theorem:psp-density"}[] together with {uses "E8Packing-covol"}[].
:::
