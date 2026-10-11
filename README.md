# Verso Cast

Render `Verso.Doc.Part genre` as native React nodes through VIR, with client-owned
inline, block and section extensions. The same renderer supports live React and
offline HTML through React SSR.

Experimental. Requires Lean **4.35.0-rc4**; exact Verso and VIR revisions are
pinned in `lakefile.lean` and `lake-manifest.json`.

## Build and use

```sh
lake build
```

```lean
import VersoCast

def renderDocument (styles : VersoCast.Renderer.Styles)
    {genre : Verso.Doc.Genre} (document : Verso.Doc.Part genre) :
    Lean.Vir.React.ReactM (Lean.Vir.Js Lean.Vir.React.Node) :=
  VersoCast.Renderer.render styles document
```

Create `Renderer.Styles.create` once in the component factory. Styles are
read-only native values; each render constructs fresh props. Basic rendering
needs no JSON, equality or hashing instances. Supply `Renderer.Renderers genre`
for inline/block/metadata extensions. The opt-in Manual adapter is available
through `import VersoCast.Manual`; `import VersoCast.Blog` supports raw Page/Post
documents. The optional [Slides package](packages/slides/lakefile.lean) exposes
`import VersoCastSlides` and `VersoCast.Slides.createRenderers`; it does not add
a Slides dependency to the core package.

The renderer returns a subtree. Stateful extensions use stable ordinary React
components; extension callbacks themselves are not hook scopes. See the
[rendering guide](doc/RENDERING.md) for lazy children, identities, attributes,
focus and change highlighting.

## Optional math

```js
import katex from "katex";
import "katex/dist/katex.css";
import { createMathComponent } from "verso-cast/katex";

const MathFormula = createMathComponent(katex); // once, outside render
```

Pass it as `Renderer.Renderers.mathComponent?` on the Lean side. Clients supply
KaTeX, CSS/fonts and any formula preparation. The core Lean build needs neither
npm nor KaTeX. [Math API and demo](doc/RENDERING.md#optional-math-leaf).

## Demos and tests

```sh
lake build VersoCast VersoCastTests cast-assets cast-standard-html
lake test
npm ci
npx playwright install chromium
lake build VersoCastExamples
npm test
npm run demo
```

`demo` prints a local URL. For VS Code, open
[VersoCastShowcase.lean](examples/VersoCastShowcase.lean) and place the cursor
inside `showcase_ready`. The [development guide](doc/DEVELOPMENT.md) covers
runtime assets, individual tests and the three-way HTML comparison.

## Source map

| Location | Responsibility |
| --- | --- |
| `VersoCast/Renderer.lean` | Identity/change helpers and document traversal |
| `VersoCast/Renderer/Config.lean` | Extension hooks, attributes and render options |
| `VersoCast/Renderer/Style.lean` | Factory-owned native styles |
| `VersoCast/Fingerprint.lean` | Optional retained identity state |
| `VersoCast/RenderPath.lean` | Navigation addresses |
| `VersoCast/JsStrings.lean` | Cached native strings |
| `VersoCast/Manual.lean` | Manual adapter |
| `VersoCast/Blog.lean` | Shared Page/Post adapter |
| `VersoCast/Highlighting.lean` | Shared stored Lean-token presentation |
| `packages/slides/` | Optional Slides genre adapter, without navigation/widget ownership |
| `js/katex.mjs` | Optional math leaf |
| `examples/`, `tests/`, `tools/` | Demos, tests and development tooling |

## Scope

Clients prepare documents, resolve genre-specific references and numbering, and
provide their editor or widget integration. Cast does not elaborate documents
or run Verso traversal.

Renderer execution, including SSR, uses VIR. Native Lean C precompilation of
the renderer is unsupported at the pinned VIR revision.

[Attribution and license](ORIGIN.md).
