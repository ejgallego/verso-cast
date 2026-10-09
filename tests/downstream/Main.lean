module
public import VersoCast.Fingerprint

open Verso VersoCast

public def main : IO Unit := do
  let value : Fingerprint.Value := .inl (.para #[.text "Native import"])
  let identities := (default : Fingerprint.State).advance #[value]
  unless identities.size == 1 && (identities.key? value).isSome do
    throw <| IO.userError "downstream identity API regression"
  IO.println "downstream native identity helpers: PASS"
