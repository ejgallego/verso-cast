/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import VersoCastSlides

open VersoCast VersoSlides Lean.Vir Lean.Vir.React

-- Only the package root is imported; no demo/internal implementation import.
example (styles : Renderer.Styles) : ReactM (Renderer.Renderers Slides) :=
  VersoCast.Slides.createRenderers styles

example (styles : Renderer.Styles) (resolve : ImgSrc → Option String) :
    ReactM (Renderer.Renderers Slides) :=
  VersoCast.Slides.createRenderers styles resolve

-- Runtime behavior is checked by Contract; these need no elaborator imports.
def localImage : Option String := VersoCast.Slides.imageUrl? (.projectRelative "badge.svg")
def remoteImage : Option String :=
  VersoCast.Slides.imageUrl? (.remote "https://example.invalid/badge.svg")

-- The documented component factory, through the public root alone.
def createSlidesView (document : Verso.Doc.Part Slides) : ReactM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let handlers ← VersoCast.Slides.createRenderers styles
  FunctionComponent.ofLean fun _ => Renderer.render styles document (renderers := handlers)

/-- error: Unknown identifier `VersoCast.Slides.Code.decode` -/
#guard_msgs in
#check VersoCast.Slides.Code.decode
