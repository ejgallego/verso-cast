import Lake
open Lake DSL

require «verso-cast» from "../.."
require «verso-slides» from git "https://github.com/leanprover/verso-slides" @
  "2d8e2ccef9876efe8194a6818b46b64f37da515f"

package «verso-cast-slides» where
  leanOptions := #[⟨`experimental.module, true⟩]

@[default_target]
lean_lib VersoCastSlides where
  requiresModuleSystem := true
