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
@[vir_export] def previewFactory :=
  VersoCast.Manual.Preview.create {
    createRenderers := fun styles => do
      let handlers ← Extensions.create styles
      pure fun _ _ => handlers }

-- Test-only observation after React commit: verify provenance inside the actual
-- Lean snapshot, not merely the envelope retained by the native request hook.
private def previewInfo (value : JSL VersoCast.Manual.Preview.Snapshot) : RuntimeM Js.Object := do
  let snapshot : VersoCast.Manual.Preview.Snapshot ← LeanRef.fromJSL value
  let page := snapshot.page
  js%{ "session" := page.session, "uri" := (← JsValue.ofString page.uri),
    "version" := (← JsValue.ofFloat page.version.toFloat), "snapshotRef" := page.snapshotRef,
    "hasErrors" := (← JsValue.ofBool page.hasErrors) }

-- Trusted native function supplied by our registered Widget.Module below.
-- This changes only the phantom type, not the value or its identity.
private def pageHost (value : Js.Any) : FunctionComponent Props := by
  unfold FunctionComponent Js.Function1 Js.Any Js at *
  exact value

@[vir_export]
def View : RuntimeM (FunctionComponent Infoview.PanelWidgetProps) := do
  let bridge ← previewFactory
  let inspect ← Js.Function.ofLean previewInfo
  FunctionComponent.ofLean fun props => do
    let pos ← Infoview.PanelWidgetProps.pos props
    let uri ← Infoview.PanelPosition.uri pos
    let host := pageHost (← Js.Object.get props (← js#"pageHost"))
    let input ← js%{ "uri" := uri, "decode" := bridge.decode, "view" := bridge.view,
      "inspect" := inspect,
      "selection" := (← Js.Object.get props (← js#"selection")) }
    Node.functionComponent host input (← Js.Array.empty)

vir_proof_widget View

@[widget_module] def widget : Lean.Widget.Module where
  javascript := (include_str "Widget.mjs").replace "__VIR_SHELL__"
    ("widget_module:hash," ++ toString Lean.Vir.Infoview.widget.javascriptHash.val)

def preparedWidgetProps : Infoview.WidgetProps :=
  { widgetProps with
    wasmPath := ".vir/runtime.wasm"
    setupHint := "Run node tools/setup-reference-manual.mjs --build from Verso Cast, then restart the Lean server." }

end CastManualPreview
