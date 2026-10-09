import Lake
open Lake DSL

require «verso-cast» from "../.."

package cast_consumer

@[default_target]
lean_lib Consumer where
  requiresModuleSystem := true

lean_exe consumer where
  root := `Main
