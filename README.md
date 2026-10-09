# Verso Cast

Experimental native React rendering of `Verso.Doc.Part genre`
through VIR, with client-owned genre extensions. No Blueprint dependency,
alternative document model or runtime implementation. This is a local extraction
checkpoint, not a published package.

## Build

Lean **4.35.0-rc4**, with exact Verso and VIR revisions in `lakefile.lean` and
`lake-manifest.json`:

```sh
lake build
lake test
```

Consumers import `VersoCast`. The main helper is:

```lean
import VersoCast

def renderDocument (styles : VersoCast.Renderer.Styles)
    {genre : Verso.Doc.Genre} (document : Verso.Doc.Part genre) :
    Lean.Vir.React.ReactM (Lean.Vir.Js Lean.Vir.React.Node) :=
  VersoCast.Renderer.render styles document
```

Create `Renderer.Styles.create` once in the component factory and capture the
result in its render callback. Styles are read-only native JavaScript objects;
the renderer constructs fresh node attributes. It returns a React subtree, not
a root, state store, widget, editor protocol or asset publisher.

`Renderer.Renderers genre` supplies optional inline/block and part-metadata
render helpers. Pass it explicitly as `renderers := myRenderers`; no global
registry is needed. Callbacks receive the genre's own extension values and lazy
child-rendering callbacks. Returning `none` selects the default output. Unknown
inline/block extensions remain visible with their original children; part
metadata defaults to the ordinary section layout. The part hook receives the
typed part without its own metadata. `renderDefault none` uses the ordinary
heading; `renderDefault (some header)` customizes numbering, anchors or title
presentation without copying section traversal. The heading callback receives
its level (clamped to h6), fresh key/focus/change attributes and title nodes.
It should return the matching hN element. Descendant metadata is preserved.
Call each child/default callback at most once and return `some` after using it;
returning `none` delegates to fallback rendering. No memoization or registry
scan is added to extension handling.
These helpers are not hook scopes: do not call React hooks inside them.
Inline extensions must return phrasing content. Cast footnotes use inline
`span`/`sup` markup rather than invalid `details` inside paragraphs.
Stateful extensions should return a normal component node with a stable component
function. Roles/directives already elaborate into Verso nodes; Cast does not
register or elaborate them again. Resolved references, numbering and other
traversal-dependent data remain client/genre responsibilities.
Math defaults to source-preserving output; a caller can supply a stable
`mathComponent?` leaf. No KaTeX bundle is included at this checkpoint.

Basic rendering requires no JSON, equality or hash instances and uses positional
keys. `Renderers.blockIdentity?` can supply semantic extension keys, while
`Renderers.fingerprint` optionally supplies content identities. For Manual,
import `VersoCast.Manual` and extend `Manual.renderers`; this adapter preserves
named placeholders and the previous stateless serialized-content key policy.
The core `VersoCast` import does not import Manual.

For retained documents, keep `Fingerprint.State genre` in component state and
advance it with `Renderer.prepareIdentities` when document content changes.
This opt-in path requires equality/hash instances for the genre's extensions.
Pass `{ fingerprint? := some (fun value => some (identities.key value)) }` as
render options, using the state prepared for that document. Preparation is pure
and resolves hash collisions with exact equality. React keys are sibling-local;
navigation paths are separate.
Cursor/control changes need not recompute content identities.

Pass a current-document state's key function only in `Options.fingerprint?`.
The `changedBlockIds*` helpers compare both documents using the stateless
`Renderers.fingerprint` policy; a state prepared only for the new document may
not contain the old values. These helpers track raw heading/block contents,
not part metadata, presentation changes or extension visibility. Preparation
visits all stored blocks, including hidden content; it does not call render
callbacks. Neither identity helper is a promise of linear whole-document cost.

Extra root/math attributes are immutable `Array Renderer.Attribute` values.
`Attribute.of nativeKey nativeValue` only widens the native value's phantom type;
it performs no conversion or host call. Cache the array with styles/components
in the factory. Each render allocates fresh props and applies defaults, then
caller attributes, then reserved fields. Caller style/class/id override defaults;
root diagnostic attributes and math key/mode (plus component source) are reserved. Values are
borrowed, not deep-copied or mutated. No fixed document DOM ID is imposed.
Attribute application is O(p) in explicitly supplied fields, with one native
write per field; it never enumerates an opaque native object. The ordinary
extension dispatch adds O(1) work per visited extension, excluding its renderer,
child rendering and any opt-in content identity policy. These are structural
cost claims, not measured latency results.

## Qualification

- Lean tests cover forced hash collisions, retirement/reordering, structural
  equality, extension identities, change detection and nested document forms.
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
| Extension replacement, fallback, hidden children | Inherited callbacks plus counted generic-genre dispatch and lazy-child checks |
| Identity collisions, duplicate contents, retirement | Pure typed-state tests and inherited key assertions |
| State through document edits | `test:identity`: live insertion, reorder, body edit, removal/reinsertion, duplicate semantic IDs; ordinary DOM retention and disposal |
| Focus/change diagnostics | Inherited path/key and fragment-focus checks; editor selection/follow-cursor acceptance remains with VBP |
| Math typesetting | Stable component-injection API retained; KaTeX leaf not yet ported/qualified. The old effect-only leaf had no offline typeset output |
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
CSS, wrappers and fallback wording may differ. Math remains untypeset in this
fixture. This is not a full Manual traversal/HTML-generation fidelity claim.
See [Fixture.lean](tests/VersoCastTests/Fixture.lean) for the shared document and
Verso HTML instance, and [Offline.lean](tests/VersoCastTests/Offline.lean) for the
corresponding Cast callbacks.

The React renderer executes through VIR, including for Node SSR; it is not a
native Lean HTML generator. Native C
compilation of the renderer currently reaches VIR host marker externs such as
`__vir_js:react.node.createElement`, which are invalid C identifiers in this
producer. The standalone Lean import succeeds; native precompilation of that
whole import is not qualified. No consumer-side stubs or marker rewrite is added.

## Small widget boundary

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

See [ORIGIN.md](ORIGIN.md) for extraction provenance and deliberately excluded
experiments. VBP retains Blueprint adaptation and widget/application policy.
