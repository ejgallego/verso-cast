/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
import Manual.Intro
import Manual.BasicTypes.Empty
import Manual.BasicTypes.Products
import Manual.BasicTypes.Int
import Manual.Monads.Syntax
import Manual.Language.InductiveTypes.Structures
import Verso.Doc.Name

-- Exercise the same retained package that the infoview RPC emits, rather than
-- only testing a freshly generated :vir facet with potentially newer imports.
#eval show Lean.CoreM Unit from do
  let env ← Lean.getEnv
  let some idx := env.getModuleIdxFor? `CastManualPreview.createComponent
    | throwError "No manual widget owner"
  let some (_, _, package) := (Lean.Vir.Infoview.widgetPackages.getModuleEntries env idx).find?
      (fun (name, _, _) => name == `CastManualPreview.createComponent)
    | throwError "No retained manual widget package"
  let .ok bytes := Vir.GeneratePackage.emitPackage package.closure package.manifest
    | throwError "Could not emit the retained widget package"
  IO.FS.createDirAll ".cast-preview"
  IO.FS.writeBinFile ".cast-preview/widget.irpkg" bytes

-- Optional browser-validation inputs: actual elaborated pages, before traversal.
def main : IO Unit := do
  IO.FS.createDirAll ".cast-preview"
  IO.FS.writeFile ".cast-preview/intro.json" (Lean.toJson (%doc Manual.Intro)).compress
  IO.FS.writeFile ".cast-preview/empty.json" (Lean.toJson (%doc Manual.BasicTypes.Empty)).compress
  IO.FS.writeFile ".cast-preview/products.json" (Lean.toJson (%doc Manual.BasicTypes.Products)).compress
  IO.FS.writeFile ".cast-preview/int.json" (Lean.toJson (%doc Manual.BasicTypes.Int)).compress
  IO.FS.writeFile ".cast-preview/monads.json" (Lean.toJson (%doc Manual.Monads.Syntax)).compress
  IO.FS.writeFile ".cast-preview/structures.json" (Lean.toJson (%doc Manual.Language.InductiveTypes.Structures)).compress
