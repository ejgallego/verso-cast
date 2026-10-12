/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCastTests.Blog.Post
public import VersoBlog.Generate

public section
namespace VersoCastTests.Blog
open Verso Verso.Doc Verso.Genre.Blog

def document : Part Post :=
  let authored := %doc VersoCastTests.Blog.Post
  { authored with content := authored.content ++ #[
    .other (.message true { severity := .warning, contents := .text "Warning <script> & detail" } [])
      #[.code "MESSAGE_CHILD_MUST_NOT_RENDER_TWICE"],
    .other (.message false { severity := .info, contents := .text "Expanded information" } []) #[],
    .other (.docstringSection 1) #[
      .para #[.text "A ", .bold #[.text "docstring heading"]],
      .para #[.text "Docstring body <escaped>"],
      .blockquote #[.para #[.text "Nested docstring content"]]],
    .other (.docstringSection 5) #[.para #[.text "Deep docstring heading"]]] }

def byline : String :=
  match document.metadata with
  | none => ""
  | some metadata => metadata.date.toIso8601String ++ " · " ++ ", ".intercalate metadata.authors

/-- Existing Blog HTML, without Cast/VIR imports or a website theme/scripts. -/
def standardHtml : IO String := do
  let context : Html.HtmlT.Context Post := {
    options := {}, traverseContext := { config := {}, components := {} },
    traverseState := { remoteContent := {} }, definitionIds := {}, linkTargets := {}, codeOptions := {} }
  let input : Part Post := { document with metadata := document.metadata.map fun (metadata : Post.Meta) =>
    { metadata with htmlId := metadata.htmlId.map ("verso-" ++ ·) } }
  let action : Html.HtmlT Post ComponentM Output.Html := Html.ToHtml.toHtml input
  let logger ← Logger.new
  let ((html, _), _) ← ((action context {}).run {}).run {} |>.run logger
  if (← logger.failIfErrors) != 0 then throw (IO.userError "Blog HTML rendering failed")
  return (Output.Html.seq #[.tag "p" #[("data-post-byline", "true")] (.text true byline), html]).asString

end VersoCastTests.Blog
