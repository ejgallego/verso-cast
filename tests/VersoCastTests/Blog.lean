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
    .other (.component `Missing .null) #[.para #[.text "Fallback children"]],
    .other (.docstringSection 0) #[
      .para #[.text "Page ", .emph #[.text "docstring"]], .para #[.text "Page section body"]],
    .other (.docstringSection 1) #[.code "Missing title survives", .para #[.text "Malformed body survives"]],
    .other (.docstringSection 2) #[],
    .other (.docstringSection 6) #[.para #[.text "Unsupported level survives"]]
  ] #[]
  Renderer.render styles input {
    focus := some "part-root-block-2-block-0", changedIds := #["part-root-block-2-block-0"] }
    (renderers := handlers)

/-- Title inspection is lazy; supported and fallback children render once. -/
@[vir_export] def sectionWork (mode : Nat) : ReactM Nat := do
  let styles ← Renderer.Styles.create
  let base ← VersoCast.Blog.createRenderers Page styles
  let visits ← RuntimeRef.new (0 : Nat)
  let handlers : Renderer.Renderers Page := { base with
    renderInline? := fun key extension children => do
      visits.modify (· + 1)
      base.renderInline? key extension children }
  let leaf : Inline Page := .other (.htmlSpan "counted") #[.text "counted"]
  let title : Block Page := .para #[leaf]
  let content : Array (Block Page) := match mode with
    | 0 => #[title, .para #[leaf]]
    | 1 => #[.blockquote #[title], .para #[leaf]]
    | 2 => #[title]
    | _ => #[]
  let input : Part Page := .mk #[] "" none
    #[.other (.docstringSection (if mode == 2 then 6 else 1)) content] #[]
  let _ ← Renderer.render styles input (renderers := handlers)
  visits.get

end VersoCastTests.Blog
