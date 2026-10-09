/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast
meta import Vir.Attributes

public section
namespace VersoCastTests.Math
open VersoCast Lean.Vir Lean.Vir.React

/-- Test the ordinary document path with a caller-owned native math component.
No Manual/Blueprint adapter or additional host binding is involved. -/
@[vir_export] def render (math : FunctionComponent Props) (source : String)
    (display : Bool) : ReactM (Js Node) := do
  let styles ← Renderer.Styles.create
  let document : Verso.Doc.Part .none := .mk #[] "" none
    #[.para #[.math (if display then .display else .inline) source]] #[]
  Renderer.render styles document (renderers := { mathComponent? := some math })

end VersoCastTests.Math
