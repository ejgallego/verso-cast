# Development

## Setup and tests

Run from the repository root with Node 24. Build the Lean targets before
`npm ci`: the local VIR npm dependency lives in Lake's pinned checkout.
Build widget examples after `npm ci`, because VIR's widget bundle uses npm tooling.

```sh
lake build VersoCast VersoCastTests cast-assets cast-standard-html cast-blog-html
lake test
npm ci
npx playwright install chromium
lake build VersoCastExamples
npm test
```

Check the separate consumer after the root build:

```sh
(cd tests/downstream && lake build && lake exe consumer)
```

Run these sequentially: the local-path consumer and root project share Cast's
build directory. CI uses this sequence on Ubuntu 24.04, installs Chromium's
system dependencies and disables restored build caches and Lake's artifact cache.

## Test coverage

Each npm test below can be run with `npm run <name>`.

| Command | Coverage |
| --- | --- |
| `lake test` | Typed identities, hash collisions, retirement and change-comparison policy |
| Consumer `lake build` | Public root import, generic extension hooks, headings and attributes |
| Consumer `lake exe consumer` | Native execution of pure identity helpers |
| `test:renderer` | React nodes, escaping, fallback extensions, keys and change markers |
| `test:offline` | Verso/SSR/live comparison, lazy extension dispatch and metadata hooks |
| `test:identity` | State and DOM retention across insertion, reordering, edits and removal |
| `test:navigation` | Focus addresses, fragments, description lists and independent change markers |
| `test:widget`, `test:showcase` | Live component state, callbacks, retained DOM and disposal |
| `test:math` | KaTeX SSR/live output, updates, malformed input and macro isolation |
| `test:manual` | Styled source/output, inline Lean, docstring sections, escaping, fallback and default-off debug metadata |
| `test:blog` | Real Post source, typed Blog extensions, metadata, live/SSR/Verso essentials and disposal |
| `test:slides` | Optional pinned Slides consumer, notes/fragments, nested root decoration, tables and retained navigation state |

Browser tests use real React and Chromium through Playwright. They test widget
components, not the VS Code infoview itself. They are correctness tests, not
performance benchmarks.

## VS Code showcase

After setup, prepare the runtime and open the example:

```sh
lake exe cast-assets
code examples/VersoCastShowcase.lean
```

Place the cursor inside `showcase_ready`. The widget demonstrates a custom genre,
a badge role, a callout directive, section anchors and a checkbox. The smaller
`examples/VersoCastDemo.lean` uses Manual; place the cursor inside
`castDemo_and_comm`. These examples display math source; the typeset math demo
is separate below.

If the infoview needs refreshed assets, restart the Lean server or reopen the
file after preparing the runtime.

## Browser demos

```sh
npm run demo
npm run compare:serve
npm run compare:blog:serve
npm run compare:slides:serve
npm run test:math -- --serve
```

Run one command at a time and open its printed local URL. Stop with Ctrl-C.
Generated files are written under `_out/`.

The comparison shows the same [typed document](../tests/VersoCastTests/Fixture.lean)
through live Cast/React, React SSR and Verso's standard renderer. The latter
converts `Output.Html` to a string with `asString`. Cast's live and SSR structures
must agree; cross-backend layout differences are illustrative rather than a
universal equivalence requirement. This fixture leaves math as source.
`npm run compare` generates the HTML and observations without serving them.

The math demo uses the shared KaTeX leaf for both live and offline output,
with editable formula source and display mode.

The Blog comparison uses a checked Post with metadata, a JSON lexer, Lean source
and output. The Slides comparison builds the isolated [test consumer](../tests/slides/lakefile.lean)
against `leanprover/verso-slides` at `268257a4fbdac12c77be726213b51c3ce3a1d41e`,
with the same Lean toolchain and Verso revision as Cast. Slides is not a Cast
library dependency; its adapter remains in test support until its scope is mature.
Run `npm run test:slides` separately; CI runs it after the root suite. Both
comparisons use actual genre documents, live React, React SSR and the existing
genre renderer's `Output.Html.asString`. Native reference executables import
only pure fixtures, not VIR's JavaScript-host-dependent renderer.

