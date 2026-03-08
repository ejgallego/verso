import Verso
import VersoManual
import VersoBlueprint
import SpherePackingBlueprint.ToolchainWorkarounds

open Verso.Genre
open Verso.Genre.Manual hiding citep citet citehere
open Informal

set_option doc.verso true
set_option pp.rawOnError true


#doc (Manual) "Density of Packings" =>


:::group "density_finite_bounds"
Bounds comparing finite density with local center counts.
:::

:::group "density_periodic_counts"
Volume-count asymptotics for lattice and periodic center sets.
:::

:::group "density_formula"
Closed formula for density of periodic sphere packings.
:::

:::lemma_ "lemma:sp-finite-density-bound" (lean := "SpherePacking.finiteDensity_le,SpherePacking.finiteDensity_ge") (parent := "density_finite_bounds")
Finite density is squeezed between center counts in slightly smaller/larger balls.
:::

:::proof "lemma:sp-finite-density-bound"
Compare unions of radius-$`r/2` balls and use disjointness.
:::

:::lemma_ "lemma:lattice-points-bound" (lean := "PeriodicSpherePacking.aux2_ge',PeriodicSpherePacking.aux2_le'") (parent := "density_periodic_counts")
The number of lattice points in a radius-$`R` ball is controlled by ball-volume over fundamental-domain volume.
:::

:::proof "lemma:lattice-points-bound"
Use the lattice tiling by translates of a bounded fundamental domain.
:::

:::lemma_ "lemma:periodic-points-bounds" (lean := "PeriodicSpherePacking.aux_ge,PeriodicSpherePacking.aux_le") (parent := "density_periodic_counts")
Center counts for periodic sets are controlled by lattice counts times the quotient cardinality.
:::

:::proof "lemma:periodic-points-bounds"
Intersect the fundamental-domain tilings with the periodic center set.
:::

:::lemma_ "lemma:volume-ball-ratio-limit" (lean := "volume_ball_ratio_tendsto_nhds_one''") (parent := "density_periodic_counts")
For fixed $`C > 0`, we have
$`\mathrm{Vol}(B_d(R)) / \mathrm{Vol}(B_d(R + C)) \to 1` as $`R \to \infty`.
:::

:::proof "lemma:volume-ball-ratio-limit"
Expand ball volumes and simplify to a rational power limit.
:::

:::theorem "theorem:psp-density" (lean := "PeriodicSpherePacking.density_eq") (parent := "density_formula")
For periodic packing centers $`X` with lattice $`\Lambda` and separation $`r`,
$`\Delta_{\mathcal{P}} = |X / \Lambda| \cdot \mathrm{Vol}(B_d(r/2)) / \mathrm{Vol}(\mathbb{R}^d / \Lambda)`.
:::

:::proof "theorem:psp-density"
Combine the counting bounds and apply the sandwich theorem with
{uses "lemma:volume-ball-ratio-limit"}[].
:::
