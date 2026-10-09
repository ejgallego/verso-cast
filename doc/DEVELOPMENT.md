# Development and validation

Run commands from the repository root. The Lean library build does not need npm;
JavaScript/browser checks and demos do. Build Lean before `npm ci`, because the
local VIR npm dependency lives in Lake's revision-locked checkout.

```sh
lake build VersoCast VersoCastTests VersoCastExamples cast-assets cast-standard-html
lake test
npm ci
npm test
```

The checked standalone consumer is separate:

```sh
(cd tests/downstream && lake build && lake exe consumer)
```

`.github/workflows/ci.yml` runs this sequence with no restored build caches on
Ubuntu 24.04 and Node 24, using SHA-pinned actions. It installs Chromium's system
dependencies with Playwright. The workflow is checked in, not a claim of a
successful remote CI run; no publish credentials or release step are present.

## Qualification

- Lean tests cover forced hash collisions, retirement/reordering, structural
  equality, extension identities, change detection and nested document forms.
  Change-policy tests cover coarse lists/quotes, extension children, fragments,
  deletions, counts and initial paths for a genre without equality instances.
- `tests/downstream` checks a separate consumer of the renderer's public Lean
  API (`lake build`) and native execution of its pure identity helpers
  (`lake exe consumer`). These are distinct gates.
- Real React assertions are in `tests/renderer-assertions.mjs`. Their runner uses
  the pinned VIR checkout's public npm entry points and host bindings, with the
  exact published runtime acquired through VIR's Lake resource API:

```sh
npm ci
npm run test:renderer
npm run test:widget
npm run test:identity
npm run test:offline
npm run test:math
npm run test:navigation
```

Run the Lean build before `npm ci`: the local npm dependency points to Lake's
revision-locked VIR checkout. `cast-assets` uses `Vir.Resources.Runtime.bundle`,
checks its compiler identity, and writes the declared Wasm payload to
`.vir/runtime.wasm`. The SSR test also checks its SHA-256. No Wasm source build,
private runtime adapter or old SDK is used. The legacy `:virSdk` download URL at
this pin returns HTTP 404; it is not part of this setup.

The Chromium test uses Playwright and the same Lean component as the widget.
It checks retained checkbox state and paragraph DOM identity through 20 prop
updates, functional callbacks, unmount and disposal. This is component/browser
acceptance, not an automated VS Code infoview test or a performance benchmark.
If Chromium is not installed, run `npx playwright install chromium` first.
The plain Lean build/test does not require npm or browser assets.

## Old-renderer parity and remaining gates

The reference is the extracted `packages/verso-react` source in VBP checkpoint
`9aa9d8892cf9c243e12771fc29418e9f2b777f3b`. Its Manual fixtures and key assertions
are retained here; this is not an execution comparison between the old 4.34
runtime and the current 4.35 runtime. Deliberate changes include generic genres,
part-metadata hooks, immutable extra attributes, no fixed document ID, and valid
inline footnotes instead of a block `details` element inside a paragraph.

| Area | Current evidence / boundary |
| --- | --- |
| Ordinary document forms, source math, escaping | Inherited Manual SSR assertions plus the shared Verso/SSR/live fixture |
| Extension replacement, fallback, hidden children | Inherited callbacks, counted generic-genre dispatch and lazy children; `test:offline` also checks part-hook order, local metadata stripping, fallback/default equivalence, header isolation and hidden sections |
| Identity collisions, duplicate contents, retirement | Pure typed-state tests and inherited key assertions |
| State through document edits | `test:identity`: live insertion, reorder, body edit, removal/reinsertion, duplicate semantic IDs; ordinary DOM retention and disposal |
| Focus/change diagnostics | `test:navigation`: SSR/Chromium exact block/heading/list paths, fragment propagation, description halves/shared item, hidden/missing paths, marker clearing, independent changes and retained DOM. Editor selection/follow-cursor acceptance remains with VBP |
| Computed change paths/counts | Pure policy tests plus `test:renderer` consuming real diff results: coarse list/quote edits, extension children, hidden paths and fragment markers. Counts describe comparison inputs, not visible DOM |
| Math typesetting | `test:math`: shared KaTeX leaf through the Lean document path in SSR/Chromium; source/mode updates, malformed recovery, escaping, macro isolation, retained DOM and disposal. Offline output is no longer empty |
| Blueprint informal blocks, external markup, math preludes | VBP-owned adapter and consumer parity gates; not inferred from Manual tests |
| Transport, codecs, FIR backend, editor shell | Separate owner-held integration gates; no private decoder or copied provider adopted here |

