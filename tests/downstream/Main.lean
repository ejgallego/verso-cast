module
public import VersoCast.Fingerprint

open Verso VersoCast

-- Fingerprinting is opt-in. Verso provides equality but no hash for Empty.
private instance : Hashable Doc.Genre.none.Inline where
  hash value := nomatch value

private instance : Hashable Doc.Genre.none.Block where
  hash value := nomatch value

public def main : IO Unit := do
  let value : Fingerprint.Value Doc.Genre.none := .inl (.para #[.text "Native import"])
  let identities := (default : Fingerprint.State Doc.Genre.none).advance #[value]
  unless identities.size == 1 && (identities.key? value).isSome do
    throw <| IO.userError "downstream identity API regression"
  IO.println "downstream native identity helpers: PASS"
