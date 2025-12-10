/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean.CoreM
import Lean.EnvExtension
import VersoBlueprint.Data

namespace Informal.Environment

open Lean
open Informal.Data

-- use batteries
structure State where
  data : Data := Data.empty
  stack : List Name := []
deriving Inhabited, Repr

initialize informalExt : EnvExtension State ←
  registerEnvExtension (pure $ {})

section EnvOps

variable [Monad m] [MonadEnv m]

def modify (f : State -> State) : m Unit :=
  modifyEnv (informalExt.modifyState · f)

-- stack operators, to associate {uses} role to the currently opened label
def push (label : Name) : m Unit :=
  modify fun data => { data with stack := label :: data.stack }

def pop : m Unit :=
  modify fun data => { data with stack := data.stack.tail }

def peek : m (Option Name) := do
  return (informalExt.getState (← getEnv)).stack.head?

def stack : m (List Name) := do
  return (informalExt.getState (← getEnv)).stack

def addDep [MonadLog m] [AddMessageContext m] [MonadOptions m] (stx : Syntax) (dep : Name) : m Unit := do
  let some label ← peek
    | logErrorAt stx m!"uses declaration outside an informal enviroment"
      pure ()
  -- dbg_trace s!"Adding dep to {repr (← stack)}"
  modify fun state => { state with data := state.data.pushDep label dep }

end EnvOps
