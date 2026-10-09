/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module

public import VersoCast
public import Vir.Infoview.Widget
public meta import Vir.Infoview.Widget
meta import Vir.Attributes

public section

namespace VersoCastDemo

open Verso Lean.Vir Lean.Vir.React Lean.Vir.Infoview
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def paragraph (text : String) : Doc.Block Genre.Manual :=
  .para #[.text text]

private def document (extra : Bool) : Doc.Part Genre.Manual :=
  .mk #[.text "Verso Cast"] "Verso Cast" none
    (#[
      .para #[.text "An ordinary ", .emph #[.text "Verso Manual"],
        .text " document rendered by a Lean-authored React component."],
      .ul #[.mk #[paragraph "Native React nodes"], .mk #[paragraph "Retained component state"]],
      .para #[.text "Math remains source-preserving: ", .math .inline "x^2 + y^2 = z^2"]
    ] ++ if extra then #[.blockquote #[paragraph "This extra block is controlled by React state."]]
      else #[]) #[]

-- One factory result per mounted widget. Styles and the updater are created once.
@[vir_export]
def View : RuntimeM (FunctionComponent PanelWidgetProps) := do
  let styles ← VersoCast.Renderer.Styles.create
  let initial ← JsValue.ofBool false
  let toggle ← Js.Function.ofLean fun (previous : Js Bool) => Js.Boolean.not previous
  FunctionComponent.ofLean fun _ => do
    js#let (extra, setter) ← Hooks.useState (α := Bool) initial
    let change ← Js.Function.ofLeanVoid fun (_ : Js SyntheticEvent) =>
      Js.Function.callVoid setter (SetStateAction.ofUpdater toggle)
    let rendered ← VersoCast.Renderer.render styles (document (← JsValue.toBool extra))
    return ← <div data-testid="cast-demo">
      <label><input type="checkbox" checked={extra} onChange={change}/> Show an extra block</label>
      {pure rendered}
    </div>

vir_proof_widget View

def preparedWidgetProps : WidgetProps :=
  { widgetProps with
    wasmPath := ".vir/runtime.wasm"
    setupHint := "Run lake exe cast-assets, then restart the Lean server or reopen this file." }

end VersoCastDemo

show_panel_widgets [local Lean.Vir.Infoview.widget with VersoCastDemo.preparedWidgetProps]

theorem castDemo_and_comm (p q : Prop) : p ∧ q → q ∧ p := by
  intro h
  exact ⟨h.right, h.left⟩
