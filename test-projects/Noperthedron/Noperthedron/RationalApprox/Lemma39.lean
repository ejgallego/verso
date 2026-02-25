import Mathlib.Analysis.InnerProductSpace.PiL2

namespace RationalApprox

theorem sum_mul_sq_le_sum_mul_abs_sq {n : ℕ} (v w : Fin n → ℝ)
    (δ : ℝ) (hδ : 0 < δ) (hle : ∀ j, |w j| ≤ δ) :
    (∑ j, w j * v j)^2 ≤ (∑ j, δ * |v j|)^2 := by
  calc (∑ j, w j * v j)^2
    _ ≤ (|(∑ j, w j * v j)|)^2 := by rw [sq_abs]
    _ ≤ ((∑ j, |w j * v j|))^2 := by
        refine (sq_le_sq₀ (by positivity) (by positivity)).mpr ?_
        exact Finset.abs_sum_le_sum_abs (fun i ↦ w i * v i) Finset.univ
    _ = ((∑ j, |w j| * |v j|))^2 := by simp
    _ ≤ (∑ j, δ * |v j|)^2 := by
        refine (sq_le_sq₀ (by positivity) (by positivity)).mpr ?_
        apply Finset.sum_le_sum
        intro i hi
        grw [hle i]

theorem sum_abs_sq_le_sum_abs_sq_mul {n : ℕ} (v : Fin n → ℝ) :
    (∑ j, |v j|) ^ 2 ≤ (∑ j, |v j| ^ 2) * n := by
  have h : (∑ j, |v j| * 1)^2  ≤ (∑ j, |v j| ^ 2) * (∑ _ : Fin n, 1 ^ 2) :=
    Finset.sum_mul_sq_le_sq_mul_sq Finset.univ (fun j => |v j|) (fun _ => 1)
  simpa using h

/-- [SY25] Lemma 39 -/
theorem norm_le_delta_sqrt_dims {m n : ℕ} {δ : ℝ} (A : Matrix (Fin m) (Fin n) ℝ)
    (hδ : 0 < δ) (hle : ∀ i j, |A i j| ≤ δ) :
    ‖A.toEuclideanLin.toContinuousLinearMap‖ ≤ δ * √(m * n) := by
  sorry
