/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Highlighting
public import VersoSlides.SlideCode.Export
public import Verso.Code.Highlighted

public section
namespace CastSlides.Code
open VersoSlides SubVerso.Highlighting Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

/-- Upstream exports use decimal table keys. Check them before the upstream
decoder's `toNat!`, then reuse its schema and typed reconstruction. These are
checked compiler exports, not an untrusted graph-validation/transport API. -/
private def parseExport (source : String) : Except String Lean.Json := do
  let json ← Lean.Json.parse source
  for name in ["tokens", "messageContents", "goals", "code"] do
    let table ← (← json.getObjVal? name).getObj?
    for (key, _) in table.toArray do
      if key.toNat?.isNone then throw s!"Invalid export table key: {key}"
  return json

def decodeHighlighted (source : String) : Except String Highlighted := do
  let data ← SubVerso.Highlighting.ExportCode.fromJson? (← parseExport source)
  data.toHighlighted

def decode (source : String) : Except String SlideCode := do
  let data ← ExportSlideCode.fromJson? (← parseExport source)
  data.toSlideCode

private def severity (info : Array (Highlighted.Span.Kind × α)) : Highlighted.Span.Kind :=
  info.foldl (fun previous (kind, _) => match previous, kind with
    | .error, _ | _, .error => .error
    | .warning, _ | _, .warning => .warning
    | _, _ => .info) .info

/-- Code wrappers use phrasing content, including block-like fragments/output,
so the same tree is valid inside both inline code and pre/code containers. -/
structure Styles where
  highlighting : VersoCast.Highlighting.Styles
  block : Js Props
  fragmentIndex : Js String

def Styles.create : ReactM Styles := do
  let highlighting ← VersoCast.Highlighting.Styles.create
  let block ← js%{ "display" := (← js#"block") }
  let fragmentIndex ← js#"data-fragment-index"
  return { highlighting, block, fragmentIndex }

/-- Always-visible native preview; annotations do not install a click/reveal
runtime. Hover spans/goals are not rendered as hidden DOM or serialized again. -/
partial def render (styles : Styles) (key : String) : SlideCode → ReactM (Js Node)
  | .hl content => VersoCast.Highlighting.render styles.highlighting content key
  | .seq parts => do
    let nodes ← parts.mapIdxM fun index part => render styles (toString index) part
    Node.fragment (← js%{ "key" := (← JsValue.ofString key) }) (← Js.Array.ofArray nodes)
  | .tactics _ startPos endPos content =>
    <span key={← JsValue.ofString key} className={← js#"tactic"}
      data-tactic-range={← JsValue.ofString s!"{startPos}-{endPos}"}>{render styles "content" content}</span>
  | .span info content =>
    <span key={← JsValue.ofString key}
      className={← JsValue.ofString (if info.isEmpty then "has-info" else "has-info " ++ (severity info).«class»)}>
      {render styles "content" content}</span>
  | .fragment wrapper isBlock content => do
    let props ← js%{ "key" := (← JsValue.ofString key),
      "className" := (← JsValue.ofString ("fragment" ++ (wrapper.style.map (" " ++ ·)).getD "")) }
    if let some index := wrapper.index then Js.Object.set props styles.fragmentIndex (← JsValue.ofString (toString index))
    if isBlock then
      Js.Object.set props (← js#"style") styles.block
      Js.Object.set props (← js#"data-slide-code-block") (← js#"true")
    return ← <span @props={props}>{render styles "content" content}</span>
  | .click target index => do
    let props ← js%{ "key" := (← JsValue.ofString key), "className" := (← js#"fragment slide-click-only") }
    if let some index := index then Js.Object.set props styles.fragmentIndex (← JsValue.ofString (toString index))
    return ← <span @props={props}>{render styles "target" target}</span>
  | .commandOutput info => do
    let nodes ← info.mapIdxM fun index (kind, message) => do
      <code key={← JsValue.ofString (toString index)}
        className={← JsValue.ofString ("verso-message " ++ kind.«class»)}
        style={styles.highlighting.message kind}>{ProofWidgets.Html.text (message.toString [])}</code>
    return ← <span key={← JsValue.ofString key}
      className={← JsValue.ofString ("command-output " ++ (severity info).«class»)}
      style={styles.block}>{Js.Array.ofArray nodes}</span>

end CastSlides.Code
