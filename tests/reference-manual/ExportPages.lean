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
private def exportPage (name : String) (part : Verso.Doc.Part Verso.Genre.Manual) : IO Unit := do
  IO.FS.writeFile s!".cast-preview/{name}.json" (Lean.toJson part).compress
  IO.FS.writeFile s!".cast-preview/{name}.typed.json" (VersoCast.Manual.Codec.encodeDocument part)

def main : IO Unit := do
  IO.FS.createDirAll ".cast-preview"
  exportPage "intro" (%doc Manual.Intro)
  exportPage "empty" (%doc Manual.BasicTypes.Empty)
  exportPage "products" (%doc Manual.BasicTypes.Products)
  exportPage "int" (%doc Manual.BasicTypes.Int)
  exportPage "monads" (%doc Manual.Monads.Syntax)
  exportPage "structures" (%doc Manual.Language.InductiveTypes.Structures)
