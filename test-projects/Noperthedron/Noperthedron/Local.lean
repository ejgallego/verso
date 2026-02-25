import Mathlib.Data.Real.CompleteField
import Mathlib.Analysis.InnerProductSpace.PiL2

import Noperthedron.Basic
import Noperthedron.Bounding.OpNorm
import Noperthedron.PoseInterval
import Noperthedron.Local.Coss
import Noperthedron.Local.EpsSpanning
import Noperthedron.Local.LocallyMaximallyDistant
import Noperthedron.Local.Prelims
import Noperthedron.Local.OriginInTriangle
import Noperthedron.Local.Spanp

namespace Local

open scoped RealInnerProductSpace Real
open scoped Matrix

/-- [SY25] Lemma 30 -/
theorem inCirc {δ ε θ₁ θ₁_ θ₂ θ₂_ φ₁ φ₁_ φ₂ φ₂_ α α_: ℝ} {P Q : Euc(3)}
    (hP : ‖P‖ ≤ 1) (hQ : ‖Q‖ ≤ 1)
    (hε : 0 < ε)
    (hθ₁ : |θ₁ - θ₁_| ≤ ε) (hφ₁ : |φ₁ - φ₁_| ≤ ε)
    (hθ₂ : |θ₂ - θ₂_| ≤ ε) (hφ₂ : |φ₂ - φ₂_| ≤ ε)
    (hα : |α - α_| ≤ ε) :
    let T : Euc(2) := midpoint ℝ (rotR α_ (rotM θ₁_ φ₁_ P)) (rotM θ₂_ φ₂_ Q)
    ‖T - rotM θ₂_ φ₂_ Q‖ ≤ δ →
    (rotR α (rotM θ₁ φ₁ P) ∈ Metric.ball T (√5 * ε + δ) ∧
     rotM θ₂ φ₂ Q ∈ Metric.ball T (√5 * ε + δ)) := by
  sorry

/--
Condition A_ε from [SY25] Theorem 36
-/
def Triangle.Aε (X : ℝ³) (P : Triangle) (ε : ℝ) : Prop :=
  ∃ σ ∈ ({-1, 1} : Set ℤ), ∀ i : Fin 3, (-1)^σ * ⟪X, P i⟫ > √2 * ε

noncomputable
def Triangle.Bε.lhs (v₁ v₂ : Euc(3)) (p : Pose) (ε : ℝ) : ℝ :=
   (⟪p.rotM₂ v₁, p.rotM₂ (v₁ - v₂)⟫ - 2 * ε * ‖v₁ - v₂‖ * (√2 + ε))
   / ((‖p.rotM₂ v₁‖ + √2 * ε) * (‖p.rotM₂ (v₁ - v₂)‖ + 2 * √2 * ε))

/--
Condition B_ε from [SY25] Theorem 36
-/
def Triangle.Bε (Q : Triangle) (poly : Finset Euc(3)) (p : Pose) (ε δ r : ℝ) : Prop :=
  ∀ i : Fin 3, ∀ v ∈ poly, v ≠ Q i →
    (δ + √5 * ε) / r < Triangle.Bε.lhs (Q i) v p ε

--instance : Membership Triangle (Finset ℝ³) where
--  mem set tri := ∀ i : Fin 3, (tri i) ∈ set

/-- The condition on δ in the Local Theorem -/
def BoundDelta (δ : ℝ) (p : Pose) (P Q : Triangle) : Prop :=
  ∀ i : Fin 3, δ ≥ ‖p.rotR (p.rotM₁ (P i)) - p.rotM₂ (Q i)‖/2

/-- The condition on r in the Local Theorem -/
def BoundR (r ε : ℝ) (p : Pose) (Q : Triangle): Prop :=
  ∀ i : Fin 3, ‖p.rotM₂ (Q i)‖ > r + √2 * ε

--- XXX: this is a leftover shim that should be cleaned up
noncomputable
def shape_of (S : Finset ℝ³) : Shape where
  vertices := S

-- TODO: Somehow separate out the "local theorem precondition"
-- predicate in a way that is suitable for the computational step's
-- tree check.

-- TODO: refactor to use GoodPoly?

/--
  [SY25] Theorem 36
-/
theorem local_theorem (P Q : Triangle)
    (cong_tri : P.Congruent Q)
    (poly : Finset ℝ³) (ne : poly.Nonempty)
    (hP : ∀ i, P i ∈ poly) (hQ : ∀ i, Q i ∈ poly)
    (radius_one : polyhedronRadius poly ne = 1)
    (p_ : Pose)
    (ε δ r : ℝ) (hε : 0 < ε) (hr : 0 < r)
    (hr₁ : BoundR r ε p_ Q)
    (hδ : BoundDelta δ p_ P Q)
    (ae₁ : P.Aε p_.vecX₁ ε) (ae₂ : Q.Aε p_.vecX₂ ε)
    (span₁ : P.Spanning p_.θ₁ p_.φ₁ ε)
    (span₂ : Q.Spanning p_.θ₂ p_.φ₂ ε)
    (be : Q.Bε poly p_ ε δ r)
    : ¬∃ p ∈ p_.closed_ball ε, RupertPose p (shape_of poly |>.hull) := by
  sorry
