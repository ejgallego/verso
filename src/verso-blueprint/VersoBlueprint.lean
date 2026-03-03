/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias, David Thrane Christiansen
-/

-- XXX VersoManual is not module yet
-- module

-- Blueprint library extending the Verso `Manual` genre.

import Lean.Elab.InfoTree.Types

import VersoManual

import VersoBlueprint.Data
import VersoBlueprint.ExternalRefSnapshot
import VersoBlueprint.Environment
import VersoBlueprint.Attribute
import VersoBlueprint.Cite
import VersoBlueprint.Commands.Graph
import VersoBlueprint.Commands.Summary
import VersoBlueprint.Commands.Bibliography
import VersoBlueprint.Informal.Code
import VersoBlueprint.Informal.Block
import VersoBlueprint.Informal.Uses
import VersoBlueprint.DocGenNameRender
import VersoBlueprint.Lean
import VersoBlueprint.NameParsing
import VersoBlueprint.PreviewCache
import VersoBlueprint.Resolve
import VersoBlueprint.StyleSwitcher
import VersoBlueprint.TexPrelude
import VersoBlueprint.Widget
import VersoBlueprint.Profiling

set_option doc.verso true
