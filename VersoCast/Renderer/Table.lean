/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Renderer.Config
public import Vir.ProofWidgets.Jsx

public section
namespace VersoCast.Renderer.Table
open Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

/-- Borrowed native styles, allocated once in the component factory. -/
structure Styles where
  table : Js Props
  left : Js Props
  right : Js Props
  cell : Js Props
  header : Js Props
  styleKey : Js String
  scopeKey : Js String
  column : Js String

def Styles.create : ReactM Styles := do
  let cell ← js%{ "padding" := (← js#"6px 10px"), "textAlign" := (← js#"left"),
    "verticalAlign" := (← js#"top"),
    "border" := (← js#"1px solid var(--vscode-panel-border, #d0d7de)") }
  let header ← js%{ "padding" := (← js#"6px 10px"), "textAlign" := (← js#"left"),
    "verticalAlign" := (← js#"top"), "fontWeight" := (← js#"600"),
    "background" := (← js#"var(--vscode-textCodeBlock-background, #f6f8fa)"),
    "border" := (← js#"1px solid var(--vscode-panel-border, #d0d7de)") }
  let table ← js%{ "borderCollapse" := (← js#"collapse"),
    "margin" := (← js#"12px auto"), "maxWidth" := (← js#"100%") }
  let left ← js%{ "borderCollapse" := (← js#"collapse"),
    "margin" := (← js#"12px auto 12px 0"), "maxWidth" := (← js#"100%") }
  let right ← js%{ "borderCollapse" := (← js#"collapse"),
    "margin" := (← js#"12px 0 12px auto"), "maxWidth" := (← js#"100%") }
  return {
    table, left, right, cell, header
    styleKey := (← js#"style")
    scopeKey := (← js#"scope")
    column := (← js#"col") }

/-- Group flat lazy cells into a valid table. Malformed shapes return `none`
before consuming any cell; callers can delegate to visible fallback. Each cell
is rendered once, retaining its supplied key and navigation/change attributes.
Cell thunks must return fresh props; this helper sets their style and header scope.
Explicit thead/tbody keep live and parsed SSR structures equal. -/
def render (styles : Styles) (props : Js Props) (columns : Nat) (header : Bool)
    (cells : Array (Unit → ReactM (Js Props × Array (Js Node)))) : ReactM (Option (Js Node)) := do
  if columns == 0 || cells.isEmpty || cells.size % columns != 0 then return none
  let rows ← (List.range (cells.size / columns)).toArray.mapM fun row => do
    let nodes ← (cells.extract (row * columns) ((row + 1) * columns)).mapM fun cell => do
      let (props, nodes) ← cell ()
      let isHeader := header && row == 0
      Js.Object.set props styles.styleKey (if isHeader then styles.header else styles.cell)
      if isHeader then
        Js.Object.set props styles.scopeKey styles.column
        return ← <th @props={props}>{Js.Array.ofArray nodes}</th>
      else return ← <td @props={props}>{Js.Array.ofArray nodes}</td>
    return ← <tr key={← JsValue.ofString s!"row:{row}"}>{Js.Array.ofArray nodes}</tr>
  let head : ReactM (Js.Nullable Node) := if header then do
    let some row := rows[0]? | Js.Nullable.null
    Js.Nullable.ofJs (← <thead>{pure row}</thead>) else Js.Nullable.null
  let body := if header then rows.extract 1 rows.size else rows
  return some (← <table @props={props}>{head}<tbody>{Js.Array.ofArray body}</tbody></table>)

end VersoCast.Renderer.Table
