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

end CastSlides.Contract
