/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Manual
public import Vir.Infoview
public import Vir.Infoview.Widget
public meta import VersoCast.Manual.Preview.Server

public section
namespace VersoCast.Manual.Preview
open Lean.Vir Lean.Vir.React Lean.Vir.Browser
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

/-- Native page authority delivered by the ordinary RPC envelope. Never pass
snapshotRef through a document JSON decoder or recreate its reserved fields. -/
structure PageInfo where
  session : Js Infoview.RpcSession
  uri : String
  version : Nat
  snapshotRef : Js.Any
  /-- Local display freshness only, not a lease against later server edits. -/
  isCurrent : Bool := true

/-- Host-owned inputs. Keep session stable across cursor motion. Change generation
on same-version page reprocessing or server-session replacement; it must be a
stable native value between such events. Cast also subscribes to source edits. -/
structure Input where
  session : Js Infoview.RpcSession
  uri : Js String
  generation : Js.Any

/-- Create stable extension components/styles once. The returned pure selection
function may close over the current page authority in its render callbacks.
Callbacks are not hook scopes. Invalidation is synchronous and idempotent. -/
structure Config where
  createRenderers : Renderer.Styles →
    RuntimeM (PageInfo → Renderer.Renderers Verso.Genre.Manual) := fun styles => do
      let handlers ← Manual.createRenderers styles
      pure fun _ => handlers
  onInvalidated : RuntimeM Unit := pure ()
  onLoaded : PageInfo → RuntimeM Unit := fun _ => pure ()

private structure Response where
  document : Option (Verso.Doc.Part Verso.Genre.Manual × PageInfo) := none
  status : String := "Loading page…"

private def decodeDocument (encoded : String) : Except String (Verso.Doc.Part Verso.Genre.Manual) :=
  Lean.Json.parse encoded >>= Lean.fromJson?

