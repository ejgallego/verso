import Mathlib.Data.Real.CompleteField
import Mathlib.Analysis.InnerProductSpace.PiL2

import Noperthedron.Basic
import Noperthedron.PoseInterval
import Noperthedron.Bounding
import Noperthedron.Local.Prelims
import Noperthedron.Local.OriginInTriangle
import Noperthedron.Local.Spanp

namespace Local

open scoped RealInnerProductSpace Real
open scoped Matrix

def Triangle : Type := Fin 3 → ℝ³

/--
[SY25] Definition 34.
We define "congruent" to mean "there exists a linear isometry". Note that this is
stronger than "there exists an *affine* isometry", which might be the definition
you usually think of.
-/
def Triangle.Congruent (P Q : Triangle) : Prop :=
  ∃ L : Euc(3) →ₗᵢ[ℝ] Euc(3), ∀ i, P i = L (Q i)

/-- [SY25] Definition 27. Note that the "+ 1" at the type Fin 3 wraps. -/
structure Triangle.Spanning (P : Triangle) (θ φ ε : ℝ) : Prop where
  pos : 0 < ε
  lt : ∀ i : Fin 3, 2 * ε * (√2 + ε) < ⟪rotR (π / 2) (rotM θ φ (P i)), rotM θ φ (P (i + 1))⟫

lemma spanning_neg {P : Triangle} {θ φ ε : ℝ} (e : ℤ) (h : P.Spanning θ φ ε) :
    Triangle.Spanning (fun i ↦ (-1:ℝ)^e • P i) θ φ ε := by
  sorry

lemma triangle_ineq_aux
    {d x y : ℝ} (hd : 0 < d) (hy : d < y) (hx : |x - y| ≤ d) : 0 < x := by
  grind

/-- [SY25] Lemma 28 -/
theorem vecX_spanning {ε θ θ_ φ φ_ : ℝ} (P : Triangle)
    (hθ : |θ - θ_| ≤ ε) (hφ : |φ - φ_| ≤ ε)
    (hSpanning: P.Spanning θ_ φ_ ε)
    (hP : ∀ i, ‖P i‖ ≤ 1)
    (hX : ∀ i, 0 < ⟪vecX θ φ, P i⟫) :
    vecX θ φ ∈ Spanp P := by
  sorry
