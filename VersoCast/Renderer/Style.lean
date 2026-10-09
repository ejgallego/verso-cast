/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

module

public import Vir.React
public import VersoCast.JsStrings

/-! Factory-owned native styles. Values are borrowed by each fresh node's props. -/
public section
namespace VersoCast.Renderer
open Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js

namespace Style

private def vscodeColor (name fallback : String) : String :=
  "var(--vscode-" ++ name ++ ", " ++ fallback ++ ")"

private def border (color : String) : String :=
  "1px solid " ++ color

def foreground : String := vscodeColor "editor-foreground" "#24292f"
def muted : String := vscodeColor "descriptionForeground" "#57606a"
def background : String := vscodeColor "editor-background" "#ffffff"
def codeBackground : String := vscodeColor "textCodeBlock-background" "#f6f8fa"
def borderColor : String := vscodeColor "panel-border" "#d0d7de"

def document : ReactM (Js Props) :=
  js%{
    "display" := (← js#"grid"),
    "gap" := (← js#"10px"),
    "minWidth" := (← js#"0"),
    "padding" := (← js#"10px 12px"),
    "border" := (← JsValue.ofString (border borderColor)),
    "borderRadius" := (← js#"6px"),
    "background" := (← JsValue.ofString background),
    "color" := (← JsValue.ofString foreground),
    "colorScheme" := (← js#"light dark"),
    "fontFamily" := (← js#"Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"),
    "overflowWrap" := (← js#"anywhere")
  }
def part : ReactM (Js Props) :=
  js%{
    "display" := (← js#"grid"),
    "gap" := (← js#"10px"),
    "minWidth" := (← js#"0")
  }
def heading : ReactM (Js Props) :=
  js%{
    "margin" := (← js#"0"),
    "fontSize" := (← js#"1.12rem"),
    "lineHeight" := (← js#"1.3")
  }
def paragraph : ReactM (Js Props) :=
  js%{
    "margin" := (← js#"0"),
    "lineHeight" := (← js#"1.5")
  }
def list : ReactM (Js Props) :=
  js%{
    "display" := (← js#"grid"),
    "gap" := (← js#"6px"),
    "margin" := (← js#"0"),
    "paddingLeft" := (← js#"1.5rem")
  }
def listItem : ReactM (Js Props) :=
  js%{
    "paddingLeft" := (← js#"0.15rem")
  }
def blockquote : ReactM (Js Props) :=
  js%{
    "display" := (← js#"grid"),
    "gap" := (← js#"8px"),
    "margin" := (← js#"0"),
    "padding" := (← js#"2px 0 2px 12px"),
    "borderLeft" := (← JsValue.ofString (border borderColor)),
    "color" := (← JsValue.ofString muted)
  }
def descriptionList : ReactM (Js Props) :=
  js%{
    "display" := (← js#"grid"),
    "gridTemplateColumns" := (← js#"max-content minmax(0, 1fr)"),
    "gap" := (← js#"6px 10px"),
    "margin" := (← js#"0")
  }
def descriptionTerm : ReactM (Js Props) :=
  js%{
    "fontWeight" := (← js#"700")
  }
def descriptionValue : ReactM (Js Props) :=
  js%{
    "margin" := (← js#"0")
  }
def inlineCode : ReactM (Js Props) :=
  js%{
    "padding" := (← js#"0.08em 0.3em"),
    "borderRadius" := (← js#"3px"),
    "background" := (← JsValue.ofString codeBackground),
    "fontFamily" := (← js#"ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"),
    "fontSize" := (← js#"0.92em")
  }
def codeBlock : ReactM (Js Props) :=
  js%{
    "margin" := (← js#"0"),
    "padding" := (← js#"9px 10px"),
    "overflow" := (← js#"auto"),
    "borderRadius" := (← js#"5px"),
    "background" := (← JsValue.ofString codeBackground),
    "fontFamily" := (← js#"ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"),
    "fontSize" := (← js#"0.78rem"),
    "lineHeight" := (← js#"1.45"),
    "whiteSpace" := (← js#"pre")
  }
def mathInline : ReactM (Js Props) :=
  js%{
    "padding" := (← js#"0 0.08em"),
    "fontFamily" := (← js#"KaTeX_Main, Cambria Math, STIX Two Math, serif"),
    "fontSize" := (← js#"1.02em"),
    "whiteSpace" := (← js#"pre-wrap")
  }
def mathDisplay : ReactM (Js Props) :=
  js%{
    "display" := (← js#"block"),
    "padding" := (← js#"8px 10px"),
    "overflowX" := (← js#"auto"),
    "borderRadius" := (← js#"5px"),
    "background" := (← JsValue.ofString codeBackground),
    "fontFamily" := (← js#"KaTeX_Main, Cambria Math, STIX Two Math, serif"),
    "fontSize" := (← js#"1.02em"),
    "lineHeight" := (← js#"1.5"),
    "textAlign" := (← js#"center"),
    "whiteSpace" := (← js#"pre-wrap")
  }
def unsupported : ReactM (Js Props) :=
  js%{
    "padding" := (← js#"7px 9px"),
    "border" := (← JsValue.ofString (border borderColor)),
    "borderRadius" := (← js#"5px"),
    "color" := (← JsValue.ofString muted)
  }

end Style

/-- Constant styles owned by one component factory. Treat these objects as read-only;
node attributes remain fresh. CSS variables keep theme changes independent of React updates. -/
structure Styles where
  strings : JsStrings.Fixed
  document : Js Props
  part : Js Props
  heading : Js Props
  paragraph : Js Props
  list : Js Props
  listItem : Js Props
  blockquote : Js Props
  descriptionList : Js Props
  descriptionTerm : Js Props
  descriptionValue : Js Props
  inlineCode : Js Props
  codeBlock : Js Props
  mathInline : Js Props
  mathDisplay : Js Props
  unsupported : Js Props

def Styles.create : ReactM Styles := do
  return {
    strings := ← JsStrings.Fixed.create
    document := ← Style.document, part := ← Style.part, heading := ← Style.heading
    paragraph := ← Style.paragraph, list := ← Style.list, listItem := ← Style.listItem
    blockquote := ← Style.blockquote, descriptionList := ← Style.descriptionList
    descriptionTerm := ← Style.descriptionTerm, descriptionValue := ← Style.descriptionValue
    inlineCode := ← Style.inlineCode, codeBlock := ← Style.codeBlock
    mathInline := ← Style.mathInline, mathDisplay := ← Style.mathDisplay
    unsupported := ← Style.unsupported
  }

end VersoCast.Renderer
