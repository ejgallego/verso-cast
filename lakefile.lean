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
