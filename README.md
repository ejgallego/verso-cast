# Verso Cast

Cast displays [Verso](https://github.com/leanprover/verso) documents in React.
The renderer is written in Lean and runs through
[VIR](https://github.com/ejgallego/lean-vir). Use it to embed a document in an
interactive interface, such as a Lean infoview widget, or produce HTML through
React server rendering.

Cast works with any Verso genre. You can supply React renderers for your own
roles, directives and section metadata. Adapters are included for Manual and
Blog documents, with a separate optional package for Slides.

This is an experimental library, using Lean **4.35.0-rc4**.

## Try it

With Lean installed through elan and Node 24 available:

```sh
git clone https://github.com/ejgallego/verso-cast.git
cd verso-cast
lake build
npm ci
lake build VersoCastExamples
npm run demo
```

Open the printed URL to try a small document with a React checkbox. No browser
test installation is needed. To see the custom-genre showcase in VS Code instead:

```sh
lake exe cast-assets
code examples/VersoCastShowcase.lean
```

Place the cursor inside `showcase_ready`. The widget shows an inline badge,
a callout directive and custom section headings. See the
[development guide](doc/DEVELOPMENT.md#demos) for the HTML comparisons,
math demo and Lean reference-manual preview.

## Use Cast in a project

Use the same Lean toolchain and pin a Cast commit in your lakefile:

```lean
require «verso-cast» from git
  "https://github.com/ejgallego/verso-cast" @ "<cast-commit>"
```

Given an existing Verso document, this creates a React component that displays it:

```lean
import VersoCast
open VersoCast Lean.Vir Lean.Vir.React

def createView {genre : Verso.Doc.Genre} (document : Verso.Doc.Part genre) :
    RuntimeM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  FunctionComponent.ofLean fun _ => Renderer.render styles document
```

The styles are created once and reused when React renders the component.
The [showcase source](examples/VersoCastShowcase.lean) shows how to add extension
renderers and register the component as a widget. The
[rendering guide](doc/RENDERING.md) covers the API, genre adapters, math,
and retaining state across document edits.

## What Cast provides

Cast renders the document you give it; your application owns document
preparation, reference resolution, assets and the surrounding interface.
Unsupported extensions remain visible with their children. This is not a
replacement for Verso's website generation or a Reveal.js presenter.

The same rendering callbacks work in live React and React server rendering.
An optional KaTeX component typesets math; without it, math source stays visible.
Renderer execution requires VIR; native Lean C execution is not supported.

For contributing, build instructions and tests, see the
[development guide](doc/DEVELOPMENT.md). Cast is licensed under Apache-2.0;
see [attribution](ORIGIN.md) and [LICENSE](LICENSE).
