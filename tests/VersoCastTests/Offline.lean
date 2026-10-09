/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast
public import VersoCastTests.Fixture
meta import Vir.Attributes

public section
namespace VersoCastTests.Offline
open VersoCast Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def renderers (highlight : FunctionComponent (Props.WithData Unit))
    (data : JSL Unit) (visits : RuntimeRef (Nat × Nat)) (idPrefix : String) : Renderer.Renderers Fixture.genre where
  renderInline? := fun key extension children => do
    match extension with
    | .highlight =>
      visits.modify fun (inlines, blocks) => (inlines + 1, blocks)
      let props ← Props.WithData.make data
      Js.Object.set (Props.WithData.asProps props) (← JsValue.ofString "key") (← JsValue.ofString key)
      return some (← Node.functionComponent highlight props (← Js.Array.ofArray (← children ())))
    | .hidden =>
      let props ← js%{ "key" := (← JsValue.ofString key) }
      return some (← Node.fragment props (← Js.Array.empty))
    | .unsupported => return none
  renderBlock? := fun key attributes extension children => do
    match extension with
    | .notice =>
      visits.modify fun (inlines, blocks) => (inlines, blocks + 1)
      let props ← attributes "notice" (← Renderer.Style.unsupported)
      return some (← <aside @props={props}>{Js.Array.ofArray (← children ())}</aside>)
    | .hidden =>
      let props ← js%{ "key" := (← JsValue.ofString key) }
      return some (← Node.fragment props (← Js.Array.empty))
    | .unsupported => return none
  renderPart? := fun key (metadata : String) _part renderDefault => do
    let header : Renderer.HeaderRenderer := fun level props title => do
      Js.Object.set props (← JsValue.ofString "id") (← JsValue.ofString s!"{idPrefix}section-{metadata}")
      let numberText ← Node.text (← JsValue.ofString (if metadata == "root" then "1. " else "1.1. "))
      let title := #[numberText] ++ title
      -- This fixture has two levels. Cast passes the level and fresh heading
      -- attributes; no section traversal is duplicated in this extension.
      if level == 1 then return ← <h1 @props={props}>{Js.Array.ofArray title}</h1>
      else return ← <h2 @props={props}>{Js.Array.ofArray title}</h2>
    return some (← <div key={← JsValue.ofString key} data-fixture-section={← JsValue.ofString metadata}>
      {renderDefault (some header)}
    </div>)

@[vir_export] def View (idPrefix : String) : ReactM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let initial ← JsValue.ofString "ready"
  let clicked ← JsValue.ofString "clicked"
  let data ← LeanRef.toJSL ()
  let visits ← RuntimeRef.new (0, 0)
  -- The extension creates a normal component boundary. Its hook is evaluated
  -- by React SSR, not by the document traversal or an extension callback.
  let highlight ← FunctionComponent.ofLean fun (props : Js (Props.WithData Unit)) => do
    js#let (state, setter) ← Hooks.useState (α := String) initial
    let click ← Js.Function.ofLeanVoid fun (_ : Js SyntheticEvent) =>
      Js.Function.callVoid setter (SetStateAction.ofValue clicked)
    return ← <mark data-cast-initial={state} onClick={click}
        title="Click to exercise retained React state">{Props.WithData.children props}</mark>
  let handlers := renderers highlight data visits idPrefix
  FunctionComponent.ofLean fun _ => do
    visits.set (0, 0)
    let rendered ← Renderer.render styles Fixture.document (renderers := handlers)
    let (inlines, blocks) ← visits.get
    return ← <div data-cast-inline-visits={← JsValue.ofString (toString inlines)}
        data-cast-block-visits={← JsValue.ofString (toString blocks)}>{pure rendered}</div>

/-- Shared frozen style values must be borrowed, never used as mutable props. -/
@[vir_export] def propsProbe (style : Js Props) : ReactM (Js Node) := do
  let styles ← Renderer.Styles.create
  let attributes := #[
    Renderer.Attribute.of styles.strings.keys.style style,
    Renderer.Attribute.of styles.strings.keys.className (← JsValue.ofString "caller-class") ]
  let root ← Renderer.render styles Fixture.document {
    attributes := attributes ++ #[
      Renderer.Attribute.of (← JsValue.ofString "id") (← JsValue.ofString "caller-id"),
      Renderer.Attribute.of styles.strings.keys.dataVersoChangedBlockCount (← JsValue.ofString "caller-cannot-override") ] }
  let math ← Renderer.renderMath styles "math-key" .inline "x < y"
    (attributes ++ #[Renderer.Attribute.of styles.strings.keys.key (← JsValue.ofString "caller-cannot-override")])
  let display ← Renderer.renderMath styles "display-key" .display "x^2" attributes
  return ← <div>{pure root}{pure math}{pure display}</div>

/-- Wide extension trees require one dispatch per visited extension. Hidden
children are not visited; this test uses no hashing/JSON identity capability. -/
@[vir_export] def extensionWork (count : Nat) : ReactM Nat := do
  let styles ← Renderer.Styles.create
  let visits ← RuntimeRef.new (0 : Nat)
  let handlers : Renderer.Renderers Fixture.genre := {
    renderBlock? := fun key _ extension children => do
      visits.modify (· + 1)
      let props ← Js.Object.empty
      Js.Object.set props styles.strings.keys.key (← JsValue.ofString key)
      let nodes ← match extension with
        | .hidden => Js.Array.empty
        | _ => Js.Array.ofArray (← children ())
      return some (← Node.fragment props nodes) }
  let hidden : Verso.Doc.Block Fixture.genre := .other .hidden #[.other .notice #[]]
  let document : Verso.Doc.Part Fixture.genre := .mk #[] "" none
    (Array.replicate count (.other .notice #[hidden])) #[]
  let _ ← Renderer.render styles document (renderers := handlers)
  visits.get

end VersoCastTests.Offline
