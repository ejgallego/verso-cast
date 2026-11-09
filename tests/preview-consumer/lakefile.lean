import Lake
open Lake DSL

require «verso-cast» from "../.."

package cast_preview_consumer

@[default_target]
lean_lib PreviewConsumer where
  requiresModuleSystem := true
