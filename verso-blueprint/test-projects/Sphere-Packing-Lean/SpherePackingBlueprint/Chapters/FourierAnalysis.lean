import Verso
import VersoManual
import VersoBlueprint
import SpherePackingBlueprint.ToolchainWorkarounds

open Verso.Genre
open Verso.Genre.Manual hiding citep citet citehere
open Informal

set_option doc.verso true
set_option pp.rawOnError true


#doc (Manual) "Fourier Analysis" =>


:::group "fourier_setup"
Fourier transform and Schwartz-space preliminaries.
:::

:::group "poisson_formula"
Summability lemmas and Poisson summation over lattices.
:::

:::definition "def:Fourier-Transform" (lean := "Real.fourierIntegral") (parent := "fourier_setup")
Define the Fourier transform on Euclidean space with the normalization used by the Cohn-Elkies bound.
:::

:::proof "def:Fourier-Transform"
Direct analytic definition.
:::

:::lemma_ "lemma:Gaussian-Fourier" (parent := "fourier_setup")
The Fourier transform of a Gaussian is an explicit Gaussian.
:::

:::proof "lemma:Gaussian-Fourier"
Classical calculation.
:::

:::definition "def:Schwartz-Space" (lean := "SchwartzMap") (parent := "fourier_setup")
Define Schwartz functions as smooth functions with rapid decay of all derivatives.
:::

:::proof "def:Schwartz-Space"
Direct functional-analytic definition.
:::

:::lemma_ "lemma:Fourier-transform-is-automorphism" (lean := "SchwartzMap.fourierTransformCLM") (parent := "fourier_setup")
Fourier transform is an automorphism of Schwartz space.
:::

:::proof "lemma:Fourier-transform-is-automorphism"
Standard Schwartz-space Fourier theory.
:::

:::lemma_ "lemma:inv-power-summable" (parent := "poisson_formula")
Inverse power tails are summable in the range needed for lattice summation arguments.
:::

:::proof "lemma:inv-power-summable"
By comparison with convergent $`p`-series.
:::

:::lemma_ "lemma:Schwartz-summable" (parent := "poisson_formula")
Summing Schwartz functions over lattices is absolutely convergent.
:::

:::proof "lemma:Schwartz-summable"
Use rapid decay together with {uses "lemma:inv-power-summable"}[].
:::

:::theorem "thm:Poisson-summation-formula" (lean := "SchwartzMap.PoissonSummation_Lattices") (parent := "poisson_formula")
Poisson summation holds for Schwartz functions on lattices.
:::

:::proof "thm:Poisson-summation-formula"
Apply the Schwartz summability lemmas and Fourier inversion machinery.
:::

:::theorem "thm:smooth-fast-decay-schwartz" (parent := "poisson_formula")
Smooth functions with sufficiently fast derivative decay belong to Schwartz space.
:::

:::proof "thm:smooth-fast-decay-schwartz"
Direct from the defining seminorm bounds.
:::
