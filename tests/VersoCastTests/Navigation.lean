/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast
public import VersoCastTests.Fixture
meta import Vir.Attributes

public section
namespace VersoCastTests.Navigation
open Verso Verso.Doc VersoCast Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def sectionChain : Nat → Part Fixture.genre
  | 0 => .mk #[.text "Deep leaf"] "Deep leaf" (some "leaf")
      #[Fixture.paragraph "Deep content"] #[]
  | n + 1 => .mk #[.text s!"Section {n + 1}"] s!"Section {n + 1}"
      (some s!"section-{n + 1}") #[] #[sectionChain n]

private def document : Part Fixture.genre := .mk #[.text "Navigation"] "Navigation"
  (some "root") #[
    Fixture.paragraph "Ordinary paragraph",
    .concat #[.concat #[], .concat #[Fixture.paragraph "Fragment A", Fixture.paragraph "Fragment B"],
      Fixture.paragraph "Fragment C", .other .hidden #[Fixture.paragraph "HIDDEN FRAGMENT"]],
    .ul #[.mk #[Fixture.paragraph "List paragraph", .ol 2 #[.mk #[Fixture.paragraph "Nested list paragraph"]]]],
    .ol 7 #[.mk #[Fixture.paragraph "Ordered paragraph"]],
    .dl #[.mk #[.text "Term"] #[Fixture.paragraph "Description paragraph"]],
    .blockquote #[Fixture.paragraph "Quoted paragraph"],
    .other .notice #[Fixture.paragraph "Notice paragraph"],
    .other .unsupported #[Fixture.paragraph "Fallback paragraph"],
    .other .hidden #[Fixture.paragraph "HIDDEN BLOCK"],
    .ol (-2) #[.mk #[Fixture.paragraph "Negative start"]],
    .ol 0 #[.mk #[Fixture.paragraph "Zero start"]],
    .ol 4 #[.mk #[Fixture.paragraph "Positive start"]]
  ] #[sectionChain 6]

private def renderers : Renderer.Renderers Fixture.genre where
  renderBlock? := fun key attributes extension children => do
    match extension with
    | .hidden =>
      let props ← js%{ "key" := (← JsValue.ofString key) }
      return some (← Node.fragment props (← Js.Array.empty))
    | .notice =>
      let props ← attributes "notice" (← Renderer.Style.unsupported)
      return some (← <aside @props={props}>{Js.Array.ofArray (← children ())}</aside>)
    | .unsupported => return none
  renderPart? := fun _key (label : String) _part renderDefault => do
    let header : Renderer.HeaderRenderer := fun level props title => do
      Js.Object.set props (← JsValue.ofString "id") (← JsValue.ofString s!"nav-{label}")
      Node.createElement (← ElementType.tag (← JsValue.ofString s!"h{level}"))
        props (← Js.Array.ofArray title)
    return some (← renderDefault (some header))

/-- Focus is navigation state, not part of the document's React identity. -/
@[vir_export] def render (focusPath : String) : ReactM (Js Node) := do
  let styles ← Renderer.Styles.create
  Renderer.render styles document {
    focus := if focusPath.isEmpty then none else some focusPath
    changedIds := #["part-root-block-1-block-1-block-0"]
  } renderers

end VersoCastTests.Navigation
