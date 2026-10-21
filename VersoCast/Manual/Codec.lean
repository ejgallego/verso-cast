/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoManual.Basic
public import Vir.Package.JsonSafeWriter
meta import Vir.Compiler.Interface.JsonSafeWriter
meta import Vir.Compiler.Interface.LibraryAdapters

namespace VersoCast.Manual.Codec

/-- Checked construction for the codec's property entries. Name components are
preserved; invalid names fail and the last value for a duplicate key wins. -/
public def propertiesFromEntries (entries : Array (Lean.Name × String)) :
    Except String (Verso.NameMap String) := do
  let mut map : Verso.NameMap String := {}
  for (key, value) in entries do
    if h : Verso.NameMap.isPublic key then
      map := map.insert key value h
    else throw "Manual properties require a nonempty all-string Name chain"
  return map

/-- Property entries in the map's iteration order, without stringifying names. -/
public def propertiesToEntries (map : Verso.NameMap String) : Array (Lean.Name × String) := Id.run do
  let mut entries := #[]
  for (key, value) in map do
    entries := entries.push (key.toName, value)
  return entries

run_meta do
  let .forallE _ wire outcome _ := (← Lean.getConstInfo ``propertiesFromEntries).type
    | Lean.throwError "unexpected property decoder type"
  let #[_, source] := outcome.getAppArgs
    | Lean.throwError "unexpected property decoder result"
  Vir.Interface.registerClosedLibraryAdapter source wire ``propertiesFromEntries ``propertiesToEntries

-- An opt-in, version-matched VIR wire format, not Verso's ToJson schema.
-- The generated public encodeDocument traverses Part directly into JSON text.
-- Select json-safe-v1 at the receiving typed call; normal calls are unchanged.
run_elab do
  Vir.Interface.JsonSafeWriter.generate `VersoCast.Manual.Codec.encodeDocument
    (Lean.mkApp (Lean.mkConst ``Verso.Doc.Part) (Lean.mkConst ``Verso.Genre.Manual))

end VersoCast.Manual.Codec
