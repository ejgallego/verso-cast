/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module

public import Verso.Doc

public section

namespace VersoCast.Fingerprint

open Verso Verso.Doc

/-- Existing document values, not a serialized document or a new wire format. -/
abbrev Value (g : Genre) := Doc.Block g ⊕ Array (Doc.Inline g)

variable {g : Genre}

private partial def blockHash [Hashable g.Inline] [Hashable g.Block] : Doc.Block g → UInt64
  | .para content => mixHash 101 (hash content)
  | .code text => mixHash 103 (hash text)
  | .ul items => mixHash 107 <| items.foldl (init := 7) fun acc item =>
      mixHash acc (blocksHash item.contents)
  | .ol start items => mixHash 109 <| mixHash (hash start) <|
      items.foldl (init := 7) fun acc item => mixHash acc (blocksHash item.contents)
  | .dl items => mixHash 113 <| items.foldl (init := 7) fun acc item =>
      mixHash acc (mixHash (hash item.term) (blocksHash item.desc))
  | .blockquote content => mixHash 127 (blocksHash content)
  | .concat content => mixHash 131 (blocksHash content)
  | .other extension content => mixHash 137 (mixHash (hash extension) (blocksHash content))
where
  blocksHash (content : Array (Doc.Block g)) : UInt64 :=
    content.foldl (init := 7) fun acc block => mixHash acc (blockHash block)

/-- Structural hash: constructors, ordered children and complete extension data.
Equal values must hash equally; equal hashes are never evidence of equality.
This is a session-local accelerator, not a persistent or cryptographic digest. -/
def contentHash [Hashable g.Inline] [Hashable g.Block] : Value g → UInt64
  | .inl block => mixHash 139 (blockHash block)
  | .inr title => mixHash 149 (hash title)

/-- Full serialized-content key for callers that do not retain identity state. -/
def canonicalKey [Lean.ToJson g.Inline] [Lean.ToJson g.Block] : Value g → String
  | .inl block => (Lean.toJson block).compress
  | .inr title => (Lean.toJson title).compress

/-- Only the current document's distinct fingerprinted values are retained.
The monotonically increasing counter prevents retired IDs from being reused.
Keep this state per mounted preview, and advance it as part of React state. -/
structure State (g : Genre) where
  private buckets : Std.HashMap UInt64 (Array (Value g × Nat)) := {}
  private nextId : Nat := 0
  deriving Inhabited

private def findId? [BEq g.Inline] [BEq g.Block] (entries : Array (Value g × Nat)) (value : Value g) : Option Nat :=
  entries.findSome? fun (prior, id) => if prior == value then some id else none

/-- Pure transition. Hash collisions use exact typed equality, including when
the two colliding values only appear in different updates. Duplicate contents
share a token; the renderer separately disambiguates sibling occurrences.
The optional hasher is for collision tests; use one hasher consistently. -/
def State.advance [BEq g.Inline] [BEq g.Block] [Hashable g.Inline] [Hashable g.Block] (previous : State g) (values : Array (Value g))
    (fingerprint : Value g → UInt64 := contentHash) : State g := Id.run do
  let mut current : State g := { nextId := previous.nextId }
  for value in values do
    let bucket := fingerprint value
    let entries := current.buckets.getD bucket #[]
    if (findId? entries value).isSome then continue
    let id := (findId? (previous.buckets.getD bucket #[]) value).getD current.nextId
    current := {
      buckets := current.buckets.insert bucket (entries.push (value, id))
      nextId := max current.nextId (id + 1)
    }
  return current

/-- Look up a value in the state prepared for the current document. -/
def State.key? [BEq g.Inline] [BEq g.Block] [Hashable g.Inline] [Hashable g.Block] (state : State g) (value : Value g)
    (fingerprint : Value g → UInt64 := contentHash) : Option String :=
  (findId? (state.buckets.getD (fingerprint value) #[]) value).map fun id => s!"token:{id}"

/-- Missing values indicate that the caller supplied another document's state. -/
def State.key [BEq g.Inline] [BEq g.Block] [Hashable g.Inline] [Hashable g.Block] (state : State g) (value : Value g) : String :=
  match state.key? value with
  | some key => key
  | none => panic! "VersoCast: fingerprint state does not contain this document value"

/-- Useful for bounded-retention tests; removed contents are not kept in history. -/
def State.size (state : State g) : Nat :=
  state.buckets.fold (init := 0) fun count _ entries => count + entries.size

end VersoCast.Fingerprint
