/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
import VersoCastTests.JsonSafe

public def main : IO Unit := do
  let part := VersoCastTests.JsonSafe.sample
  IO.println (VersoCast.Manual.Codec.encodeDocument part)
