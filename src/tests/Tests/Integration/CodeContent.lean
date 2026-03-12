/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Jason Reed
-/
import Verso
import VersoManual

namespace Verso.Integration.CodeContent

open Verso Genre Manual InlineLean

--------------------

#docs (Manual) doc "Title of the Doc" :=
:::::::

%%%
authors := ["Harry Q. Bovik"]
%%%

Here is some code with vertical bars:
```lean
def or := (· || ·)
```

Here is some with a variety of interesting Unicode, including characters where UTF-16 is funky:
```lean
def Set (α : Type u) : Type u := α → Prop

instance : EmptyCollection (Set α) where
  emptyCollection := fun _ => False

instance : Union (Set α) where
  union a b := fun x => a x ∨ b x

instance : Inter (Set α) where
  inter a b := fun x => a x ∧ b x

instance : Membership α (Set α) where
  mem a x := a x

@[ext]
theorem Set.ext {a b : Set α} :
    (∀ x, x ∈ a ↔ x ∈ b) → a = b := by
  intro h
  funext x
  exact propext (h x)

instance : HasSubset (Set α) where
  Subset a b := ∀ x, x ∈ a → x ∈ b

@[simp, grind .]
theorem Set.subset_refl {a : Set α} : a ⊆ a := by
  simp [(· ⊆ ·)]

@[grind ←]
theorem Set.subset_union {a b c : Set α} :
    a ⊆ b → a ⊆ b ∪ c := by
  simp [(· ⊆ ·), (· ∪ ·), (· ∈ ·)]
  intro h
  solve_by_elim

def Set.powerset (a : Set α) : Set (Set α) :=
  fun (x : Set α) => x ⊆ a

notation "𝒫 " x => Set.powerset x

theorem Set.powerset_empty_nonempty :
    ∃ (a : Set α), a ∈ 𝒫 {} := by
  constructor
  case w => exact {}
  simp [(· ∈ ·), powerset]

@[grind? →]
theorem Set.powerset_empty_unique (x y : Set α) :
    x ∈ (𝒫 {}) → y ∈ (𝒫 {}) → x = y := by
  intro hx hy
  ext x'
  exact (iff_false_right (hy x')).mpr (hx x')
```

And now some inline code:

 * {lean}`∀x y : Set _, x ∈ ((𝒫 x) ∪ (𝒫 y))`
 * {lean}`true || false`
 * {lean}`False → True`

And here is a proof explained step-by-step with `:::multilean`:

:::multilean
```lean
theorem reverse_reverse_demo (xs : List α) :
    xs.reverse.reverse = xs := by
  induction xs with
  | nil =>
      rfl
  | cons x xs ih =>
```
The induction turns the theorem into the empty-list case and the cons case. In the second branch,
`ih` records that reversing the tail twice gives back the original tail.
```lean
      simp [List.reverse_cons, ih]
```
The final `simp` unfolds `List.reverse_cons` and uses the induction hypothesis to collapse the
double reverse on the tail.
:::

:::::::
