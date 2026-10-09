/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Manual
public import CastManualPreview.Extensions
public import Vir.Infoview
public import Vir.Infoview.Widget
public meta import Vir.Infoview.Widget
public meta import CastManualPreview.Server
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

-- Same public RPC/effect pattern as VIR's RpcReferenceWidget tutorial.
-- A single child type and stable inputs keep ordinary React state across edits.
private def Page : RuntimeM (FunctionComponent (Props.WithData Input)) := do
  let styles ← VersoCast.Renderer.Styles.create
  let renderers ← Extensions.create styles
  FunctionComponent.ofLean fun props => do
    let input : Input ← LeanRef.fromJSL (← Props.WithData.data props)
    let initializer ← Js.Function.ofLean0 (LeanRef.toJSL ({} : Response))
    js#let (value, setter) ← Hooks.useState initializer
    js#let (revision, setRevision) ← Hooks.useState (α := Nat) (← JsValue.ofNat 0)
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
          match Lean.Json.parse encoded >>= Lean.fromJson? with
          | .ok (document : Verso.Doc.Part Verso.Genre.Manual) =>
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
          Js.Nullable.ofJs (← VersoCast.Renderer.render styles doc
          (renderers := renderers))
    return ← <section>
      <p role="status">{Lean.Vir.ProofWidgets.Html.text state.status}</p>
      {rendered}
    </section>

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
