/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Manual.Preview
public import VersoCast.Manual.Codec
public import CastManualPreview.Extensions
public import Vir.Infoview
public import Vir.Infoview.Widget
public meta import Vir.Infoview.Widget
-- Widget elaboration snapshots the imported runtime implementations. Ordinary
-- opaque imports alone do not invalidate that snapshot when bodies change.
meta import all CastManualPreview.Extensions
meta import all VersoCast.Manual
meta import all VersoCast.Manual.Preview
meta import all VersoCast.Highlighting
meta import all VersoCast.Renderer
meta import all VersoCast.Renderer.Table
meta import Vir.Attributes

public section
namespace CastManualPreview
open Lean.Vir Lean.Vir.React Lean.Vir.Browser
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def decodeDocument (encoded : String) : Except String (Verso.Doc.Part Verso.Genre.Manual) :=
  Lean.Json.parse encoded >>= Lean.fromJson?

/-- Test-only typed path for live React and SSR, using the retained widget's
renderer without its editor/RPC shell or string decoder. -/
@[vir_export] def renderPart (document : Verso.Doc.Part Verso.Genre.Manual) : ReactM (Js Node) := do
  let styles ← VersoCast.Renderer.Styles.create
  VersoCast.Renderer.render styles document (renderers := (← Extensions.create styles))

@[vir_export] def renderDocument (encoded : String) : ReactM (Js Node) := do
  match decodeDocument encoded with
  | .error error => jsx%{<p role="alert">{ProofWidgets.Html.text error}</p>}
  | .ok document => renderPart document

-- Public component contract exercised without the editor wrapper below.
@[vir_export] def previewFactory (invalidated : Js.Function0 Unit)
    (loaded : Js.Function1 Js.Any Unit) :=
  VersoCast.Manual.Preview.create {
    createRenderers := fun styles => do
      let handlers ← Extensions.create styles
      pure fun _ => handlers
    onInvalidated := Js.Function.call0Void invalidated
    onLoaded := fun page => do
      let metadata ← js%{ "session" := page.session, "uri" := (← JsValue.ofString page.uri),
        "version" := (← JsValue.ofFloat page.version.toFloat),
        "snapshotRef" := page.snapshotRef }
      Js.Function.callVoid loaded (Js.erase metadata) }

@[vir_export] def previewProps (session : Js Infoview.RpcSession)
    (uri : Js String) (generation : Js.Any) := do
  Props.WithData.make (← LeanRef.toJSL
    ({ session, uri, generation } : VersoCast.Manual.Preview.Input))

@[vir_export]
def View : RuntimeM (FunctionComponent Infoview.PanelWidgetProps) := do
  let page ← VersoCast.Manual.Preview.create {
    createRenderers := fun styles => do
      let handlers ← Extensions.create styles
      pure fun _ => handlers }
  -- Minimal validation host only: source edits are handled by Preview; this
  -- wrapper does not yet observe same-version reprocessing/session restart.
  let generation ← JsValue.ofFloat 0
  FunctionComponent.ofLean fun props => do
    let session ← Infoview.useRpcSession
    let pos ← Infoview.PanelWidgetProps.pos props
    let uri ← Infoview.PanelPosition.uri pos
    let calculate ← Js.Function.ofLean0 do
      let input ← Props.WithData.make (← LeanRef.toJSL ({ session, uri, generation := Js.erase generation } : VersoCast.Manual.Preview.Input))
      Node.functionComponent page input (← Js.Array.empty)
    Hooks.useMemo calculate (← js#[Js.erase session, Js.erase uri])

vir_proof_widget View

def preparedWidgetProps : Infoview.WidgetProps :=
  { widgetProps with
    wasmPath := ".vir/runtime.wasm"
    setupHint := "Run node tools/setup-reference-manual.mjs --build from Verso Cast, then restart the Lean server." }

end CastManualPreview