Slides preview covers three horizontal sections, a vertical group, notes,
inline/block fragments, nested class directives and a basic column-header table.
Notes/fragments remain visible; ordinary React shell buttons select/highlight a
source heading while retaining the whole deck. Vertical/background metadata is
annotated, not converted into Reveal.js grouping/navigation. This is not a
presenter: arbitrary HTML, slide-specific code/diagrams/animations and row-header
or striped tables remain named fallbacks. Basic tables use Cast's preview styles,
not every Reveal.js style flag. Math remains source. Blog's stored hidden
hover messages are excluded from the visible-code comparison; Cast does not
implement those hovers. Cross-backend checks are bounded content observations,
not a promise of identical themes, wrappers or generated sites.

## Lean reference manual validation

After the normal setup above, prepare an isolated, shallow copy of
`leanprover/reference-manual` at `349244b4dd2f284728c1dacb621cc74a32f9929b`:

```sh
node tools/setup-reference-manual.mjs --build
code --new-window .local/reference-manual --goto .local/reference-manual/Manual/Intro.lean:35
node tests/reference-manual/browser.test.mjs
```

The script checks the exact toolchain and shared dependency revisions, reuses
Cast's built dependencies, and adds the test widget before `#doc` in 205 pages.
It does not touch another manual checkout. Repeat runs preserve page edits and
refuse to overwrite changed configuration or test helpers. The checked-in
[Lake patch](../tests/reference-manual/lakefile.patch) and widget live only in
test support, not the Cast library.

Place the cursor in a page under `Manual/`. The widget shows that module's
whole checked document; opening another page changes the preview, and edits
refresh it through the standard infoview notification/RPC APIs. Setup builds
Introduction, The Empty Type, Tuples, Integers, Monadic Syntax and Structure
Declarations. Other pages may build imports when first
opened; to prepare all of them, run `lake build Manual` inside the copy.
Do not build that copy and Cast concurrently: their dependencies are shared.
Existing legacy pages may emit a missing-`module` warning; they are not migrated.

This is a raw-document validation mode, not the generated reference website:
it does not run Manual traversal, resolve references or typeset math. Built-in
Lean code/output render as text panels; the consumer adds proof-state panels
and collapsible examples. Example and syntax summaries preserve stored rich
inlines; grammar displays its stored text without interactive grammar links.
Figures preserve rich captions. The browser harness stages the two pinned
screenshots; VS Code asset-URL mapping is not implemented yet.
Interactive hover information is not implemented. The adapter
colours stored Lean tokens with cached native styles, formats inline Lean and
glossary terms, and displays docstring containers, field signatures, labeled
file examples, tables and syntax-error diagnostics.
Unsupported extensions have visible named
placeholders. The test-only transport uses `ToJson`/`FromJson` and Lean's JSON
parser, not an optimized codec; its latency is not a renderer benchmark.

The browser replay validates the public Lake facet and runs the retained package
that the widget RPC would emit, using the six real elaborated sample pages.
The widget declares meta/private imports for the Manual implementations it snapshots,
so those body changes rebuild that package despite ordinary opaque imports.
The replay tests
decoding, rendering, page changes, edit refresh, stale replies, malformed input
recovery and disposal, including edits inside an open example. Its RPC transport
is controlled, not a real VS Code/LSP connection. Screenshots are written under
`_out/reference-manual/`.

Each selected page is compared with React SSR from the same decoder/adapter;
parsed element/text structures must agree. The browser replay writes a source
extension inventory and remaining visible fallbacks to `coverage.json` in that
output directory. Its browser page has a sample selector and an expandable SSR
pane. The ordinary three-way comparison additionally covers nested rich
summaries and tables against `Output.Html.asString`; Verso layout differences
remain illustrative, not a universal equality constraint.

Remaining fallbacks in this sample include references/citations, generated
license/index data and consumer roles such as TODO and attributes. They remain
visible; this validation does not claim whole-manual extension coverage.

The widget's sticky header contains an off-by-default Debug checkbox and its
inspection explanation, outside the rendered article. It enables renderer
metadata only: no clock reads, timing bar, extra RPC request or diagnostic tree
walk. Named examples use their authored tags; anonymous examples use positional
keys. The browser edit test changes the serialized document body, not the saved
manual source or its Lean elaboration.

## Runtime assets

`cast-assets` reads `Vir.Resources.Runtime.bundle`, checks the Lean compiler
identity and writes `.vir/runtime.wasm` plus its identity metadata. SSR tests
also verify the Wasm SHA-256. Runtime assets and host bindings come from the
pinned VIR dependency; use the same toolchain and revisions for the Lean build
and runtime.

Build outputs, runtime assets, browser bundles and dependencies are ignored by
Git. Only source, tests and dependency lock files belong in commits.
