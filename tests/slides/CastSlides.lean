/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast
public import VersoCast.Renderer.Table
public import CastSlides.Fixture
meta import Vir.Attributes

public section
namespace CastSlides
open Verso Verso.Doc VersoSlides VersoCast Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def blockName : BlockExt → String
  | .notes => "Slides.notes" | .fragment .. => "Slides.fragment"
  | .attr .. => "Slides.attr" | .wrap .. => "Slides.wrap" | .ofHtml .. => "Slides.ofHtml"
  | .leanCode .. => "Slides.leanCode" | .slideCode .. => "Slides.slideCode"
  | .otherLanguage .. => "Slides.otherLanguage" | .css .. => "Slides.css"
  | .diagram .. => "Slides.diagram" | .animate .. => "Slides.animate" | .table .. => "Slides.table"

private def inlineName : InlineExt → String
  | .fragment .. => "Slides.fragment" | .styled .. => "Slides.styled"
  | .image .. => "Slides.image" | .ofHtml .. => "Slides.ofHtml"
  | .leanCode .. => "Slides.leanCode" | .slideCode .. => "Slides.slideCode" | .name .. => "Slides.name"

/-- A bounded preview adapter, not a Reveal.js presenter. Construction uses
fresh props and native strings; it never inspects/clones completed React nodes. -/
private def renderers (styles : Renderer.Styles) : ReactM (Renderer.Renderers Slides) := do
  let tables ← Renderer.Table.Styles.create
  let fragmentKey ← js#"data-fragment-index"
  let attrs := fun props (fields : Array (String × String)) => do
    for (key, value) in fields do
      if key == "class" then
        Renderer.appendClass props styles.strings.keys.className (← JsValue.ofString s!" {value}")
      else Js.Object.set props (← JsValue.ofString key) (← JsValue.ofString value)
  return {
    blockName, inlineName
    renderInline? := fun key extension children => do
      match extension with
      | .fragment style index =>
        let props ← js%{ "key" := (← JsValue.ofString key),
          "className" := (← JsValue.ofString (fragmentClass style)) }
        if let some index := index then Js.Object.set props fragmentKey (← JsValue.ofString (toString index))
        return some (← <span @props={props}>{Js.Array.ofArray (← children ())}</span>)
      | _ => return none
    renderBlock? := fun key attributes extension children => do
      match extension with
      | .notes =>
        let props ← attributes "notes" styles.blockquote
        Renderer.appendClass props styles.strings.keys.className (← js#" notes")
        return some (← <aside @props={props}>{Js.Array.ofArray (← children.render ())}</aside>)
      | .fragment style index =>
        let suffix ← JsValue.ofString s!" {fragmentClass style}"
        let index := index.map toString
        let nodes ← children.renderWith fun props => do
          Renderer.appendClass props styles.strings.keys.className suffix
          if let some index := index then Js.Object.set props fragmentKey (← JsValue.ofString index)
        let props ← js%{ "key" := (← JsValue.ofString key) }
        return some (← Node.fragment props (← Js.Array.ofArray nodes))
      | .attr fields =>
        let nodes ← children.renderWith (fun props => attrs props fields)
        let props ← js%{ "key" := (← JsValue.ofString key) }
        return some (← Node.fragment props (← Js.Array.ofArray nodes))
      | .wrap fields =>
        let props ← attributes "wrap" styles.part
        attrs props fields
        return some (← <div @props={props}>{Js.Array.ofArray (← children.render ())}</div>)
      | .table columns style =>
        -- Row headers/stripes/animation need their own qualification. Decline
        -- rather than pretending the simpler table helper implements them.
        if style.rowHeaders || style.stripedRows || style.stripedCols then return none
        let some cells := children.listItems? () | return none
        return ← Renderer.Table.render tables (← attributes "table" tables.table) columns style.colHeaders cells
      | _ => return none
    renderPart? := fun key metadata _part renderDefault => do
      let props ← js%{ "key" := (← JsValue.ofString key),
        "data-slide-vertical" := (← JsValue.ofBool (metadata.vertical.getD false)) }
      if let some color := metadata.backgroundColor then
        Js.Object.set props (← js#"data-background-color") (← JsValue.ofString color)
        Js.Object.set props styles.strings.keys.style (← js%{ "backgroundColor" := (← JsValue.ofString color) })
      return some (← <div @props={props}>{renderDefault none}</div>) }

/-- Normal React shell state selects a source heading; the document renderer
owns neither presentation navigation nor a second imperative DOM runtime. -/
@[vir_export] def View : ReactM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let handlers ← renderers styles
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
