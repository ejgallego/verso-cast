/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import Vir.React
public import Vir.ProofWidgets.Jsx
public import SubVerso.Highlighting

public section
namespace VersoCast.Highlighting
open Lean.Vir Lean.Vir.React SubVerso.Highlighting
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

/-- Native values created once per renderer factory, never per token. -/
structure Styles where
  block : Js Props
  inlineCode : Js Props
  keyword : Js Props
  name : Js Props
  literal : Js Props
  comment : Js Props
  plain : Js Props
  error : Js Props
  warning : Js Props
  info : Js Props

def Styles.create : ReactM Styles := do
  let color := fun value => do js%{ "color" := (← JsValue.ofString value) }
  let message := fun value => do js%{ "color" := (← JsValue.ofString value),
    "borderLeft" := (← JsValue.ofString s!"3px solid {value}"), "paddingLeft" := (← js#"10px") }
  return {
    block := ← js%{ "margin" := (← js#"0"), "padding" := (← js#"10px 12px"),
      "background" := (← js#"var(--vscode-textCodeBlock-background, #f6f8fa)"),
      "borderRadius" := (← js#"5px"), "overflowX" := (← js#"auto"),
      "fontFamily" := (← js#"var(--vscode-editor-font-family, ui-monospace, monospace)"),
      "fontSize" := (← js#"var(--vscode-editor-font-size, 0.88rem)"),
      "lineHeight" := (← js#"1.5"), "whiteSpace" := (← js#"pre") }
    inlineCode := ← js%{ "fontFamily" := (← js#"var(--vscode-editor-font-family, ui-monospace, monospace)"),
      "fontSize" := (← js#"0.95em"), "padding" := (← js#"0.08em 0.25em"),
      "whiteSpace" := (← js#"pre-wrap"),
      "borderRadius" := (← js#"3px"),
      "background" := (← js#"var(--vscode-textCodeBlock-background, #f6f8fa)") }
    keyword := ← color "var(--vscode-symbolIcon-keywordForeground, #8250df)"
    name := ← color "var(--vscode-symbolIcon-functionForeground, #0969da)"
    literal := ← color "var(--vscode-symbolIcon-stringForeground, #0a7a48)"
    comment := ← color "var(--vscode-descriptionForeground, #57606a)"
    plain := ← Js.Object.empty
    error := ← message "var(--vscode-errorForeground, #cf222e)"
    warning := ← message "var(--vscode-editorWarning-foreground, #9a6700)"
    info := ← message "var(--vscode-editorInfo-foreground, #0969da)"
  }

def Styles.message (styles : Styles) : Highlighted.Span.Kind → Js Props
  | .error => styles.error | .warning => styles.warning | .info => styles.info

private def tokenStyle (styles : Styles) : Token.Kind → Js Props
  | .keyword .. | .delim .. | .sort .. | .option .. => styles.keyword
  | .str .. | .char .. | .num .. | .levelConst .. => styles.literal
  | .docComment | .lineComment | .blockComment | .commentDelim => styles.comment
  | .unknown | .withType .. => styles.plain
  | _ => styles.name

/-- Render the typed highlighting tree, preserving source whitespace and escaping.
No raw HTML, document lookup, hover protocol, or per-token style construction. -/
private partial def renderAt (styles : Styles) (key : String) : Highlighted → ReactM (Js Node)
  | .token token =>
    <span key={← JsValue.ofString key} style={tokenStyle styles token.kind} data-verso-token="true">
      {ProofWidgets.Html.text token.content}</span>
  | .text text | .unparsed text => do Node.text (← JsValue.ofString text)
  | .seq values => do
    let values ← values.mapIdxM fun index => renderAt styles (toString index)
    let props ← js%{ "key" := (← JsValue.ofString key) }
    Node.fragment props (← Js.Array.ofArray values)
  | .span _ content | .tactics _ _ _ content => renderAt styles key content
  | .point .. => do Node.text (← js#"")

/-- The caller may provide a sibling-local root key when composing highlighting
leaves into another typed renderer. Descendant token keys stay local. -/
def render (styles : Styles) (value : Highlighted) (key : String := "root") : ReactM (Js Node) :=
  renderAt styles key value

/-- Shared compiler-message presentation. The caller supplies fresh outer props
with its source identity and a factory-created label style. Summarized messages
use native details state; ordinary messages remain expanded. -/
def renderMessage (styles : Styles) (labelStyle props : Js Props)
    (message : Highlighted.Message) (summarize : Bool)
    (expandTraces : List Lean.Name := []) : ReactM (Js Node) := do
  let severity := message.severity.toString
  Js.Object.set props (← js#"data-verso-message-severity") (← JsValue.ofString severity)
  let content ← <pre style={styles.block}><code>
    {ProofWidgets.Html.text (message.toString expandTraces)}</code></pre>
  if summarize then
    return ← <details @props={props}><summary style={labelStyle}>
      {ProofWidgets.Html.text severity}</summary>{pure content}</details>
  else
    return ← <div @props={props}><div style={labelStyle}>
      {ProofWidgets.Html.text severity}</div>{pure content}</div>

end VersoCast.Highlighting
