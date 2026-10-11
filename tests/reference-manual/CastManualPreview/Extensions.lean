/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Manual
public import Manual.Meta.Syntax.Grammar
meta import VersoManual.Basic

public section
namespace CastManualPreview.Extensions
open Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def exampleIdentity? (ext : Verso.Genre.Manual.Block) : Option String :=
  if ext.name == `Manual.example then
    match ext.data with
    | .arr #[_, .arr #[tag, _]] =>
      match Lean.fromJson? (α := Option String) tag with
      | .ok (some tag) => some s!"example:{tag}"
      | _ => none
    | _ => none
  else none

#guard exampleIdentity? {
  name := `Manual.example
  data := .arr #[.str "title", .arr #[.str "stable-tag", .null]] } == some "example:stable-tag"
#guard exampleIdentity? {
  name := `Manual.example
  data := .arr #[.str "title", .arr #[.null, .null]] } == none

/-- Reference-manual roles belong to this consumer, not Cast's generic API. -/
def create (styles : VersoCast.Renderer.Styles) : ReactM
    (VersoCast.Renderer.Renderers Verso.Genre.Manual) := do
  let base ← VersoCast.Manual.createRenderers styles
  let highlighting ← VersoCast.Highlighting.Styles.create
  let calloutStyle ← js%{ "border" := (← js#"1px solid var(--vscode-panel-border, #d0d7de)"),
    "borderRadius" := (← js#"5px"), "padding" := (← js#"8px 10px") }
  let summaryStyle ← js%{ "fontWeight" := (← js#"600"), "cursor" := (← js#"pointer") }
  let keywordStyle ← js%{ "fontFamily" := (← js#"var(--vscode-editor-font-family, ui-monospace, monospace)"),
    "fontWeight" := (← js#"600"), "color" := (← js#"var(--vscode-symbolIcon-keywordForeground, #8250df)") }
  return { base with
    -- Named examples have author-supplied sibling-local identities. Anonymous
    -- examples retain the default positional policy; no content serialization.
    blockIdentity? := fun ext =>
      (exampleIdentity? ext).orElse (fun _ => base.blockIdentity? ext)
    renderInline? := fun key ext children => do
      if ext.name == `Manual.keywordOf then
        let .ok ((word, _, _, _) : String × Option Lean.Name × Lean.Name × Option String) :=
          Lean.fromJson? ext.data | return none
        return some (← <code key={← JsValue.ofString key} style={keywordStyle}>
          {ProofWidgets.Html.text word}</code>)
      else if ext.name == `Manual.keyword then
        let .ok word := ext.data.getStr? | return none
        return some (← <code key={← JsValue.ofString key} style={keywordStyle}>
          {ProofWidgets.Html.text word}</code>)
      else if ext.name == `Manual.attr || ext.name == `Manual.attrs then
        let .ok (value : SubVerso.Highlighting.Highlighted) := Lean.fromJson? ext.data | return none
        return some (← <code key={← JsValue.ofString key} style={highlighting.inlineCode}>
          {VersoCast.Highlighting.render highlighting value}</code>)
      else if ext.name == `Manual.syntaxKind then
        let .ok ((_kind, label, _doc) : Lean.Name × String × Option String) :=
          Lean.fromJson? ext.data | return none
        -- Preserve the authored label; no unresolved links or hover protocol.
        return some (← <code key={← JsValue.ofString key} style={keywordStyle}>
          {ProofWidgets.Html.text label}</code>)
      else if ext.name == `Manual.TODO then
        if ext.data != .null then return none
        return some (← <span key={← JsValue.ofString key} style={highlighting.warning}>
          <strong>TODO: </strong>{Js.Array.ofArray (← children ())}</span>)
      else base.renderInline? key ext children
    renderBlock? := fun key attributes ext children => do
      if ext.name == `Manual.TODO then
        if ext.data != .null then return none
        let props ← attributes "todo" highlighting.warning
        return some (← <aside @props={props}><strong>TODO: </strong>
          {Js.Array.ofArray (← children.render ())}</aside>)
      else if ext.name == `Manual.proofState then
        let .ok ((_, goals) : Option String × Array
            (SubVerso.Highlighting.Highlighted.Goal SubVerso.Highlighting.Highlighted)) :=
          Lean.fromJson? ext.data | return none
        let text := if goals.isEmpty then "All goals completed! 🐙"
          else "\n\n".intercalate (goals.toList.map (·.toString))
        let props ← attributes "proof-state" styles.codeBlock
        return some (← <pre @props={props}><code>{ProofWidgets.Html.text text}</code></pre>)
      else if ext.name == `Manual.example then
        -- Raw and traversed forms both have five fields. The tag supplies only
        -- identity above; links are unresolved without reference traversal.
        let .ok ((_description, _, opened, _, _) : String × Option String × Bool ×
            Option Lean.Json × Option String) := Lean.fromJson? ext.data | return none
        let some (summary, body) := children.splitParagraph? () | return none
        let (summaryProps, title) ← summary ()
        Js.Object.set summaryProps (← js#"style") summaryStyle
        let props ← attributes "example" calloutStyle
        -- Set the initial browser-owned disclosure state, not React-controlled
        -- state; unchanged attributes preserve user toggles across parent updates.
        if opened then Js.Object.set props (← js#"open") (← JsValue.ofBool true)
        return some (← <details @props={props}>
          <summary @props={summaryProps}>{Js.Array.ofArray title}</summary>
          <div style={styles.part}>{Js.Array.ofArray (← body ())}</div>
        </details>)
      else if ext.name == `Manual.syntax then
        let .ok ((_, _, label, _, _) : Option String × Lean.Name × String ×
            Option Lean.Json × Array Lean.Name) := Lean.fromJson? ext.data | return none
        let some (summary, body) := children.splitParagraph? () | return none
        let (summaryProps, title) ← summary ()
        Js.Object.set summaryProps (← js#"style") summaryStyle
        let props ← attributes "syntax" calloutStyle
        return some (← <section @props={props}>
          <div @props={summaryProps}><span>{ProofWidgets.Html.text label}</span> {Js.Array.ofArray title}</div>
          {Js.Array.ofArray (← body ())}</section>)
      else if ext.name == `Manual.grammar then
        let .ok ((_, bnf, _) : Lean.Name × Lean.Widget.TaggedText Manual.GrammarTag × Lean.Json) :=
          Lean.fromJson? ext.data | return none
        let props ← attributes "grammar" styles.codeBlock
        return some (← <pre @props={props}><code>{ProofWidgets.Html.text bnf.stripTags}</code></pre>)
      else if ext.name == `Manual.figure then
        let .ok (_ : String × Option String × Option Lean.Json) := Lean.fromJson? ext.data | return none
        let some (caption, body) := children.splitParagraph? () | return none
        let (captionProps, title) ← caption ()
        Js.Object.set captionProps (← js#"style") summaryStyle
        let props ← attributes "figure" calloutStyle
        return some (← <figure @props={props}>{Js.Array.ofArray (← body ())}
          <figcaption @props={captionProps}>{Js.Array.ofArray title}</figcaption></figure>)
      else base.renderBlock? key attributes ext children }

end CastManualPreview.Extensions
