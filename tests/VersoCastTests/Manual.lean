/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Manual
meta import Vir.Attributes

public section
namespace VersoCastTests.Manual
open Verso Verso.Doc Lean SubVerso.Highlighting
open Lean.Vir Lean.Vir.React

private def code : Block Genre.Manual := .other {
  name := `Verso.Genre.Manual.InlineLean.Block.lean
  data := .arr #[toJson (Highlighted.text "def x := \"<script>\"\n"), .arr #[], .null, .null]
} #[.code "STORED_CHILD_MUST_NOT_RENDER_TWICE"]

private def output (kind : Highlighted.Span.Kind) (summarize : Bool) : Block Genre.Manual := .other {
  name := `Verso.Genre.Manual.InlineLean.Block.leanOutput
  data := toJson (({ severity := kind, contents := .text "<img src=x>\nmessage" } : Highlighted.Message),
    summarize, ([] : List Name))
} #[.code "OUTPUT_CHILD_MUST_NOT_RENDER_TWICE"]

private def malformed : Block Genre.Manual := .other {
  name := `Verso.Genre.Manual.InlineLean.Block.lean, data := .null
} #[.code "malformed source stays visible"]

@[vir_export] def render : ReactM (Js Node) := do
  let styles ← VersoCast.Renderer.Styles.create
  let renderers ← VersoCast.Manual.createRenderers styles
  let doc : Part Genre.Manual := .mk #[] "" none
    #[code, output .error false, output .warning true, output .info false, malformed,
      .other { name := `Unknown.manual, data := .null } #[.para #[.text "unknown children survive"]]] #[]
  VersoCast.Renderer.render styles doc { focus := some "part-root-block-0" } renderers

end VersoCastTests.Manual
