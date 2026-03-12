import Lake
open Lake DSL

-- While the split is in progress, the extracted blueprint package depends on
-- the parent repo root, which remains a checkout of Verso.
require verso from ".."

-- Blueprints depend directly on Mathlib.
require mathlib from git "https://github.com/leanprover-community/mathlib4"@"v4.29.0-rc3"

-- These are needed as transitive dependencies of Verso and for docs/tooling
-- that are part of the blueprint build.
require subverso from git "https://github.com/leanprover/subverso"@"main"
require MD4Lean from git "https://github.com/acmepjz/md4lean"@"main"
require proofwidgets from git "https://github.com/leanprover-community/ProofWidgets4"@"v0.0.86"

package VersoBlueprint where
  precompileModules := false
  leanOptions := #[⟨`experimental.module, true⟩]

-- Blueprint core library.
@[default_target]
lean_lib VersoBlueprint where
  srcDir := "src/verso-blueprint"
  roots := #[`VersoBlueprint]

-- An example of a "math blueprint" project built in Verso.
lean_lib Noperthedron where
  srcDir := "test-projects/Noperthedron"
  roots := #[`Authors, `Contents, `Chapters, `Noperthedron, `Bibliography, `Macros]

@[default_target]
lean_exe noperthedron where
  srcDir := "test-projects/Noperthedron"
  root := `Main
  supportInterpreter := true

-- Port of the Sphere Packing TeX blueprint to Verso Blueprints.
lean_lib SpherePackingBlueprint where
  srcDir := "test-projects/Sphere-Packing-Lean"
  roots := #[`SpherePackingBlueprint]

@[default_target]
lean_exe spherepackingblueprint where
  srcDir := "test-projects/Sphere-Packing-Lean"
  root := `SpherePackingBlueprintMain
  supportInterpreter := true

@[default_target]
lean_lib Tests where
  srcDir := "src/tests"

@[test_driver]
lean_exe «verso-tests» where
  root := `TestMain
  srcDir := "src/tests"
  supportInterpreter := true
