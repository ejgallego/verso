import Mathlib.Analysis.InnerProductSpace.Dual
import Mathlib.MeasureTheory.Integral.IntervalIntegral.FundThmCalculus
import Mathlib.Analysis.InnerProductSpace.Calculus
import Noperthedron.Nopert
import Noperthedron.PoseInterval
import Noperthedron.Global.Basic
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic

/- [SY25] Lemma 20 -/

open scoped RealInnerProductSpace

namespace GlobalTheorem

private abbrev E (n : ℕ) := EuclideanSpace ℝ (Fin n)

-- FIXME: the fact that I can't find exactly this lemma with loogle on "sum" and EuclideanSpace.single
-- makes me think there's probably some nearby lemma that uses different tools, maybe?
lemma vector_rep {n : ℕ} (v : E n) : v = ∑ x, v.ofLp x • EuclideanSpace.single x 1 := by
  ext i; simp [Finset.sum_apply, Pi.single_apply]

lemma nth_partial_def {n : ℕ} (f : E n → ℝ) (v w : E n) :
    fderiv ℝ f w v = ∑ i, v i * nth_partial i f w := by
  unfold nth_partial
  rw [show ∑ i, v.ofLp i * (fderiv ℝ f w) (EuclideanSpace.single i 1)
         = (fderiv ℝ f w) (∑ x, v.ofLp x • EuclideanSpace.single x 1)
      by simp]
  congr
  exact vector_rep v

private noncomputable
def interpolator {n : ℕ} (x y : E n) (t : ℝ) : E n :=
  (1 - t) • x + t • y

private noncomputable
def interpolator' {n : ℕ} (x y : E n) : ℝ →L[ℝ] E n :=
  ContinuousLinearMap.toSpanSingleton ℝ (y - x)

