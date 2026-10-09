import Lake
open Lake DSL

require verso from git "https://github.com/leanprover/verso" @
  "01a09f320122475119588526857a07d218aef600"
require lean_vir from git "https://github.com/ejgallego/lean-vir" @
  "aa465b873387a0bf46669031da1af99f59b0f3b9"

package «verso-cast» where
  leanOptions := #[⟨`experimental.module, true⟩]

@[default_target]
lean_lib VersoCast where
  requiresModuleSystem := true

@[test_driver]
lean_lib VersoCastTests where
  srcDir := "tests"
  requiresModuleSystem := true

-- Test/demo assets come from VIR's locked resource, not a locally built Wasm.
lean_exe «cast-assets» where
  srcDir := "tests"
  root := `PrepareAssets

-- Pure Verso backend for the illustrative offline comparison (no VIR host externs).
lean_exe «cast-standard-html» where
  srcDir := "tests"
  root := `OfflineComparison

-- Optional live example; the renderer library does not import Infoview.
lean_lib VersoCastExamples where
  srcDir := "examples"
  roots := #[`VersoCastDemo, `VersoCastShowcase]
  requiresModuleSystem := true
