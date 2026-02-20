import Noperthedron.Basic
import Noperthedron.Bounding.OpNorm
import Noperthedron.Bounding.RaRa
import Noperthedron.Bounding.Lemma11

/-!

Material for [SY25] Lemma 12.

-/

namespace Bounding
open Real
open scoped Real

theorem dist_rot3_apply {d : Fin 3} {α α' : ℝ} {v : ℝ³} :
  ‖(rot3 d α - rot3 d α') v‖ = 2 * |sin ((α - α') / 2)| * ‖(WithLp.toLp 2 (Fin.removeNth d v) : ℝ²)‖ := by
    sorry

theorem dist_rot3 {d : Fin 3} {α α' : ℝ} :
  ‖rot3 d α - rot3 d α'‖ = 2 * |sin ((α - α') / 2)| := by
    apply ContinuousLinearMap.opNorm_eq_of_bounds
    try positivity
    · intro v
      rw [dist_rot3_apply]
      by_cases h : |sin ((α - α') / 2)| = 0
      · rw [h]; simp
      · field_simp
        simp [PiLp.norm_eq_sum, Fin.sum_univ_three]
        apply rpow_le_rpow
        · positivity
        ·  try fin_cases d <;> {
            simp [Fin.removeNth_apply, Fin.succAbove] -- TODO: simp only
            positivity
          }
        · positivity

    · intro N N_nonneg h
      let d' := d
      let v : ℝ³ := if d = 0 then !₂[0, 1, 0] else !₂[1, 0, 0]
      have norm_v_one : ‖v‖ = 1 := by
        unfold v
        split <;> simp [PiLp.norm_eq_sum, Fin.sum_univ_three]
      fin_cases d <;> {
        specialize h v
        calc
          2 * |sin ((α - α') / 2)| = _ := by rfl
          _ = ‖(rot3 d' α - rot3 d' α') v‖ := by
            rw [dist_rot3_apply]
            simp [v, d', PiLp.norm_eq_sum, Fin.removeNth_apply, Fin.succAbove]
          _ ≤ N * ‖v‖ := by assumption
          _ = N := by simp [norm_v_one]
      }

theorem dist_rot2_apply {α α' : ℝ} {v : ℝ²} :
  ‖(rot2 α - rot2 α') v‖ = 2 * |sin ((α - α') / 2)| * ‖v‖ := by
    sorry

theorem dist_rot2 {α α' : ℝ} :
    ‖rot2 α - rot2 α'‖ = 2 * |sin ((α - α') / 2)| := by
  refine ContinuousLinearMap.opNorm_eq_of_bounds ?_ ?_ ?_
  · positivity
  · intro v
    rw [dist_rot2_apply]
  · intro N N_nonneg h
    specialize h !₂[1, 0]
    have norm_xhat_eq_one : ‖!₂[(1 : ℝ), 0]‖ = 1 := by simp [PiLp.norm_eq_sum, Fin.sum_univ_two]
    calc
      2 * |sin ((α - α') / 2)| = _ := by rfl
      _ = ‖(rot2 α - rot2 α') !₂[(1 : ℝ), 0]‖ := by simp only [dist_rot2_apply, norm_xhat_eq_one, mul_one]
      _ ≤ N * ‖!₂[(1 : ℝ), 0]‖ := by assumption
      _ = N := by simp [norm_xhat_eq_one]

theorem dist_rot3_eq_dist_rot {d : Fin 3} {α α' : ℝ} : ‖rot3 d α - rot3 d α'‖ = ‖rot2 α - rot2 α'‖ := by
  simp only [dist_rot3, dist_rot2]

lemma two_mul_abs_sin_half_le {α : ℝ} : 2 * |sin (α / 2)| ≤ |α| := by
  sorry

theorem dist_rot2_le_dist {α α' : ℝ} : ‖rot2 α - rot2 α'‖ ≤ ‖α - α'‖ := by
  calc
    ‖rot2 α - rot2 α'‖ = _ := by rfl
    _ = 2 * |sin ((α - α') / 2)| := by apply dist_rot2
    _ ≤ |α - α'| := by apply two_mul_abs_sin_half_le

def rot3_eq_rot3_mat_toEuclideanLin {d : Fin 3} {θ : ℝ}: rot3 d θ = (rot3_mat d θ).toEuclideanLin := by
  fin_cases d <;> simp [RxL, RyL, RzL, rot3, rot3_mat]

end Bounding
