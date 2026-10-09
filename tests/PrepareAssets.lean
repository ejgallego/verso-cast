/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
import Lean.Data.Json
import Vir.Resources.Runtime

def main : IO Unit := do
  let bundle := Vir.Resources.Runtime.bundle
  let some wasmPath := bundle.entryPath? "wasm"
    | throw <| IO.userError "VIR runtime resource has no wasm role"
  let some wasm := bundle.file? wasmPath
    | throw <| IO.userError "VIR runtime resource has no wasm payload"
  unless bundle.descriptor.compatibility.leanRevision == Lean.githash do
    throw <| IO.userError "VIR runtime resource does not match this Lean compiler"
  IO.FS.createDirAll ".vir"
  IO.FS.writeBinFile ".vir/runtime.wasm" wasm.bytes
  let metadata := Lean.Json.mkObj [
    ("contentId", Lean.toJson bundle.contentId),
    ("leanRevision", Lean.toJson bundle.descriptor.compatibility.leanRevision),
    ("virVersion", Lean.toJson bundle.descriptor.compatibility.virVersion),
    ("sha256", Lean.toJson <|
      (bundle.descriptor.files.find? (·.path == wasmPath)).map (·.sha256))]
  IO.FS.writeFile ".vir/runtime.json" metadata.compress
  IO.println s!"Prepared exact VIR runtime {bundle.contentId}"
