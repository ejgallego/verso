/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/
module
public import Lean.Data.Options
import Std.Data.HashMap

open Lean
open Std (HashMap)

public section

register_option verso.elab.profile : Bool := {
  defValue := false
  descr := "Collect coarse Verso elaboration timings and print a summary for each #doc page"
}

namespace Verso.Doc.Elab.Profile

structure Stats where
  count : Nat := 0
  totalMs : Nat := 0
  maxMs : Nat := 0
deriving Inhabited

abbrev Ref := IO.Ref (HashMap Name Stats)

def mkRef : BaseIO Ref := IO.mkRef {}

def getEnabled [Monad m] [MonadOptions m] : m Bool := do
  return (← getOptions).get verso.elab.profile.name verso.elab.profile.defValue

private def update (stats : Stats) (elapsedMs : Nat) : Stats :=
  { count := stats.count + 1
    totalMs := stats.totalMs + elapsedMs
    maxMs := max stats.maxMs elapsedMs }

def record (ref : Ref) (label : Name) (elapsedMs : Nat) : BaseIO Unit :=
  ref.modify fun stats => stats.insert label (update (stats[label]?.getD {}) elapsedMs)

def profileRefM [Monad m] [MonadLiftT BaseIO m] (ref? : Option Ref) (label : Name) (act : m α) : m α := do
  let some ref := ref?
    | act
  let start ← liftM IO.monoMsNow
  let x ← act
  let stop ← liftM IO.monoMsNow
  liftM <| record ref label (stop - start)
  pure x

private def sortStats (stats : HashMap Name Stats) : Array (Name × Stats) :=
  stats.toArray.qsort fun (x, sx) (y, sy) =>
    sx.totalMs > sy.totalMs ||
      (sx.totalMs == sy.totalMs && x.quickCmp y == .lt)

private def avgMs (stats : Stats) : Nat :=
  if stats.count = 0 then
    0
  else
    stats.totalMs / stats.count

def emitSummary (title : String) (totalMs : Nat) (ref : Ref) : IO Unit := do
  let stats ← ref.get
  let linePrefix := "[verso.elab.profile]"
  IO.println s!"{linePrefix} {title} total={totalMs}ms"
  for (label, s) in sortStats stats do
    IO.println s!"{linePrefix}   {label} count={s.count} total={s.totalMs}ms avg={avgMs s}ms max={s.maxMs}ms"

end Verso.Doc.Elab.Profile
