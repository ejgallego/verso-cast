/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Blog
public import VersoCastTests.Blog.Fixture
meta import Vir.Attributes

public section
namespace VersoCastTests.Blog
open Verso Verso.Doc Verso.Genre VersoCast Lean.Vir Lean.Vir.React
open Verso.Genre.Blog
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

/-- Publication presentation belongs to this client, not generic Cast. -/
@[vir_export] def View (idPrefix : String) : ReactM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let base ← VersoCast.Blog.createRenderers Post styles
  let handlers : Renderer.Renderers Post := { base with
    renderPart? := fun key metadata _part renderDefault => do
      let header : Renderer.HeaderRenderer := fun level props title => do
        if let some id := metadata.htmlId then
          Js.Object.set props (← js#"id") (← JsValue.ofString (idPrefix ++ id))
        Node.createElement (← ElementType.tag (← JsValue.ofString s!"h{level}")) props
          (← Js.Array.ofArray title)
      return some (← <div key={← JsValue.ofString key}><p data-post-byline="true">
        {ProofWidgets.Html.text byline}</p>{renderDefault (some header)}</div>) }
  FunctionComponent.ofLean fun _ => Renderer.render styles document (renderers := handlers)

/-- The same public adapter works for Page and preserves unsupported children. -/
@[vir_export] def renderPage : ReactM (Js Node) := do
  let styles ← Renderer.Styles.create
  let handlers ← VersoCast.Blog.createRenderers Page styles
  let input : Part Page := .mk #[.text "Page"] "Page" none #[
    .other (.htmlDiv "page-panel") #[.para #[.other (.htmlSpan "page-badge") #[.text "Page badge"]]],
    .other (.component `Missing .null) #[.para #[.text "Fallback children"]]
  ] #[]
  Renderer.render styles input (renderers := handlers)

end VersoCastTests.Blog