-- Same public RPC/effect pattern as VIR's RpcReferenceWidget tutorial.
-- A single child type and stable inputs keep ordinary React state across edits.
/-- Whole-page preview with retained last-good content. The caller owns the
surrounding VIR widget shell and supplies Input through Props.WithData. -/
def create (config : Config := {}) : RuntimeM (FunctionComponent (Props.WithData Input)) := do
  let styles ← VersoCast.Renderer.Styles.create
  let renderers ← config.createRenderers styles
  let params ← Js.Object.empty
  let shellStyle ← js%{ "position" := (← js#"sticky"), "top" := (← js#"0"),
    "zIndex" := (← js#"1"), "padding" := (← js#"8px"),
    "background" := (← JsValue.ofString VersoCast.Renderer.Style.background),
    "borderBottom" := (← js#"1px solid var(--vscode-panel-border, #d0d7de)") }
  -- Status changes must not change the space occupied by the sticky shell.
  -- Keep one line beside the controls; long failures remain available via title.
  let controlsStyle ← js%{ "display" := (← js#"flex"), "alignItems" := (← js#"center"),
    "gap" := (← js#"12px") }
  let labelStyle ← js%{ "flexShrink" := (← js#"0"), "whiteSpace" := (← js#"nowrap") }
  let statusStyle ← js%{ "flex" := (← js#"1"), "minWidth" := (← js#"0"),
    "margin" := (← js#"0"), "whiteSpace" := (← js#"nowrap"),
    "overflow" := (← js#"hidden"), "textOverflow" := (← js#"ellipsis") }
  let toggleDebug ← Js.Function.ofLean fun (previous : Js Bool) => Js.Boolean.not previous
  let noCancel ← LeanRef.toJSL (pure () : RuntimeM Unit)
  FunctionComponent.ofLean fun props => do
    let input : Input ← LeanRef.fromJSL (← Props.WithData.data props)
    let initializer ← Js.Function.ofLean0 (LeanRef.toJSL ({} : Response))
    js#let (value, setter) ← Hooks.useState initializer
    js#let (revision, setRevision) ← Hooks.useState (α := Nat) (← JsValue.ofNat 0)
    js#let (debugValue, setDebug) ← Hooks.useState (α := Bool) (← JsValue.ofBool false)
    let cancelRef ← Hooks.useRef noCancel
    let cancelCurrent : RuntimeM Unit := do
      let cancel : RuntimeM Unit ← LeanRef.fromJSL (← Ref.get cancelRef)
      cancel
    let debug ← JsValue.toBool debugValue
    let debugChanged ← Js.Function.ofLeanVoid fun (_ : Js SyntheticEvent) =>
      Js.Function.callVoid setDebug (SetStateAction.ofUpdater toggleDebug)
    let changed ← Js.Function.ofLeanVoid fun (params : Js.Any) => do
      let doc ← Js.Object.get params (← js#"textDocument")
      let uri ← Js.String.fromAny (← Js.Object.get doc (← js#"uri"))
      if ← JsValue.toBool (← Js.String.equal uri input.uri) then
        cancelCurrent
        let increment ← Js.Function.ofLean fun previous => do
          Js.Nat.add previous (← JsValue.ofNat 1)
        Js.Function.callVoid setRevision (SetStateAction.ofUpdater increment)
    Infoview.useClientNotificationEffect (← js#"textDocument/didChange") changed
      (← Js.UndefinedOr.undefined)
    let effect ← Js.Function.ofLean0 <| DomM.toRuntime do
      let active ← RuntimeRef.new true
      let abort ← AbortController.create
      let cancel : RuntimeM Unit := do
        if ← active.get then
          active.set false
          DomM.toRuntime (AbortController.abort abort)
          config.onInvalidated
      Ref.set cancelRef (← LeanRef.toJSL cancel)
      let options ← Infoview.ClientRequestOptions.empty
      Infoview.ClientRequestOptions.setAbortSignal options (← AbortController.getSignal abort)
      let loading ← Js.Function.ofLean fun previous => do
        let previous : Response ← LeanRef.fromJSL previous
        LeanRef.toJSL { previous with
          status := "Loading page…"
          document := previous.document.map fun (doc, page) => (doc, { page with isCurrent := false }) }
      Js.Function.callVoid setter (SetStateAction.ofUpdater loading)
      let request : Js.Promise Js.Object.Value ← Infoview.RpcSession.callWithOptions input.session
        (← js#"VersoCast.Manual.Preview.Server.document") (Js.erase params) options
      let succeed ← Js.Function.ofLeanVoid fun (reply : Js.Object) => do
        if ← active.get then
          let uri ← Js.String.fromAny (← Js.Object.get reply (← js#"uri"))
          if !(← JsValue.toBool (← Js.String.equal uri input.uri)) then return
          let encoded ← JsValue.toString (← Js.String.fromAny
            (← Js.Object.get reply (← js#"documentJson")))
          match decodeDocument encoded with
          | .ok document =>
            let version ← JsValue.toFloat (← Js.Number.fromAny
              (← Js.Object.get reply (← js#"version")))
            let page : PageInfo := {
              session := input.session
              uri := ← JsValue.toString uri
              version := version.toUInt64.toNat
              snapshotRef := ← Js.Object.get reply (← js#"snapshotRef") }
            config.onLoaded page
            Js.Function.callVoid setter (SetStateAction.ofValue (← LeanRef.toJSL {
              document := some (document, page), status := "" : Response }))
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
      let cleanup ← Js.Function.ofLean0Void cancel
      pure (Js.UndefinedOr.ofJs cleanup)
    Hooks.useEffect effect (Js.UndefinedOr.ofJs (← js#[
      Js.erase input.session, Js.erase input.uri, input.generation, Js.erase revision]))
    let state : Response ← LeanRef.fromJSL value
    let rendered : ReactM (Js.Nullable Node) := match state.document with
      | none => Js.Nullable.null
      | some (doc, page) => do
          Js.Nullable.ofJs (← VersoCast.Renderer.render styles doc { debug }
          (renderers := renderers page))
    let debugPanel : ReactM (Js.Nullable Node) := if debug then do
      Js.Nullable.ofJs (← jsx%{<aside data-cast-debug="true">Inspection metadata enabled. Keys use author identities when supplied,
        otherwise positions. Timing instrumentation is disabled.</aside>})
      else Js.Nullable.null
    return ← jsx%{<section data-cast-preview-current={← JsValue.ofBool
        (state.document.any fun (_, page) => page.isCurrent)}>
      <header data-cast-preview-shell="true" style={shellStyle}>
        <div style={controlsStyle}>
          <label style={labelStyle}><input type="checkbox" checked={debugValue} onChange={debugChanged}/> Debug</label>
          <p role="status" style={statusStyle} title={(← JsValue.ofString state.status)}>{Lean.Vir.ProofWidgets.Html.text state.status}</p>
        </div>
        {debugPanel}
      </header>
      {rendered}
    </section>}

end VersoCast.Manual.Preview
