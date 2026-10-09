/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import Verso.Doc.Html
public import Verso.Output.Html

public section
namespace VersoCastTests.Fixture
open Verso Verso.Doc

-- Deliberately no JSON, equality or hashing instances: rendering needs none.
inductive InlineExtension where
  | highlight | hidden | unsupported

inductive BlockExtension where
  | notice | hidden | unsupported

@[expose] def genre : Doc.Genre where
  Inline := InlineExtension
  Block := BlockExtension
  PartMetadata := String
  TraverseContext := Unit
  TraverseState := Unit

instance : TraversePart genre := {}
instance : TraverseBlock genre := {}

instance : Html.GenreHtml genre Id where
  inline go extension children := do
    match extension with
    | .highlight => return .tag "mark" #[] (.seq (← children.mapM go))
    | .hidden => return .empty
    | .unsupported => return .seq (#[.text true "[unsupported inline]"] ++ (← children.mapM go))
  block _ go extension children := do
    match extension with
    | .notice => return .tag "aside" #[] (.seq (← children.mapM go))
    | .hidden => return .empty
    | .unsupported => return .seq (#[.text true "[unsupported block]"] ++ (← children.mapM go))
  part go label part := do
    let label : String := label
    let numberText := if label == "root" then "1. " else "1.1. "
    let header := fun level title => Output.Html.tag s!"h{level}" #[("id", s!"verso-section-{label}")]
      (.seq #[.text true numberText, title])
    return .tag "div" #[("data-fixture-section", label)] (← go part header)

def paragraph (text : String) : Block genre := .para #[.text text]

/-- One typed document shared by both backends, including nested extensions. -/
def document : Part genre := .mk #[.text "Offline comparison"] "Offline comparison"
  (some "root") #[
    .para #[.text "Plain ", .emph #[.text "emphasis"], .text " ",
      .bold #[.text "strong"], .text " ", .code "<script>unsafe()</script>",
      .text " ", .link #[.text "Lean"] "https://lean-lang.org/", .linebreak "\n",
      .math .inline "x < y", .math .display "x^2", .footnote "note" #[.text "Footnote body"],
      .image "Fixture image" "fixture.svg",
      .other .highlight #[.text "Highlighted ", .emph #[.text "nested emphasis"]],
      .other .hidden #[.other .highlight #[.text "HIDDEN INLINE"]],
      .other .unsupported #[.text "Unsupported inline child"]],
    .code "#check Nat\n-- <escaped>",
    .ul #[.mk #[paragraph "Unordered item"]],
    .ol 3 #[.mk #[paragraph "Ordered item"]],
    .dl #[.mk #[.text "Term"] #[paragraph "Definition"]],
    .blockquote #[paragraph "Quotation"],
    .other .notice #[paragraph "Notice child", .other .notice #[paragraph "Nested notice"]],
    .other .hidden #[.other .notice #[paragraph "HIDDEN BLOCK"]],
    .other .unsupported #[paragraph "Unsupported block child"],
    .concat #[paragraph "Concatenated paragraph"]
  ] #[.mk #[.text "Child section"] "Child section" (some "child")
      #[paragraph "Child content"] #[]]

def standardHtml : String :=
  let context : Html.HtmlT.Context genre := {
    options := {}, traverseContext := (), traverseState := (),
    definitionIds := {}, linkTargets := {}, codeOptions := {} }
  let rendered := (Html.ToHtml.toHtml document : Html.HtmlT genre Id Output.Html) context {}
  rendered.1.asString

end VersoCastTests.Fixture
