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

```texPrelude
\newcommand{\R}{\mathbb{R}}
\newcommand{\Z}{\mathbb{Z}}
\newcommand{\C}{\mathbb{C}}
\newcommand{\N}{\mathbb{N}}
\newcommand{\h}{\mathfrak{H}}
\newcommand{\B}{\mathcal{B}}
\newcommand{\Pa}{\mathcal{P}}
\newcommand{\Vol}[1]{\operatorname{Vol}\!\left(#1\right)}
\newcommand{\Bd}[1]{\B_d\!\left(#1\right)}
\newcommand{\dd}{\mathrm{d}}
\newcommand{\rad}{\mathrm{rad}}
\newcommand{\set}[1]{\left\{ #1 \right\}}
\newcommand{\setof}[2]{\left\{ #1 \,\mid\, #2 \right\}}
\newcommand{\abs}[1]{\left\lvert #1 \right\rvert}
\newcommand{\norm}[1]{\left\lVert #1 \right\rVert}
\newcommand{\ang}[1]{\left\langle #1 \right\rangle}
\newcommand{\eps}{\varepsilon}
```

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
