import VersoManual

open Verso Doc Genre Manual

namespace Benchmark.ManualGenreScaling

def defaultExtensionImpls : ExtensionImpls := by
  exact extension_impls%

abbrev MInline := Doc.Inline Manual
abbrev MBlock := Doc.Block Manual
abbrev MPart := Doc.Part Manual

def paragraphInlines (sectionIndex paragraphIndex : Nat) : Array MInline :=
  #[
    .text s!"Benchmark section {sectionIndex}, paragraph {paragraphIndex}. ",
    .emph #[.text "Traversal"],
    .text " and ",
    .bold #[.text "elaboration"],
    .text " should scale reasonably as the synthetic manual grows. ",
    .code s!"code-{sectionIndex}-{paragraphIndex}",
    .text " keeps the inline tree nontrivial."
  ]

def paragraph (sectionIndex paragraphIndex : Nat) : MBlock :=
  .para (paragraphInlines sectionIndex paragraphIndex)

def mkSubsection (sectionIndex subsectionIndex : Nat) : MPart :=
  .mk
    #[.text s!"Detail {sectionIndex}.{subsectionIndex}"]
    s!"Detail {sectionIndex}.{subsectionIndex}"
    none
    #[
      paragraph sectionIndex (10 * subsectionIndex),
      paragraph sectionIndex (10 * subsectionIndex + 1)
    ]
    #[]

def mkSection (sectionIndex : Nat) : MPart :=
  .mk
    #[.text s!"Section {sectionIndex}"]
    s!"Section {sectionIndex}"
    none
    #[
      paragraph sectionIndex 0,
      paragraph sectionIndex 1,
      paragraph sectionIndex 2
    ]
    #[
      mkSubsection sectionIndex 1
    ]

def syntheticManual (sections : Nat) : MPart :=
  .mk
    #[.text s!"Synthetic traversal benchmark ({sections} sections)"]
    s!"Synthetic traversal benchmark ({sections} sections)"
    (some {number := false, file := some "index"})
    #[paragraph 0 999]
    ((Array.range sections).map mkSection)

structure Counts where
  parts : Nat := 0
  blocks : Nat := 0
  inlines : Nat := 0
deriving Repr, Inhabited

def Counts.add (x y : Counts) : Counts := {
  parts := x.parts + y.parts,
  blocks := x.blocks + y.blocks,
  inlines := x.inlines + y.inlines
}

partial def countInline : MInline → Counts
  | .text _ | .code _ | .math _ _ | .linebreak _ => { inlines := 1 }
  | .emph xs | .bold xs | .concat xs =>
      Counts.add { inlines := 1 } <| xs.foldl (init := ({} : Counts)) fun acc x =>
        Counts.add acc (countInline x)
  | .link xs _ | .footnote _ xs | .other _ xs =>
      Counts.add { inlines := 1 } <| xs.foldl (init := ({} : Counts)) fun acc x =>
        Counts.add acc (countInline x)
  | .image alt _ => { inlines := alt.length + 1 }

partial def countBlock : MBlock → Counts
  | .para xs =>
      Counts.add { blocks := 1 } <| xs.foldl (init := ({} : Counts)) fun acc x =>
        Counts.add acc (countInline x)
  | .code _ => { blocks := 1 }
  | .ul items | .ol _ items => Counts.add { blocks := 1 } <| items.foldl (init := ({} : Counts)) fun acc item =>
      item.contents.foldl (init := acc) fun acc' block =>
        Counts.add acc' (countBlock block)
  | .dl items => Counts.add { blocks := 1 } <| items.foldl (init := ({} : Counts)) fun acc item =>
      let terms := item.term.foldl (init := ({} : Counts)) fun acc' x => Counts.add acc' (countInline x)
      let descs := item.desc.foldl (init := ({} : Counts)) fun acc' block => Counts.add acc' (countBlock block)
      Counts.add (Counts.add acc terms) descs
  | .blockquote xs | .concat xs | .other _ xs =>
      Counts.add { blocks := 1 } <| xs.foldl (init := ({} : Counts)) fun acc x =>
        Counts.add acc (countBlock x)

partial def countPart (part : MPart) : Counts :=
  let titleCounts := part.title.foldl (init := ({} : Counts)) fun acc x => Counts.add acc (countInline x)
  let contentCounts := part.content.foldl (init := ({} : Counts)) fun acc block => Counts.add acc (countBlock block)
  let subpartCounts := part.subParts.foldl (init := ({} : Counts)) fun acc subpart => Counts.add acc (countPart subpart)
  Counts.add (Counts.add { parts := 1 } titleCounts) <| Counts.add contentCounts subpartCounts

def nsToMs (time : Nat) : Float :=
  Float.ofNat time / 1000000.0

def meanMs (samples : Array Nat) : Float :=
  if samples.isEmpty then
    0
  else
    let total := samples.foldl (init := 0) fun acc t => acc + t
    Float.ofNat total / Float.ofNat samples.size / 1000000.0

def medianMs (samples : Array Nat) : Float :=
  if samples.isEmpty then
    0
  else
    let sorted := samples.qsort (· < ·)
    let mid := sorted.size / 2
    if sorted.size % 2 = 1 then
      nsToMs sorted[mid]!
    else
      (nsToMs sorted[mid - 1]! + nsToMs sorted[mid]!) / 2.0

def oneTraversalNs (doc : MPart) : IO Nat := do
  let start ← IO.monoNanosNow
  discard <| ReaderT.run (traverse (fun _ => pure ()) doc {}) defaultExtensionImpls
  let stop ← IO.monoNanosNow
  pure (stop - start)

def parseNat? (s : String) : Option Nat :=
  s.toNat?

def parseArgs (args : List String) : IO (Nat × Array Nat) := do
  match args with
  | [] => pure (5, #[25, 50, 100, 200, 400, 800])
  | repeats :: sizes =>
      let some repeats := parseNat? repeats
        | throw <| .userError s!"Expected a repeat count, got {repeats}"
      let mut parsed := #[]
      for size in sizes do
        let some n := parseNat? size
          | throw <| .userError s!"Expected a size, got {size}"
        parsed := parsed.push n
      if parsed.isEmpty then
        pure (repeats, #[25, 50, 100, 200, 400, 800])
      else
        pure (repeats, parsed)

def run (args : List String) : IO Unit := do
  let (repeats, sizes) ← parseArgs args
  IO.println "sections,parts,blocks,inlines,repeats,median_ms,mean_ms,min_ms,max_ms"
  for sectionCount in sizes do
    let doc := syntheticManual sectionCount
    let counts := countPart doc
    let _ ← oneTraversalNs doc
    let mut samples := #[]
    for _ in [0:repeats] do
      samples := samples.push (← oneTraversalNs doc)
    let minNs := samples.foldl (init := samples[0]!) fun acc t => if t < acc then t else acc
    let maxNs := samples.foldl (init := samples[0]!) fun acc t => if acc < t then t else acc
    let minMs := nsToMs minNs
    let maxMs := nsToMs maxNs
    IO.println
      s!"{sectionCount},{counts.parts},{counts.blocks},{counts.inlines},{repeats},{medianMs samples},{meanMs samples},{minMs},{maxMs}"

end Benchmark.ManualGenreScaling

def main (args : List String) : IO Unit :=
  Benchmark.ManualGenreScaling.run args
