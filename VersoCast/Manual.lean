/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Renderer
public import VersoManual.Basic
public import VersoCast.Highlighting
public import VersoCast.Renderer.Table
public import VersoManual.Table
public import VersoManual.Docstring
public import VersoManual.InlineLean.IO

public section
namespace VersoCast.Manual
open Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

/-- Manual's named extension placeholders and positional fallback keys.
Clients extend this ordinary record with their own rendering callbacks.
This adapter does not run Manual traversal or resolve cross-references. -/
def renderers : Renderer.Renderers Verso.Genre.Manual where
  inlineName := fun extension => extension.name.toString
  blockName := fun extension => extension.name.toString

/-- Readable source and compiler output for Verso's built-in Lean blocks.
Create once in the component factory. This first presentation preserves text,
severity, token colouring and trace expansion, but no interactive hover widgets.
Invalid extension data delegates to the normal visible fallback. -/
def createRenderers (styles : Renderer.Styles) : ReactM (Renderer.Renderers Verso.Genre.Manual) := do
  let highlighting ← Highlighting.Styles.create
  let tableStyles ← Renderer.Table.Styles.create
  let labelStyle ← js%{ "fontWeight" := (← js#"600"), "fontSize" := (← js#"0.8rem") }
  return { renderers with
    renderInline? := fun key ext children => do
      if ext.name == `Verso.Genre.Manual.InlineLean.Inline.lean then
        let .arr #[hl, _] := ext.data | return none
        let .ok (hl : SubVerso.Highlighting.Highlighted) := Lean.fromJson? hl | return none
        return some (← <code key={← JsValue.ofString key} style={highlighting.inlineCode}>
          {Highlighting.render highlighting hl}</code>)
      else if ext.name == `Verso.Genre.Manual.InlineLean.Inline.name ||
          ext.name == `Verso.Genre.Manual.leanFromMarkdown || ext.name == `Verso.Genre.Manual.tacticInline then
        let .ok (hl : SubVerso.Highlighting.Highlighted) := Lean.fromJson? ext.data | return none
        return some (← <code key={← JsValue.ofString key} style={highlighting.inlineCode}>
          {Highlighting.render highlighting hl}</code>)
      else if ext.name == `Verso.Genre.Manual.deftech then
        let .ok ((_key, _term) : String × String) := Lean.fromJson? ext.data | return none
        return some (← <dfn key={← JsValue.ofString key}>{Js.Array.ofArray (← children ())}</dfn>)
      else if ext.name == `Verso.Genre.Manual.tech then
        let .arr #[.str _, _, _] := ext.data | return none
        return some (← <em key={← JsValue.ofString key}>{Js.Array.ofArray (← children ())}</em>)
      else return none
    renderBlock? := fun _ attributes ext children => do
      if ext.name == `Verso.Genre.Manual.Block.table then
        let .ok ((columns, header, _, _, alignment) : Nat × Bool × Option String ×
            Option Lean.Json × Option Verso.Genre.Manual.TableConfig.Alignment) :=
          Lean.fromJson? ext.data | return none
        let some cells := children.listItems? () | return none
        let style := match alignment with
          | some .left => tableStyles.left
          | some .right => tableStyles.right
          | _ => tableStyles.table
        let props ← attributes "table" style
        if let some alignment := alignment then
          Js.Object.set props (← js#"data-verso-table-alignment")
            (← JsValue.ofString alignment.htmlClass)
        return ← Renderer.Table.render tableStyles props columns header cells
      else if ext.name == `Verso.Genre.Manual.Block.paragraph then
        if ext.data != .null then return none
        let props ← attributes "paragraph-group" styles.part
        return some (← <div @props={props}>{Js.Array.ofArray (← children.render ())}</div>)
      else if ext.name == `Verso.Genre.Manual.Block.internalSignature then
        let .ok ((name, signature) : SubVerso.Highlighting.Highlighted ×
            Option SubVerso.Highlighting.Highlighted) := Lean.fromJson? ext.data | return none
        let hl := match signature with
          | none => name
          | some signature => .seq #[name, .text " : ", signature]
        let props ← attributes "internal-signature" styles.part
        return some (← <section @props={props}>
          <pre style={highlighting.block}><code>{Highlighting.render highlighting hl}</code></pre>
          {Js.Array.ofArray (← children.render ())}</section>)
      else if ext.name == `Verso.Genre.Manual.Block.fieldSignature then
        let .ok ((visibility, name, signature, inheritedFrom, parents) :
            Verso.Genre.Manual.Block.Docstring.Visibility × SubVerso.Highlighting.Highlighted ×
            SubVerso.Highlighting.Highlighted × Option Nat × Array SubVerso.Highlighting.Highlighted) :=
          Lean.fromJson? ext.data | return none
        let modifier := match visibility with
          | .private => "private "
          | .public | .protected => ""
        let hl := SubVerso.Highlighting.Highlighted.seq #[.text modifier, name, .text " : ", signature]
        let props ← attributes "field-signature" styles.part
        let inherited : ReactM (Js.Nullable Node) := if inheritedFrom.isSome then do
          let names ← parents.mapIdxM fun index parent => do
            return ← <li key={← JsValue.ofString s!"parent:{index}"}>
              <code>{Highlighting.render highlighting parent}</code></li>
          Js.Nullable.ofJs (← <div>Inherited from <ul>{Js.Array.ofArray names}</ul></div>)
          else Js.Nullable.null
        return some (← <section @props={props}>
          <pre style={highlighting.block}><code>{Highlighting.render highlighting hl}</code></pre>
          {inherited}{Js.Array.ofArray (← children.render ())}</section>)
      else if ext.name == `Verso.Genre.Manual.InlineLean.Block.exampleFile ||
          ext.name == `Verso.Genre.Manual.InlineLean.Block.exampleLeanFile then
        let label? := if ext.name == `Verso.Genre.Manual.InlineLean.Block.exampleLeanFile then
          ext.data.getStr?.map (fun file => s!"File: {file}")
        else (Lean.fromJson? (α := Verso.Genre.Manual.InlineLean.FileType) ext.data).map fun type =>
          match type with
          | .stdin => "stdin" | .stdout => "stdout" | .stderr => "stderr"
          | .input file => s!"Input: {file}" | .output file => s!"Output: {file}" | .other file => s!"File: {file}"
        let .ok label := label? | return none
        let props ← attributes "example-file" styles.blockquote
        return some (← <section @props={props}><strong>{ProofWidgets.Html.text label}</strong>
          {Js.Array.ofArray (← children.render ())}</section>)
      else if ext.name == `Verso.Genre.Manual.InlineLean.Block.lean then
        let .arr #[hl, _, _, _] := ext.data | return none
        let .ok (highlighted : SubVerso.Highlighting.Highlighted) := Lean.fromJson? hl | return none
        let props ← attributes "lean" highlighting.block
        return some (← <pre @props={props}><code>{Highlighting.render highlighting highlighted}</code></pre>)
      else if ext.name == `Verso.Genre.Manual.InlineLean.Block.leanOutput then
        let .ok ((msg, summarize, expandTraces) :
            SubVerso.Highlighting.Highlighted.Message × Bool × List Lean.Name) :=
          Lean.fromJson? ext.data | return none
        let props ← attributes "lean-output" (highlighting.message msg.severity)
        let severity := msg.severity.toString
        Js.Object.set props (← js#"data-verso-message-severity") (← JsValue.ofString severity)
        let content ← <pre style={highlighting.block}><code>{ProofWidgets.Html.text (msg.toString expandTraces)}</code></pre>
        if summarize then
          return some (← <details @props={props}><summary style={labelStyle}>
            {ProofWidgets.Html.text severity}</summary>{pure content}</details>)
        else
          return some (← <div @props={props}><div style={labelStyle}>
            {ProofWidgets.Html.text severity}</div>{pure content}</div>)
      else if ext.name == `Verso.Genre.Manual.Block.constructorSignature ||
          ext.name == `Verso.Genre.Manual.leanFromMarkdown ||
          ext.name == `Verso.Genre.Manual.InlineLean.Block.signature then
        let .ok (hl : SubVerso.Highlighting.Highlighted) := Lean.fromJson? ext.data | return none
        let props ← attributes "signature" styles.part
        return some (← <div @props={props}>
          <pre style={highlighting.block}><code>{Highlighting.render highlighting hl}</code></pre>
          {Js.Array.ofArray (← children.render ())}</div>)
      else if ext.name == `Verso.Genre.Manual.Block.docstringSection then
        let .ok label := ext.data.getStr? | return none
        let props ← attributes "docstring-section" styles.part
        Js.Object.set props (← js#"aria-label") (← JsValue.ofString label)
        return some (← <section @props={props}>
          <strong>{ProofWidgets.Html.text label}</strong>{Js.Array.ofArray (← children.render ())}</section>)
      else if ext.name == `Verso.Genre.Manual.Block.docstring then
        let .arr #[.str name, .arr #[_, .arr #[signature, _]]] := ext.data | return none
        -- Choose the stored narrow form for an infoview-sized pane. The wide
        -- variant and traversal/reference metadata need not be decoded here.
        let .ok (signature : SubVerso.Highlighting.Highlighted) :=
          signature.getObjValAs? SubVerso.Highlighting.Highlighted "narrow" | return none
        let props ← attributes "docstring" styles.blockquote
        Js.Object.set props (← js#"aria-label") (← JsValue.ofString name)
        return some (← <section @props={props}>
          <pre style={highlighting.block}><code>{Highlighting.render highlighting signature}</code></pre>
          {Js.Array.ofArray (← children.render ())}</section>)
      else if ext.name == `Verso.Genre.Manual.InlineLean.Block.syntaxError then
        let .ok ((source, errors) : String × Array Lean.Json) := Lean.fromJson? ext.data | return none
        let mut messages := #[]
        for error in errors do
          let .ok text := error.getObjValAs? String "text" | return none
          messages := messages.push text
        let props ← attributes "syntax-error" styles.part
        return some (← <div @props={props}><pre style={highlighting.block}>
          <code>{ProofWidgets.Html.text source}</code></pre>
          <div style={highlighting.error}>{ProofWidgets.Html.text ("\n".intercalate messages.toList)}</div></div>)
      else return none }

end VersoCast.Manual
