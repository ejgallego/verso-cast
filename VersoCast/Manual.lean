/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Renderer
public import VersoManual.Basic
public import SubVerso.Highlighting

public section
namespace VersoCast.Manual
open Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

/-- Manual's named extension placeholders and stateless content-key policy.
Clients extend this ordinary record with their own rendering callbacks.
This adapter does not run Manual traversal or resolve cross-references. -/
def renderers : Renderer.Renderers Verso.Genre.Manual where
  inlineName := fun extension => extension.name.toString
  blockName := fun extension => extension.name.toString
  fingerprint := fun value => some (Fingerprint.canonicalKey value)

/-- Readable source and compiler output for Verso's built-in Lean blocks.
Create once in the component factory. This first presentation preserves text,
severity and trace expansion, but does not provide highlighting/hover widgets.
Invalid extension data delegates to the normal visible fallback. -/
def createRenderers (styles : Renderer.Styles) : ReactM (Renderer.Renderers Verso.Genre.Manual) := do
  let outputStyle ← js%{
    "borderLeft" := (← js#"3px solid var(--vscode-descriptionForeground, #57606a)"),
    "paddingLeft" := (← js#"10px") }
  let labelStyle ← js%{ "fontWeight" := (← js#"600"), "fontSize" := (← js#"0.8rem") }
  return { renderers with renderBlock? := fun _ attributes ext _children => do
    if ext.name == `Verso.Genre.Manual.InlineLean.Block.lean then
      let .arr #[hl, _, _, _] := ext.data | return none
      let .ok (highlighted : SubVerso.Highlighting.Highlighted) := Lean.fromJson? hl | return none
      let props ← attributes "lean" styles.codeBlock
      return some (← <pre @props={props}><code>{ProofWidgets.Html.text highlighted.toString}</code></pre>)
    else if ext.name == `Verso.Genre.Manual.InlineLean.Block.leanOutput then
      let .ok ((msg, summarize, expandTraces) :
          SubVerso.Highlighting.Highlighted.Message × Bool × List Lean.Name) :=
        Lean.fromJson? ext.data | return none
      let props ← attributes "lean-output" outputStyle
      let severity := msg.severity.toString
      Js.Object.set props (← js#"data-verso-message-severity") (← JsValue.ofString severity)
      let content ← <pre style={styles.codeBlock}><code>{ProofWidgets.Html.text (msg.toString expandTraces)}</code></pre>
      if summarize then
        return some (← <details @props={props}><summary style={labelStyle}>
          {ProofWidgets.Html.text severity}</summary>{pure content}</details>)
      else
        return some (← <div @props={props}><div style={labelStyle}>
          {ProofWidgets.Html.text severity}</div>{pure content}</div>)
    else return none }

end VersoCast.Manual
