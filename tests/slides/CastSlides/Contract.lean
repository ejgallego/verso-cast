/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import CastSlides.Renderers
meta import Vir.Attributes

public section
namespace CastSlides.Contract
open Verso Verso.Doc VersoSlides VersoCast Lean.Vir Lean.Vir.React

private def leaf : Block Slides := .other (.otherLanguage "text" "<payload>") #[]

private def run (kind field : String) : ReactM (Js Node × Nat) := do
  let styles ← Renderer.Styles.create
  let base ← createRenderers styles
  let visits ← RuntimeRef.new (0 : Nat)
  let handlers : Renderer.Renderers Slides := { base with
    renderBlock? := fun key attributes extension children => do
      if let .otherLanguage .. := extension then visits.modify (· + 1)
      base.renderBlock? key attributes extension children }
  let fields := #[("class", "retained"), (field, "value")]
  let block : Block Slides := match kind with
    | "attr" => .other (.attr fields) #[leaf]
    | "wrap" => .other (.wrap fields) #[leaf]
    | "styled" => .para #[.other (.styled fields) #[.text "<payload>"]]
    | "nested" => .other (.attr #[("class", "outer"), ("title", "outer title"), ("data-probe", "ok")])
        #[.concat #[leaf, .other (.attr #[("class", "inner"), ("title", "inner title")]) #[leaf]]]
    | "zero-columns" => .other (.table 0 {}) #[.ul #[.mk #[leaf]]]
    | "incomplete-row" => .other (.table 2 {}) #[.ul #[.mk #[leaf]]]
    | "row-headers" => .other (.table 1 { rowHeaders := true }) #[.ul #[.mk #[leaf]]]
    | "cell-gap" => .other (.table 1 { cellGap := some "2em" }) #[.ul #[.mk #[leaf]]]
    | _ => .other (.table 1 {}) #[.ul #[.mk #[leaf]]]
  let input : Part Slides := .mk #[.text "Contract"] "Contract" none #[block] #[]
  let node ← Renderer.render styles input {
    focus := some "part-root-block-0", changedIds := #["part-root-block-0"] } handlers
  return (node, ← visits.get)

@[vir_export] def render (kind field : String) : ReactM (Js Node) := do
  return (← run kind field).1

@[vir_export] def visits (kind field : String) : ReactM Nat := do
  return (← run kind field).2

/-- Image paths are resolved by the client; every image has fresh dimensions. -/
@[vir_export] def renderImages (mapped : Bool) : ReactM (Js Node) := do
  let styles ← Renderer.Styles.create
  let resolveImage : ImgSrc → Option String := fun source =>
    match source with
    | .projectRelative "known.svg" => if mapped then some "published/known.svg" else none
    | _ => imageUrl? source
  let handlers ← createRenderers styles resolveImage
  let input : Part Slides := .mk #[.text "Images"] "Images" none #[.para #[
    .other (.image (.remote "https://example.invalid/remote.svg") "Remote <image>" (some "10px") (some "12px") (some "remote-image")) #[],
    .other (.image (.projectRelative "known.svg") "Local" (some "80px") none (some "local-image")) #[],
    .other (.image (.projectRelative "missing.svg") "Missing" none none none) #[.text "Unresolved children"],
    .other (.image (.remote "") "Empty" none none none) #[.text "Empty URL children"]
  ]] #[]
  Renderer.render styles input (renderers := handlers)

private def sampleCode : SlideCode := .seq #[
  .hl (.token { kind := .unknown, content := "start\n" }),
  .hl (.token { kind := .unknown, content := "second\n" }),
  .fragment { style := some "fade-up", index := some 7 } true (.hl (.text "block\n")),
  .fragment { style := none, index := none } false (.hl (.text "<inline>")),
  .click (.hl (.text "click")) (some 9),
  .tactics #[] 4 12 (.hl (.text "tactic")),
  .span #[(.warning, .text "HIDDEN HOVER")] (.hl (.text "warn")),
  .commandOutput #[(.info, .text "5"), (.error, .text "<failure>")] ]

/-- Exercise both stored export formats through the actual adapter. -/
@[vir_export] def renderCode (source : String) (block simple : Bool) : ReactM (Js Node) := do
  let styles ← Renderer.Styles.create
  let handlers ← createRenderers styles
  let encoded := if !source.isEmpty then source else
    if simple then SubVerso.Highlighting.hlToExport (.text "simple <code>") else scToExport sampleCode
  let content : Array (Block Slides) := if block then
    #[.other (if simple then .leanCode encoded true else .slideCode encoded true true)
      #[.code "FALLBACK SOURCE"]]
    else #[.para #[.other (if simple then .leanCode encoded else .slideCode encoded)
      #[.text "FALLBACK SOURCE"]]]
  Renderer.render styles (.mk #[.text "Code"] "Code" none content #[]) (renderers := handlers)

end CastSlides.Contract
