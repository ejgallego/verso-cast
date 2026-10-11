import Lake
open Lake DSL

require «verso-cast-slides» from "../../packages/slides"

package cast_slides where
  leanOptions := #[⟨`experimental.module, true⟩]

@[default_target]
lean_lib CastSlides where
  requiresModuleSystem := true

lean_exe «standard-slides» where
  root := `Standard
