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


#doc (Manual) "Cohn-Elkies Bounds" =>


:::group "ce_periodic"
Linear programming bound for periodic sphere packings.
:::

:::group "ce_general"
Passage from periodic to general packings.
:::

:::group "ce_optimal_function"
Existence of the optimal normalized auxiliary function in dimension eight.
:::

Following {citet ElkiesCohn}[], we use the sign constraints
$`f(x) \le 0` outside the forbidden radius and $`\widehat{f}(x) \ge 0` everywhere.

:::theorem "thm:Cohn-Elkies-periodic" (lean := "LinearProgrammingBound'") (parent := "ce_periodic")
For a lattice-periodic packing with pairwise center distance at least one,
any Schwartz function satisfying the Cohn-Elkies sign conditions bounds density by
$`f(0) / \widehat{f}(0) \cdot \mathrm{Vol}(B_d(0,1/2))`.
:::

:::proof "thm:Cohn-Elkies-periodic"
Use {uses "thm:Poisson-summation-formula"}[] and positivity of Fourier-side terms.
:::

:::theorem "thm:Cohn-Elkies-general" (lean := "LinearProgrammingBound") (parent := "ce_general")
The same bound holds for arbitrary sphere packings (not necessarily periodic).
:::

:::proof "thm:Cohn-Elkies-general"
Combine {uses "thm:Cohn-Elkies-periodic"}[] with {uses "thm:periodic-packing-optimal"}[].
:::

:::theorem "thm:g" (parent := "ce_optimal_function")
There exists a radial Schwartz function $`g : \mathbb{R}^8 \to \mathbb{R}` with
- $`g(x) \le 0` for $`\|x\| \ge \sqrt{2}`,
- $`\widehat{g}(x) \ge 0` for all $`x`,
- $`g(0) = \widehat{g}(0) = 1`.
:::

:::proof "thm:g"
This follows from the explicit $`a,b` construction and the inequalities in
{uses "thm:g1"}[].
:::
