/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import CastSlides.Document
public import VersoSlides.Render

public section
namespace CastSlides
open Verso Verso.Doc VersoSlides

def document : Part Slides := %doc CastSlides.Document

/-- The demo publishes exactly one local asset; unknown paths are not guessed. -/
def previewImageUrl? : ImgSrc → Option String
  | .remote url => some url
  | .projectRelative "CastSlides/badge.svg" => some "images/badge.svg"
  | .projectRelative _ => none

def standardHtml : IO String := do
  let context : Html.HtmlT.Context Slides := {
    options := {}, traverseContext := (),
    traverseState := { imageFiles := ({} : Std.HashMap String String).insert "CastSlides/badge.svg" "badge.svg" },
    definitionIds := {}, linkTargets := {}, codeOptions := {} }
  let logger ← Logger.new
  let (html, _) ← (renderDocument {} document : Html.HtmlT Slides (BuildLogT IO) Output.Html) context {} |>.run logger
  if (← logger.failIfErrors) != 0 then throw (IO.userError "Slides HTML rendering failed")
  -- The deck shell, including its title/navigation, is client presentation.
  return (Output.Html.seq #[.tag "h1" #[] (.text true document.titleString), html]).asString

end CastSlides
