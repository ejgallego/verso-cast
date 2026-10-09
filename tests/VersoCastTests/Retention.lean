/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Manual
meta import Vir.Attributes

public section
namespace VersoCastTests.Retention
open Verso Verso.Doc VersoCast Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def paragraph (text : String) : Block Genre.Manual := .para #[.text text]

private def counter (label body : String) : Block Genre.Manual :=
  .other { name := `Retention.counter, data := .str label } #[paragraph body]

private def document (phase : Nat) : Part Genre.Manual :=
  let a := counter "A" (if phase ≤ 2 then "A body" else "A edited body")
  let b := counter "B" "B body"
  let inserted := paragraph "Inserted ordinary block"
  let content := match phase with
    | 0 => #[a, b]
    | 1 => #[inserted, a, b]
    | 2 | 3 => #[b, a, inserted]
    | 4 => #[a]
    | 5 => #[b, a]
    | _ => #[a, counter "A" "Duplicate A body"]
  .mk #[.text "Retained document identities"] "Retained document identities" none content #[]

private structure State where
  phase : Nat
  document : Part Genre.Manual
  identities : Fingerprint.State Genre.Manual

@[vir_export] def View : ReactM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let zero ← JsValue.ofFloat 0
  let one ← JsValue.ofFloat 1
  let increment ← Js.Function.ofLean fun (previous : Js Float) => Js.Number.add previous one
  let counterView ← FunctionComponent.ofLean fun (props : Js (Props.WithData String)) => do
    let label ← LeanRef.fromJSL (← Props.WithData.data props)
    js#let (count, setter) ← Hooks.useState (α := Float) zero
    let click ← Js.Function.ofLeanVoid fun (_ : Js SyntheticEvent) =>
      Js.Function.callVoid setter (SetStateAction.ofUpdater increment)
    return ← <div data-counter={← JsValue.ofString label}>
      <button onClick={click}>Increment {Node.text (← JsValue.ofString label)}</button>
      <output>{pure count}</output>
      {Props.WithData.children props}
    </div>
  let handlers : Renderer.Renderers Genre.Manual := {
    Manual.renderers with
    -- Rendering uses the prepared typed state, not serialized content keys.
    fingerprint := fun _ => none
    blockIdentity? := fun extension => match extension.data with
      | .str label => some label
      | _ => none
    renderBlock? := fun _key attributes extension children => do
      let .str label := extension.data | return none
      let props ← Props.WithData.make (← LeanRef.toJSL label)
      let leaf ← Node.functionComponent counterView props (← Js.Array.ofArray (← children ()))
      let wrapper ← attributes "counter" styles.unsupported
      return some (← <section @props={wrapper}>{pure leaf}</section>) }
  let first := document 0
  let initialState : State := {
    phase := 0
    document := first
    identities := Renderer.prepareIdentities default first handlers }
  let initial ← LeanRef.toJSL initialState
  let advance ← Js.Function.ofLean fun (previous : JSL State) => do
    let previous ← LeanRef.fromJSL previous
    let phase := min (previous.phase + 1) 6
    let next := document phase
    -- One pure transition accepts the document and its corresponding identities.
    let nextState : State := {
      phase
      document := next
      identities := Renderer.prepareIdentities previous.identities next handlers }
    LeanRef.toJSL nextState
  FunctionComponent.ofLean fun _ => do
    js#let (state, setter) ← Hooks.useState (α := LeanRef.Handle State) initial
    let state ← LeanRef.fromJSL state
    let next ← Js.Function.ofLeanVoid fun (_ : Js SyntheticEvent) =>
      Js.Function.callVoid setter (SetStateAction.ofUpdater advance)
    let rendered ← Renderer.render styles state.document {
      fingerprint? := some (fun value => some (state.identities.key value)) } handlers
    return ← <div data-phase={← JsValue.ofString (toString state.phase)}>
      <button data-next="true" onClick={next}>Next document edit</button>
      {pure rendered}
    </div>

end VersoCastTests.Retention
