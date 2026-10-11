/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCastSlides
public import CastSlides.Fixture
meta import Vir.Attributes

public section
namespace CastSlides
open Verso Verso.Doc VersoSlides VersoCast Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

/-- Normal React shell state selects a source heading; the document renderer
owns neither presentation navigation nor a second imperative DOM runtime. -/
@[vir_export] def View : ReactM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let handlers ← VersoCast.Slides.createRenderers styles previewImageUrl?
  let initial ← LeanRef.toJSL (0 : Nat)
  let next ← Js.Function.ofLean fun (previous : JSL Nat) => do
    LeanRef.toJSL (min document.subParts.size ((← LeanRef.fromJSL previous) + 1))
  let previous ← Js.Function.ofLean fun (previous : JSL Nat) => do
    LeanRef.toJSL ((← LeanRef.fromJSL previous) - 1)
  FunctionComponent.ofLean fun _ => do
    js#let (value, setter) ← Hooks.useState (α := LeanRef.Handle Nat) initial
    let selected : Nat ← LeanRef.fromJSL value
    let moveNext ← Js.Function.ofLeanVoid fun (_ : Js SyntheticEvent) =>
      Js.Function.callVoid setter (SetStateAction.ofUpdater next)
    let movePrevious ← Js.Function.ofLeanVoid fun (_ : Js SyntheticEvent) =>
      Js.Function.callVoid setter (SetStateAction.ofUpdater previous)
    let focus := if selected == 0 then none else some s!"part-root-part-{selected - 1}-heading"
    let node ← Renderer.render styles document { focus } handlers
    return ← <div>
      <nav aria-label="Slide preview"><button onClick={movePrevious}>Previous</button>
        <output data-slide-selected={← JsValue.ofString (toString selected)}>
          {ProofWidgets.Html.text (if selected == 0 then "Whole deck" else s!"Slide {selected}")}</output>
        <button onClick={moveNext}>Next</button></nav>
      {pure node}</div>

end CastSlides
