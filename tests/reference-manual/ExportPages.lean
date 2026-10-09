/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
import Manual.Intro
import Manual.BasicTypes.Empty
import Verso.Doc.Name

-- Optional browser-validation inputs: actual elaborated pages, before traversal.
def main : IO Unit := do
  IO.FS.createDirAll ".cast-preview"
  IO.FS.writeFile ".cast-preview/intro.json" (Lean.toJson (%doc Manual.Intro)).compress
  IO.FS.writeFile ".cast-preview/empty.json" (Lean.toJson (%doc Manual.BasicTypes.Empty)).compress