The retention fixture accepts each document and its corresponding
`Fingerprint.State` in one functional React state update. It uses public
`LeanRef` to retain that Lean value, not a private wire format or mutable identity
registry. Styles, component types and the counter updater are created once per
factory. The old VBP demo should remain until its own extension/widget parity
checks pass; Cast's fixture is not a substitute for them.

## Offline rendering and comparison

React nodes can be rendered to an HTML string with ReactDOMServer's
`renderToStaticMarkup`. No browser DOM or live widget is needed for that rendering;
browser-only effects do not run and the result is non-interactive. Extensions
intended for offline use must produce their content during rendering, not solely
in an effect. This is HTML text, not conversion into a Lean `Output.Html` tree.

```sh
npm run compare
npm run compare:serve
```

This generates `_out/comparison/index.html`, with live Cast/React, Cast/React SSR
and Verso's standard `ToHtml` renderer side by side. The Verso side first produces
`Output.Html` and calls `asString`; the Cast side uses the same typed document
and client-owned extension renderers. The live pane uses that same Lean component
and shared VIR asset/bootstrap setup, not another renderer implementation.
Serve the generated directory over HTTP so its live module/runtime can load;
opening the HTML directly from a file is only useful for the static panes.
`compare:serve` generates/checks the views and prints a local HTTP URL; stop it
with Ctrl-C. The fixture gives each pane its own anchor namespace.
Both static outputs and an observations report are saved alongside it.

The fixture covers inline/block/part-metadata hooks, a real React extension
component with retained hook state, nested extensions, hidden content, visible
unsupported children, numbered/anchored headings, lists, code escaping, links, footnotes and math
source. It deliberately has no JSON/equality/hash instances. Chromium checks
each backend's essential content and semantics; cross-backend differences are
reported rather than enforced as layout or universal output equivalence.
Cast SSR/live element and text structures must agree; this detects parser repair
that would otherwise be hidden by content-only checks. Verso's current footnote
repair is recorded, not required to remain as an upstream bug. The live pane
checks state/DOM retention through 20 redraws, no React nesting/runtime errors,
and disposal. Additional checks cover frozen style values, attribute precedence,
and exact callback counts for wide extension trees with hidden descendants.
The metadata contract probe additionally checks five paths: decline to fallback,
delegate once to the default, supply a custom heading, hide the root, and hide
one child. Exact event order ensures title/body work stays lazy and descendant
metadata is preserved; custom headings retain focus/change attributes without
leaking into metadata-free children. These counters exist only in test fixtures,
not in the core traversal.
CSS, wrappers and fallback wording may differ. Math remains untypeset in this
fixture. This is not a full Manual traversal/HTML-generation fidelity claim.
See [Fixture.lean](../tests/VersoCastTests/Fixture.lean) for the shared document and
Verso HTML instance, and [Offline.lean](../tests/VersoCastTests/Offline.lean) for the
corresponding Cast callbacks.

## Small widget boundary

For the richer standalone showcase, open `examples/VersoCastShowcase.lean` and
place the cursor inside `showcase_ready`. It defines its own genre, badge role,
callout directive, section-header adapter and ordinary React checkbox state.
It imports no test fixture or Blueprint code and reuses the same widget/assets
setup as the minimal example. Math typesetting is demonstrated separately by
`npm run test:math -- --serve`; it is not injected into this widget.

`examples/VersoCastDemo.lean` uses VIR's native-props `vir_proof_widget` mechanism:
one Manual document, one retained checkbox, and no custom server/RPC/shell. The
factory constructs styles once. Its registration and generated IR build pass;
live VS Code display has also been manually confirmed.

After `lake build` and `npm ci`:

```sh
lake exe cast-assets
lake build VersoCastExamples
code .
```

Open `examples/VersoCastDemo.lean` and place the cursor inside `castDemo_and_comm`.
The Lean extension's infoview loads VIR's dependency-owned widget module and the
prepared Wasm. No local widget bridge, JSON converter or provider abstraction is
added. The simpler `createProgram` resource facade cannot accept React host
bindings, so this experimental UI uses VIR's public custom-host APIs.

For a standalone browser view of the same component:

```sh
npm run demo
```

Open the printed local URL. The server serves only generated `_out/demo` files;
stop it with Ctrl-C. Math is source-preserving in this first example.
