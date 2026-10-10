/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Adapted from VersoSlides/TestFixtures/Markup.lean (David Thrane Christiansen).
Reduced preview fixture: Emilio J. Gallego Arias. -/
module
public import VersoSlides.Basic
public import Verso.Doc.Concrete
public meta import VersoSlides.Directives
public meta import VersoSlides.OtherLanguages
open VersoSlides

#doc (Slides) "Slides Preview" =>

# Introduction
A *small* deck with [a link](https://lean-lang.org).

:::notes
Speaker notes remain inspectable in this preview.
:::

:::fragment fadeUp (index := 2)
First fragment.

Second fragment.
:::

:::hstack
Left column.

Right column.
:::

# Vertical Group
%%%
vertical := some true
%%%
Implicit first vertical slide.

## Sub A
%%%
backgroundColor := some "#e9f5ef"
%%%
Sub-slide A.

::::class "nested-one"
:::class "nested-two"
Nested decoration.
:::
::::

## Sub B
Sub-slide B, with {fragment (style := highlightRed)}[inline emphasis].

# Data
:::table +colHeaders +border
* + Name
  + Value
* + x
  + 42
:::

Inline math stays as source: $`x^2 + y^2`.

An inline {class "slide-badge"}[class role] and escaped source:

```code javascript
const message = "<escaped>";
```
