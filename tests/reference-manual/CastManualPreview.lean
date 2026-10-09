/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Manual
public import CastManualPreview.Extensions
public import Vir.Infoview
public import Vir.Infoview.Widget
public meta import Vir.Infoview.Widget
public meta import CastManualPreview.Server
-- Widget elaboration snapshots the imported runtime implementations. Ordinary
-- opaque imports alone do not invalidate that snapshot when bodies change.
meta import all CastManualPreview.Extensions
meta import all VersoCast.Manual
meta import all VersoCast.Manual.Highlighting
meta import all VersoCast.Renderer
meta import all VersoCast.Renderer.Table
meta import Vir.Attributes

public section
namespace CastManualPreview
open Lean.Vir Lean.Vir.React Lean.Vir.Browser
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private structure Input where
  session : Js Infoview.RpcSession
  params : Js.Object
  uri : Js String

private structure Response where
  document : Option (Verso.Doc.Part Verso.Genre.Manual) := none
  status : String := "Loading page…"

private def decodeDocument (encoded : String) : Except String (Verso.Doc.Part Verso.Genre.Manual) :=
  Lean.Json.parse encoded >>= Lean.fromJson?

-- Same public RPC/effect pattern as VIR's RpcReferenceWidget tutorial.
-- A single child type and stable inputs keep ordinary React state across edits.
private def Page : RuntimeM (FunctionComponent (Props.WithData Input)) := do
  let styles ← VersoCast.Renderer.Styles.create
  let renderers ← Extensions.create styles
  let shellStyle ← js%{ "position" := (← js#"sticky"), "top" := (← js#"0"),
    "zIndex" := (← js#"1"), "padding" := (← js#"8px"),
    "background" := (← JsValue.ofString VersoCast.Renderer.Style.background),
    "borderBottom" := (← js#"1px solid var(--vscode-panel-border, #d0d7de)") }
  let toggleDebug ← Js.Function.ofLean fun (previous : Js Bool) => Js.Boolean.not previous
  FunctionComponent.ofLean fun props => do
    let input : Input ← LeanRef.fromJSL (← Props.WithData.data props)
    let initializer ← Js.Function.ofLean0 (LeanRef.toJSL ({} : Response))
    js#let (value, setter) ← Hooks.useState initializer
    js#let (revision, setRevision) ← Hooks.useState (α := Nat) (← JsValue.ofNat 0)
    js#let (debugValue, setDebug) ← Hooks.useState (α := Bool) (← JsValue.ofBool false)
    let debug ← JsValue.toBool debugValue
    let debugChanged ← Js.Function.ofLeanVoid fun (_ : Js SyntheticEvent) =>
      Js.Function.callVoid setDebug (SetStateAction.ofUpdater toggleDebug)
    let changed ← Js.Function.ofLeanVoid fun (params : Js.Any) => do
      let doc ← Js.Object.get params (← js#"textDocument")
      let uri ← Js.String.fromAny (← Js.Object.get doc (← js#"uri"))
      if ← JsValue.toBool (← Js.String.equal uri input.uri) then
        let increment ← Js.Function.ofLean fun previous => do
          Js.Nat.add previous (← JsValue.ofNat 1)
        Js.Function.callVoid setRevision (SetStateAction.ofUpdater increment)
    Infoview.useClientNotificationEffect (← js#"textDocument/didChange") changed
      (← Js.UndefinedOr.undefined)
    let effect ← Js.Function.ofLean0 <| DomM.toRuntime do
      let active ← RuntimeRef.new true
      let abort ← AbortController.create
      let options ← Infoview.ClientRequestOptions.empty
      Infoview.ClientRequestOptions.setAbortSignal options (← AbortController.getSignal abort)
      let loading ← Js.Function.ofLean fun previous => do
        let previous : Response ← LeanRef.fromJSL previous
        LeanRef.toJSL { previous with status := "Loading page…" }
      Js.Function.callVoid setter (SetStateAction.ofUpdater loading)
      let request : Js.Promise String ← Infoview.RpcSession.callWithOptions input.session
        (← js#"CastManualPreview.Server.document") (Js.erase input.params) options
      let succeed ← Js.Function.ofLeanVoid fun (reply : Js String) => do
        if ← active.get then
          let encoded ← JsValue.toString reply
          match decodeDocument encoded with
          | .ok document =>
            Js.Function.callVoid setter (SetStateAction.ofValue (← LeanRef.toJSL {
              document := some document, status := "" : Response }))
          | .error error =>
            let invalid ← Js.Function.ofLean fun previous => do
              let previous : Response ← LeanRef.fromJSL previous
              LeanRef.toJSL { previous with status := s!"Invalid manual preview: {error}" }
            Js.Function.callVoid setter (SetStateAction.ofUpdater invalid)
      let fail ← Js.Function.ofLeanVoid fun (_error : Js.Any) => do
        if ← active.get then
          let update ← Js.Function.ofLean fun previous => do
            let previous : Response ← LeanRef.fromJSL previous
            LeanRef.toJSL { previous with status := "Could not load this page. Showing the last successful preview, if any." }
          Js.Function.callVoid setter (SetStateAction.ofUpdater update)
      let handled ← Js.Promise.thenVoid request succeed
      let ignore ← Js.Function.ofLeanVoid fun (_ : Js.Undefined) => pure ()
      let _ ← Js.Promise.thenVoidWithRejection handled ignore fail
      let cleanup ← Js.Function.ofLean0Void <| DomM.toRuntime do
        active.set false
        AbortController.abort abort
      pure (Js.UndefinedOr.ofJs cleanup)
    Hooks.useEffect effect (Js.UndefinedOr.ofJs (← js#[
      Js.erase input.session, Js.erase input.params, Js.erase input.uri, Js.erase revision]))
    let state : Response ← LeanRef.fromJSL value
    let rendered : ReactM (Js.Nullable Node) := match state.document with
      | none => Js.Nullable.null
      | some doc => do
          Js.Nullable.ofJs (← VersoCast.Renderer.render styles doc { debug }
          (renderers := renderers))
    let debugPanel : ReactM (Js.Nullable Node) := if debug then do
      Js.Nullable.ofJs (← <aside data-cast-debug="true">Inspection metadata enabled. Keys use author identities when supplied,
        otherwise positions. Timing instrumentation is disabled.</aside>)
      else Js.Nullable.null
    return ← <section>
      <header data-cast-preview-shell="true" style={shellStyle}>
        <label><input type="checkbox" checked={debugValue} onChange={debugChanged}/> Debug</label>
        <p role="status">{Lean.Vir.ProofWidgets.Html.text state.status}</p>
        {debugPanel}
      </header>
      {rendered}
    </section>

/-- Test-only direct path for React SSR, using the same decoder and renderers as
the retained widget, without its editor/RPC shell. -/
@[vir_export] def renderDocument (encoded : String) : ReactM (Js Node) := do
  match decodeDocument encoded with
  | .error error => <p role="alert">{ProofWidgets.Html.text error}</p>
  | .ok document => do
    let styles ← VersoCast.Renderer.Styles.create
    VersoCast.Renderer.render styles document (renderers := (← Extensions.create styles))

@[vir_export]
def View : RuntimeM (FunctionComponent Infoview.PanelWidgetProps) := do
  let page ← Page
  -- The endpoint uses the RPC session's current page, not a cursor fragment.
  -- Keep this params object stable rather than rebuilding it during rendering.
  -- JSON-RPC positions are JavaScript numbers; Js Nat values are bigints.
  let params ← js%{ "line" := (← JsValue.ofFloat 0), "character" := (← JsValue.ofFloat 0) }
  FunctionComponent.ofLean fun props => do
    let session ← Infoview.useRpcSession
    let pos ← Infoview.PanelWidgetProps.pos props
    let uri ← Infoview.PanelPosition.uri pos
    let calculate ← Js.Function.ofLean0 do
      let input ← Props.WithData.make (← LeanRef.toJSL ({ session, params, uri } : Input))
      Node.functionComponent page input (← Js.Array.empty)
    Hooks.useMemo calculate (← js#[Js.erase session, Js.erase uri])

vir_proof_widget View

def preparedWidgetProps : Infoview.WidgetProps :=
  { widgetProps with
    wasmPath := ".vir/runtime.wasm"
    setupHint := "Run node tools/setup-reference-manual.mjs --build from Verso Cast, then restart the Lean server." }

end CastManualPreview
