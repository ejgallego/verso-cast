/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast
public import VersoCast.Renderer.Table
public import VersoSlides.Render

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

/-- This preview does not interpret HTML styles, event strings or React's
reserved props. Decline the entire extension before consuming any children. -/
private def supportedAttribute (name : String) : Bool :=
  ["class", "id", "title", "role", "lang", "dir", "aria-label", "aria-hidden",
    "aria-labelledby", "aria-describedby"].contains name ||
  (name.startsWith "data-" && name.length > 5 && !name.startsWith "data-verso-" &&
    name.toList.all (fun c => c.isLower || c.isDigit || c == '-'))

/-- Validate field names and convert native keys/values once per extension.
Applying the result mutates only fresh props, never borrowed styles or nodes. -/
private def prepareAttributes (styles : Renderer.Styles) (fields : Array (String × String)) :
    ReactM (Option (Js Props → ReactM Unit)) := do
  if !fields.all (supportedAttribute ·.1) then return none
  let fields ← fields.mapM fun (key, value) => do
    let append := key == "class"
    return (append, (← JsValue.ofString (if append then "className" else key)),
      (← JsValue.ofString (if append then " " ++ value else value)))
  return some fun props => do
    for (append, key, value) in fields do
      if append then Renderer.appendClass props styles.strings.keys.className value
      else Js.Object.set props key value

/-- A bounded raw-document preview adapter, independent of navigation/state.
Create once per component factory. Notes/fragments stay visible. Unsupported
markup keeps named fallbacks; no Reveal.js runtime or traversal is installed. -/
def createRenderers (styles : Renderer.Styles) : ReactM (Renderer.Renderers Slides) := do
  let tables ← Renderer.Table.Styles.create
  -- Authored layout classes must not fight Cast's section-grid defaults.
  let wrapperStyle ← Js.Object.empty
  let fragmentKey ← js#"data-fragment-index"
  return {
    blockName, inlineName
    renderInline? := fun key extension children => do
      match extension with
      | .fragment style index =>
        let props ← js%{ "key" := (← JsValue.ofString key),
          "className" := (← JsValue.ofString (fragmentClass style)) }
        if let some index := index then Js.Object.set props fragmentKey (← JsValue.ofString (toString index))
        return some (← <span @props={props}>{Js.Array.ofArray (← children ())}</span>)
      | .styled fields =>
        let some apply ← prepareAttributes styles fields | return none
        let props ← js%{ "key" := (← JsValue.ofString key), "className" := (← js#"") }
        apply props
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
        let index ← index.mapM fun index => JsValue.ofString (toString index)
        let nodes ← children.renderWith fun props => do
          Renderer.appendClass props styles.strings.keys.className suffix
          if let some index := index then Js.Object.set props fragmentKey index
        return some (← Node.fragment (← js%{ "key" := (← JsValue.ofString key) }) (← Js.Array.ofArray nodes))
      | .attr fields =>
        let some apply ← prepareAttributes styles fields | return none
        let nodes ← children.renderWith apply
        return some (← Node.fragment (← js%{ "key" := (← JsValue.ofString key) }) (← Js.Array.ofArray nodes))
      | .wrap fields =>
        let some apply ← prepareAttributes styles fields | return none
        let props ← attributes "wrap" wrapperStyle
        apply props
        return some (← <div @props={props}>{Js.Array.ofArray (← children.render ())}</div>)
      | .otherLanguage language code =>
        let props ← attributes "code" styles.codeBlock
        return some (← <pre @props={props}><code
          className={← JsValue.ofString s!"language-{language}"}
          data-language={← JsValue.ofString language}>{ProofWidgets.Html.text code}</code></pre>)
      | .table columns style =>
        -- Preview styles only: unsupported semantic/styling features stay
        -- visible instead of being silently treated as ordinary cells.
        if style.rowHeaders || style.stripedRows || style.stripedCols ||
            style.rowSeps || style.colSeps || style.headerSep || style.cellGap.isSome then return none
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

end CastSlides
