/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Renderer
public import VersoCast.Highlighting
public import VersoBlog.Basic

public section
namespace VersoCast.Blog
open Verso Verso.Doc Verso.Genre
open Verso.Genre.Blog
open Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def blockName : Genre.Blog.BlockExt → String
  | .highlightedCode .. => "Blog.highlightedCode"
  | .message .. => "Blog.message"
  | .lexedText .. => "Blog.lexedText"
  | .htmlDiv .. => "Blog.htmlDiv"
  | .htmlWrapper .. => "Blog.htmlWrapper"
  | .htmlDetails .. => "Blog.htmlDetails"
  | .blob .. => "Blog.blob"
  | .component name _ => s!"Blog.component:{name}"
  | .docstring .. => "Blog.docstring"
  | .docstringSection .. => "Blog.docstringSection"

private def inlineName : Genre.Blog.InlineExt → String
  | .highlightedCode .. => "Blog.highlightedCode"
  | .message .. => "Blog.message"
  | .lexedText .. => "Blog.lexedText"
  | .customHighlight .. => "Blog.customHighlight"
  | .label .. => "Blog.label"
  | .ref .. => "Blog.ref"
  | .pageref .. => "Blog.pageref"
  | .htmlSpan .. => "Blog.htmlSpan"
  | .blob .. => "Blog.blob"
  | .component name _ => s!"Blog.component:{name}"

/-- A raw-document adapter shared by Page/Post through BlogGenre. Publication
metadata is client-owned. References, registered site components and arbitrary
HTML keep visible fallbacks; no site traversal or scripting is copied here. -/
def createRenderers (g : Doc.Genre) [bg : BlogGenre g] (styles : Renderer.Styles) :
    ReactM (Renderer.Renderers g) := do
  let highlighting ← Highlighting.Styles.create
  let labelStyle ← js%{ "fontWeight" := (← js#"600"), "fontSize" := (← js#"0.8rem") }
  let lexed := fun (content : Genre.Blog.LexedText) => do
    content.content.mapIdxM fun index (category, text) => do
      let props ← js%{ "key" := (← JsValue.ofString s!"token:{index}") }
      if let some category := category then
        Js.Object.set props styles.strings.keys.className (← JsValue.ofString category)
      return ← <span @props={props}>{ProofWidgets.Html.text text}</span>
  return {
    inlineName := fun extension => inlineName (bg.inline_eq ▸ extension)
    blockName := fun extension => blockName (bg.block_eq ▸ extension)
    renderInline? := fun key extension children => do
      let extension : Genre.Blog.InlineExt := bg.inline_eq ▸ extension
      match extension with
      | .highlightedCode _ highlighted | .customHighlight highlighted =>
        return some (← <code key={← JsValue.ofString key} style={highlighting.inlineCode}>
          {Highlighting.render highlighting highlighted}</code>)
      | .lexedText content =>
        return some (← <code key={← JsValue.ofString key} style={highlighting.inlineCode}>
          {Js.Array.ofArray (← lexed content)}</code>)
      | .message message traces =>
        return some (← <code key={← JsValue.ofString key}>
          {ProofWidgets.Html.text (message.toString traces)}</code>)
      | .htmlSpan classes =>
        return some (← <span key={← JsValue.ofString key} className={← JsValue.ofString classes}>
          {Js.Array.ofArray (← children ())}</span>)
      | _ => return none
    renderBlock? := fun _ attributes extension children => do
      let extension : Genre.Blog.BlockExt := bg.block_eq ▸ extension
      match extension with
      | .highlightedCode _ highlighted =>
        let props ← attributes "lean" highlighting.block
        return some (← <pre @props={props}><code>{Highlighting.render highlighting highlighted}</code></pre>)
      | .lexedText content =>
        let props ← attributes "lexed" highlighting.block
        Js.Object.set props (← js#"data-language") (← JsValue.ofString content.name)
        return some (← <pre @props={props}><code>{Js.Array.ofArray (← lexed content)}</code></pre>)
      | .message summarize message traces =>
        let props ← attributes "lean-output" (highlighting.message message.severity)
        return some (← Highlighting.renderMessage highlighting labelStyle props message summarize traces)
      | .htmlDiv classes =>
        let props ← attributes "html-div" styles.part
        Renderer.appendClass props styles.strings.keys.className (← JsValue.ofString s!" {classes}")
        return some (← <div @props={props}>{Js.Array.ofArray (← children.render ())}</div>)
      | .docstring _ _ =>
        let props ← attributes "docstring" styles.blockquote
        return some (← <section @props={props}>{Js.Array.ofArray (← children.render ())}</section>)
      | .docstringSection level =>
        if level > 5 then return none
        let some (title, body) := children.splitParagraph? () | return none
        let props ← attributes "docstring-section" styles.part
        let (headingProps, inlines) ← title ()
        -- Reuse the title paragraph's key/source/focus/change attributes.
        Js.Object.set headingProps styles.strings.keys.style styles.heading
        Js.Object.set headingProps styles.strings.keys.dataVersoKind (← js#"docstring-heading")
        let heading ← Node.createElement
          (← ElementType.tag (← JsValue.ofString s!"h{level + 1}")) headingProps
          (← Js.Array.ofArray inlines)
        return some (← <section @props={props}>{pure heading}{Js.Array.ofArray (← body ())}</section>)
      | _ => return none }

end VersoCast.Blog
