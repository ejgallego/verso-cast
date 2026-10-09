/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Manual
meta import Vir.Attributes

public section
namespace VersoCastTests.Manual
open Verso Verso.Doc Lean SubVerso.Highlighting
open Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js

private def code : Block Genre.Manual := .other {
  name := `Verso.Genre.Manual.InlineLean.Block.lean
  data := .arr #[toJson (Highlighted.seq #[.token { content := "def", kind := .keyword none none none },
    .text " x := \"<script>\"\n"]), .arr #[], .null, .null]
} #[.code "STORED_CHILD_MUST_NOT_RENDER_TWICE"]

private def output (kind : Highlighted.Span.Kind) (summarize : Bool) : Block Genre.Manual := .other {
  name := `Verso.Genre.Manual.InlineLean.Block.leanOutput
  data := toJson (({ severity := kind, contents := .text "<img src=x>\nmessage" } : Highlighted.Message),
    summarize, ([] : List Name))
} #[.code "OUTPUT_CHILD_MUST_NOT_RENDER_TWICE"]

private def malformed : Block Genre.Manual := .other {
  name := `Verso.Genre.Manual.InlineLean.Block.lean, data := .null
} #[.code "malformed source stays visible"]

private def table (columns : Nat) : Block Genre.Manual := .other {
  name := `Verso.Genre.Manual.Block.table
  data := toJson (columns, true, (none : Option String), (none : Option Json),
    (none : Option Verso.Genre.Manual.TableConfig.Alignment))
} #[.ul #[.mk #[.para #[.text "First heading"]], .mk #[.para #[.text "Second heading"]],
    .mk #[.para #[.text "First cell"]], .mk #[.para #[.text "Second cell"]]]]

@[vir_export] def render : ReactM (Js Node) := do
  let styles ← VersoCast.Renderer.Styles.create
  let renderers ← VersoCast.Manual.createRenderers styles
  let doc : Part Genre.Manual := .mk #[] "" none
    #[code, output .error false, output .warning true, output .info false, malformed,
      .para #[.other {
        name := `Verso.Genre.Manual.InlineLean.Inline.lean
        data := .arr #[toJson (Highlighted.text "<inline>"), .arr #[]] } #[]],
      .other { name := `Verso.Genre.Manual.Block.docstringSection, data := toJson "Fields" }
        #[.para #[.text "documentation children"]],
      .other {
        name := `Verso.Genre.Manual.InlineLean.Block.syntaxError
        data := toJson ("bad <source>", #[Lean.Json.mkObj [("text", toJson "expected term")]]) } #[],
      .other { name := `Unknown.manual, data := .null } #[.para #[.text "unknown children survive"]],
      table 2, table 0,
      .other {
        name := `Verso.Genre.Manual.Block.internalSignature
        data := toJson (Highlighted.text "Internal.name", (some (Highlighted.text "Nat") : Option Highlighted)) }
        #[.para #[.text "internal documentation"]],
      .other {
        name := `Verso.Genre.Manual.Block.fieldSignature
        data := toJson (Verso.Genre.Manual.Block.Docstring.Visibility.private,
          Highlighted.text "field", Highlighted.text "Nat", (some 0 : Option Nat), #[Highlighted.text "Parent"]) }
        #[.para #[.text "field documentation"]],
      .other {
        name := `Verso.Genre.Manual.InlineLean.Block.exampleFile
        data := toJson Verso.Genre.Manual.InlineLean.FileType.stdin } #[.code "input <text>"],
      .other {
        name := `Verso.Genre.Manual.InlineLean.Block.exampleLeanFile
        data := toJson "Example.lean" } #[.code "def example := 1"]] #[]
  VersoCast.Renderer.render styles doc { focus := some "part-root-block-0" } renderers

/-- Debug changes attributes, not navigation, highlighting or React identity. -/
@[vir_export] def renderDebug (debug : Bool) : ReactM (Js Node) := do
  let styles ← VersoCast.Renderer.Styles.create
  let para : Block .none := .para #[.text "ordinary content"]
  let doc : Part .none := .mk #[.text "Debug defaults"] "Debug defaults" none
    #[para, .ul #[.mk #[para]], .dl #[.mk #[.text "term"] #[para]],
      .concat #[para]] #[.mk #[.text "Child section"] "Child section" none #[para] #[]]
  VersoCast.Renderer.render styles doc {
    debug, focus := some "part-root-block-0", changedIds := #["part-root-block-0"] }

/-- Invalid table shapes must not consume cells before delegating to fallback. -/
@[vir_export] def tableWork (count columns : Nat) : ReactM Nat := do
  let styles ← VersoCast.Renderer.Table.Styles.create
  let visits ← RuntimeRef.new (0 : Nat)
  let cells := (List.range count).toArray.map fun index => fun _ : Unit => do
    visits.modify (· + 1)
    let props ← js%{ "key" := (← JsValue.ofString (toString index)) }
    let text ← Node.text (← js#"cell")
    return (props, #[text])
  let _ ← VersoCast.Renderer.Table.render styles (← Js.Object.empty) columns true cells
  visits.get

end VersoCastTests.Manual
