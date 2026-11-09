import Lake
open Lake DSL

require verso from git "https://github.com/leanprover/verso" @
  "f7a4dc6867f8df27778b2b320763ec9e3b7be070"
require lean_vir from git "https://github.com/ejgallego/lean-vir" @
  "5a5614b802e1eb15607b885f84d11cbd8cd4fd21"

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

lean_exe «cast-blog-html» where
  srcDir := "tests"
  root := `BlogComparison

-- Native server-side writer fixture; no browser bindings enter its import graph.
lean_exe «cast-codec-input» where
  srcDir := "tests"
  root := `JsonSafeInput

-- Optional live example; the renderer library does not import Infoview.
lean_lib VersoCastExamples where
  srcDir := "examples"
  roots := #[`VersoCastDemo, `VersoCastShowcase]
  requiresModuleSystem := true
