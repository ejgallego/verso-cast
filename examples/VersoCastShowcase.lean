/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast
public import Vir.Infoview.Widget
public meta import Vir.Infoview.Widget
meta import Vir.Attributes

public section
namespace VersoCastShowcase
open Verso Lean.Vir Lean.Vir.React Lean.Vir.Infoview
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

-- The client owns the genre; rendering does not require JSON/equality instances.
inductive Role where | badge
inductive Directive where | note

@[expose] def genre : Doc.Genre where
  Inline := Role
  Block := Directive
  PartMetadata := String
  TraverseContext := Unit
  TraverseState := Unit

private def paragraph (text : String) : Doc.Block genre := .para #[.text text]

private def document (showNote : Bool) : Doc.Part genre :=
  .mk #[.text "A little document, a live React view"] "Verso Cast showcase" (some "welcome")
    #[
      .para #[.text "Written in ", .other .badge #[.text "Lean"], .text ", rendered through ",
        .bold #[.text "VIR"], .text ", with ordinary React state."],
      .blockquote #[paragraph "Cast renders the document. Your genre owns its roles and directives."],
      .ul #[.mk #[paragraph "Inline roles can supply native React elements."],
        .mk #[paragraph "Block directives keep their children lazy."],
        .mk #[paragraph "Section metadata can customize headings and anchors."]]
    ] #[.mk #[.text "Try the control"] "Try the control" (some "try-it")
      (#[paragraph "Toggle the note above, then edit a sentence in this Lean source."] ++
        if showNote then #[.other .note #[
          paragraph "This callout is a client-owned extension.",
          .para #[.text "Its ", .emph #[.text "children"], .text " are rendered once, on demand."]]] else #[])
      #[]]

@[vir_export] def View : RuntimeM (FunctionComponent PanelWidgetProps) := do
  let styles ← VersoCast.Renderer.Styles.create
  let badgeStyle ← js%{ "padding" := (← js#"0.1em 0.5em"), "borderRadius" := (← js#"999px"),
    "background" := (← js#"#e8f0ff"), "color" := (← js#"#244b86"), "fontWeight" := (← js#"600") }
  let noteStyle ← js%{ "padding" := (← js#"12px"), "borderLeft" := (← js#"3px solid #4a77bd"),
    "background" := (← JsValue.ofString VersoCast.Renderer.Style.codeBackground),
    "display" := (← js#"grid"), "gap" := (← js#"8px") }
  let handlers : VersoCast.Renderer.Renderers genre := {
    renderInline? := fun key _ children => do
      let props ← js%{ "key" := (← JsValue.ofString key), "style" := badgeStyle }
      return some (← <span @props={props}>{Js.Array.ofArray (← children ())}</span>)
    renderBlock? := fun _key attributes _ children => do
      let props ← attributes "note" noteStyle
      return some (← <aside @props={props}>{Js.Array.ofArray (← children ())}</aside>)
    renderPart? := fun _key (label : String) _part renderDefault => do
      let header : VersoCast.Renderer.HeaderRenderer := fun level props title => do
        Js.Object.set props (← JsValue.ofString "id") (← JsValue.ofString s!"showcase-{label}")
        Node.createElement (← ElementType.tag (← JsValue.ofString s!"h{level}"))
          props (← Js.Array.ofArray title)
      return some (← renderDefault (some header)) }
  let initial ← JsValue.ofBool true
  let toggle ← Js.Function.ofLean fun (previous : Js Bool) => Js.Boolean.not previous
  FunctionComponent.ofLean fun _ => do
    js#let (showNote, setter) ← Hooks.useState (α := Bool) initial
    let change ← Js.Function.ofLeanVoid fun (_ : Js SyntheticEvent) =>
      Js.Function.callVoid setter (SetStateAction.ofUpdater toggle)
    return ← <div>
      <label><input type="checkbox" checked={showNote} onChange={change}/> Show the callout</label>
      {VersoCast.Renderer.render styles (document (← JsValue.toBool showNote)) (renderers := handlers)}
    </div>

vir_proof_widget View

def preparedWidgetProps : WidgetProps :=
  { widgetProps with
    wasmPath := ".vir/runtime.wasm"
    setupHint := "Run lake exe cast-assets, then restart the Lean server or reopen this file." }

end VersoCastShowcase

show_panel_widgets [local Lean.Vir.Infoview.widget with VersoCastShowcase.preparedWidgetProps]

-- Place the cursor here to keep the widget visible while editing the document.
theorem showcase_ready : True := by
  trivial
