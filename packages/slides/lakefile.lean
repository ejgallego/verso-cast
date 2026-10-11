import Lake
open Lake DSL

require «verso-cast» from "../.."
require «verso-slides» from git "https://github.com/leanprover/verso-slides" @
  "268257a4fbdac12c77be726213b51c3ce3a1d41e"

package «verso-cast-slides» where
  leanOptions := #[⟨`experimental.module, true⟩]

@[default_target]
lean_lib VersoCastSlides where
  requiresModuleSystem := true
