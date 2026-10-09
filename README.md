# Verso Cast

Genre-agnostic rendering of `Verso.Doc.Part genre` as native React nodes through
VIR. Clients supply their own extension renderers. Cast adds no Blueprint
dependency, alternative document model, editor protocol or runtime.

Experimental, local-only source checkpoint. Lean **4.35.0-rc4** and exact
Verso/VIR revisions are pinned in `lakefile.lean` and `lake-manifest.json`.
The npm package remains private; no registry release has been made.

## Build and use

```sh
lake build
```

Consumers import `VersoCast`:

```lean
import VersoCast

def renderDocument (styles : VersoCast.Renderer.Styles)
    {genre : Verso.Doc.Genre} (document : Verso.Doc.Part genre) :
    Lean.Vir.React.ReactM (Lean.Vir.Js Lean.Vir.React.Node) :=
  VersoCast.Renderer.render styles document
```

Create `Renderer.Styles.create` once in the component factory. Styles are
read-only native values; each render constructs fresh props. Basic rendering
needs no JSON, equality or hashing instances. Use `Renderer.Renderers genre`
for inline/block/metadata extensions. For Manual, explicitly import
`VersoCast.Manual`; it is not part of the core import.

The renderer returns a subtree, not a React root or a widget. Stateful
extensions return stable ordinary React components; extension callbacks
themselves are not hook scopes. See the [rendering guide](doc/RENDERING.md) for
identities, lazy children, attributes, focus and change highlighting.

## Optional math

The optional JS entry point supplies one shared live/offline React leaf:

```js
import katex from "katex";
import "katex/dist/katex.css";
import { createMathComponent } from "verso-cast/katex";

const MathFormula = createMathComponent(katex); // once, outside render
```

Pass it as `Renderer.Renderers.mathComponent?` on the Lean side. Clients own
KaTeX, CSS/fonts and formula/prelude preparation. The Lean library does not
require npm or KaTeX. [Math contract and demo](doc/RENDERING.md#optional-math-leaf).

## Try and test

From a source checkout:

```sh
lake build VersoCast VersoCastTests VersoCastExamples cast-assets cast-standard-html
lake test
npm ci
npm test
npm run demo
```

`demo` prints a loopback URL. The [development guide](doc/DEVELOPMENT.md)
covers the small VS Code widget, the three-way Verso/live React/offline
comparison, individual test commands, runtime assets and qualification limits.

## Source map

| Location | Responsibility |
| --- | --- |
| `VersoCast/Renderer.lean` | Identity/change helpers and document traversal |
| `VersoCast/Renderer/Config.lean` | Extension hooks, attributes and render options |
| `VersoCast/Renderer/Style.lean` | Factory-owned native styles |
| `VersoCast/Fingerprint.lean` | Optional pure retained identity state |
| `VersoCast/Manual.lean` | Opt-in Manual adapter |
| `js/katex.mjs` | Optional JS library leaf; exported as `verso-cast/katex` |
| `examples/` | Small Lean widget and standalone browser example |
| `tests/` | Lean, SSR and Chromium fixtures; browser entries in `tests/browser/` |
| `tools/` | Development-only staging, serving and browser bootstrap |

`import VersoCast` continues to expose the renderer and its configuration/style
names. The file split introduces no new runtime layer. Fixed native strings
remain in `JsStrings.lean`; navigation addresses remain in `RenderPath.lean`.

## Integration status

Generic rendering, extension contracts, live state/DOM retention, focus and
optional KaTeX have local SSR/browser coverage. Blueprint semantics and its
consumer parity remain VBP-owned: see the
[consumer migration guide](doc/CONSUMER_MIGRATION.md). Codec/FIR/editor-shell
qualification is separate. The full renderer's native Lean C precompilation is
not qualified; offline HTML currently uses React SSR through VIR.

[Extraction provenance](ORIGIN.md) records the source and deliberate changes.
Publication still needs a fresh-checkout CI gate and consumer review.