private noncomputable
def interpolator_has_deriv {n : ℕ} (x y : E n) (t : ℝ) :
    HasFDerivAt (interpolator x y) (interpolator' x y) t := by
  unfold interpolator'
  rw [← hasDerivAt_iff_hasFDerivAt]
  unfold interpolator
  -- I don't really like this proof, I'd prefer something that more incrementally
  -- "discovers" the derivative of interpolator instead of building it all up and then
  -- `convert`ing it to the desired form.
  convert ((hasDerivAt_id t).const_sub 1).smul_const x |>.add ((hasDerivAt_id t).smul_const y) using 1
  ext i
  simp only [PiLp.sub_apply, neg_smul, one_smul, PiLp.add_apply, PiLp.neg_apply]
  ring_nf

private noncomputable
def interpolated {n : ℕ} (x y : E n) (f : E n → ℝ) : ℝ → ℝ  :=
  f ∘ interpolator x y

private noncomputable
def Differentiable.interpolator {n : ℕ} (x y : E n) :
    Differentiable ℝ (interpolator x y)  := by
  unfold GlobalTheorem.interpolator
  fun_prop

private noncomputable
def Differentiable.interpolated {n : ℕ} (x y : E n) (f : E n → ℝ) (fc : ContDiff ℝ 2 f) :
    Differentiable ℝ (interpolated x y f)  := by
  have := Differentiable.interpolator x y
  have := fc.differentiable (by norm_num)
  unfold GlobalTheorem.interpolated
  fun_prop

private noncomputable
def interpolated_deriv {n : ℕ} (x y : E n) (f : E n → ℝ) (t : ℝ) : ℝ :=
  ∑ i, (y i - x i) * nth_partial i f ((1 - t) • x + t • y)

private noncomputable
def interpolated_deriv2 {n : ℕ} (x y : E n) (f : E n → ℝ) (t : ℝ) : ℝ :=
  ∑ i, ∑ j, (y i - x i) * (y j - x j) * (nth_partial i <| nth_partial j f) ((1 - t) • x + t • y)

private
lemma interpolated_deriv2_bound {n : ℕ} (x y : E n) {f : E n → ℝ}
    (mpb : mixed_partials_bounded f) {ε : ℝ} (hε : 0 < ε) (hdiff : (i : Fin n) → |x i - y i| ≤ ε)
    (t : ℝ) :
    |interpolated_deriv2 x y f t| ≤ n^2 * ε^2 := by
  calc |interpolated_deriv2 x y f t|
  _ ≤ ∑ i, |∑ j, (y i - x i) * (y j - x j) * nth_partial i (nth_partial j f) ((1 - t) • x + t • y)| := by
    apply Finset.abs_sum_le_sum_abs
  _ ≤ ∑ i, ∑ j, |(y i - x i) * (y j - x j) * nth_partial i (nth_partial j f) ((1 - t) • x + t • y)| := by
    refine Finset.sum_le_sum ?_; intro i hi;
    apply Finset.abs_sum_le_sum_abs
  _ = ∑ i, ∑ j, |(y i - x i)| * |(y j - x j)| * |nth_partial i (nth_partial j f) ((1 - t) • x + t • y)| := by
    conv => enter [1, 2, i, 2, j]; repeat rw [abs_mul];
  _ ≤ ∑ i, ∑ j, ε * ε * 1 := by
    refine Finset.sum_le_sum ?_; intro i hi;
    refine Finset.sum_le_sum ?_; intro j hj;
    rw [abs_sub_comm]; grw [hdiff i]
    rw [abs_sub_comm]; grw [hdiff j]
    unfold mixed_partials_bounded at mpb; grw [mpb]
  _ = n^2 * ε^2 := by
    simp only [mul_one, Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]
    ring_nf

lemma c2_imp_partials_differentiable {n : ℕ} {f : E n → ℝ} {i : Fin n} (fc : ContDiff ℝ 2 f) :
      Differentiable ℝ (nth_partial i f) := by
  have h_deriv : Differentiable ℝ (fderiv ℝ f) :=
    ContDiff.differentiable (n := 1) (by fun_prop) one_ne_zero
  exact h_deriv.clm_apply (differentiable_const _)

lemma c2_imp_partials_c1 {n : ℕ} {f : E n → ℝ} {j : Fin n} (fc : ContDiff ℝ 2 f) :
    ContDiff ℝ 1 (nth_partial j f) := by
  (apply ContDiff.fderiv_apply <;> try fun_prop); norm_num

lemma c2_imp_mixed_partials_continuous {n : ℕ} {f : E n → ℝ} {i j : Fin n} (fc : ContDiff ℝ 2 f) :
      Continuous (nth_partial i (nth_partial j f)) := by
  have h1 : ContDiff ℝ 1 (nth_partial j f) := c2_imp_partials_c1 fc
  have h0 : ContDiff ℝ 0 (nth_partial i (nth_partial j f)) := by
    (apply ContDiff.fderiv_apply <;> try fun_prop); norm_num
  exact h0.continuous

open ContinuousLinearMap in
def interpolated_has_deriv {n : ℕ} (x y : E n) (f : E n → ℝ) (fc : ContDiff ℝ 2 f) (t : ℝ) :
    HasDerivAt (interpolated x y f) (interpolated_deriv x y f t) t := by
  unfold interpolated interpolated_deriv
  rw [hasDerivAt_iff_hasFDerivAt]
  have hfd : HasFDerivAt f (fderiv ℝ f (interpolator x y t)) (interpolator x y t) :=
    fc.differentiable (by norm_num) |>.differentiableAt.hasFDerivAt

  have : (toSpanSingleton ℝ (∑ i, (y.ofLp i - x.ofLp i) * nth_partial i f ((1 - t) • x + t • y)))
      = ((fderiv ℝ f (interpolator x y t)).comp (interpolator' x y)) := by
    unfold interpolator' interpolator
    ext
    simp only [toSpanSingleton_apply, smul_eq_mul, one_mul, coe_comp', Function.comp_apply,
      one_smul]
    rw [nth_partial_def f]
    congr
  rw [this]
  exact HasFDerivAt.comp t hfd (interpolator_has_deriv x y t)

open ContinuousLinearMap in
def interpolated_has_deriv2 {n : ℕ} (x y : E n) (f : E n → ℝ) (fc : ContDiff ℝ 2 f) (t : ℝ) :
    HasDerivAt (interpolated_deriv x y f) (interpolated_deriv2 x y f t) t := by
  sorry

def deriv_interpolated {n : ℕ} (x y : E n) (f : E n → ℝ) (fc : ContDiff ℝ 2 f) :
    deriv (interpolated x y f) = interpolated_deriv x y f := by
  ext t
  exact (interpolated_has_deriv x y f fc t).deriv

def deriv_interpolated2 {n : ℕ} (x y : E n) (f : E n → ℝ) (fc : ContDiff ℝ 2 f) :
    deriv (interpolated_deriv x y f) = interpolated_deriv2 x y f := by
  ext t
  exact (interpolated_has_deriv2 x y f fc t).deriv

def differentiable_deriv_interpolated {n : ℕ} (x y : E n) (f : E n → ℝ) (fc : ContDiff ℝ 2 f) :
    Differentiable ℝ (interpolated_deriv x y f) := by
  unfold interpolated_deriv
  refine Differentiable.fun_sum ?_; intro i hi
  refine Differentiable.mul (by fun_prop) ?_
  change Differentiable ℝ ((fun v ↦ nth_partial i f v) ∘ (fun t ↦ (1 - t) • x + t • y))
  refine Differentiable.comp ?_ (by fun_prop)
  exact c2_imp_partials_differentiable fc

def continuous_deriv_interpolated2 {n : ℕ} (x y : E n) (f : E n → ℝ) (fc : ContDiff ℝ 2 f) :
    Continuous (interpolated_deriv2 x y f) := by
  unfold interpolated_deriv2
  refine continuous_finset_sum Finset.univ ?_; intro i hi
  refine continuous_finset_sum Finset.univ ?_; intro j hj
  refine Continuous.mul (by fun_prop) ?_
  change Continuous ((fun v ↦ nth_partial i (nth_partial j f) v) ∘ (fun t ↦ (1 - t) • x + t • y))
  refine Continuous.comp ?_ (by fun_prop)
  exact c2_imp_mixed_partials_continuous fc

theorem bounded_partials_control_difference {n : ℕ} (f : E n → ℝ)
    (fc : ContDiff ℝ 2 f) (x y : E n)
    (ε : ℝ) (hε : ε > 0) (hdiff : (i : Fin n) → |x i - y i| ≤ ε)
    (mpb : mixed_partials_bounded f) :
    |f x - f y| ≤ ε * ∑ i, |nth_partial i f x| + (n^2 / 2) * ε^2 := by
  sorry
