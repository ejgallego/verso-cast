# Development

## Setup and tests

Run from the repository root with Node 24. Build the Lean targets before
`npm ci`: the local VIR npm dependency lives in Lake's pinned checkout.
Build widget examples after `npm ci`, because VIR's widget bundle uses npm tooling.

```sh
lake build VersoCast VersoCastTests cast-assets cast-standard-html
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
| `test:manual` | Styled source/output, inline Lean, docstring sections, diagnostics, escaping and fallback |

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
Introduction and The Empty Type. Other pages may build imports when first
opened; to prepare all of them, run `lake build Manual` inside the copy.
Do not build that copy and Cast concurrently: their dependencies are shared.
Existing legacy pages may emit a missing-`module` warning; they are not migrated.

This is a raw-document validation mode, not the generated reference website:
it does not run Manual traversal, resolve references or typeset math. Built-in
Lean code/output render as text panels; the consumer adds proof-state panels
and collapsible examples. Example summaries use their plain-text description;
rich summary markup and hover information are not implemented. The adapter
colours stored Lean tokens with cached native styles, formats inline Lean and
glossary terms, and displays docstring containers and syntax-error diagnostics.
Unsupported extensions have visible named
placeholders. The test-only transport uses `ToJson`/`FromJson` and Lean's JSON
parser, not an optimized codec; its latency is not a renderer benchmark.

The browser replay validates the public Lake facet and runs the retained package
that the widget RPC would emit, using real elaborated Introduction/Empty pages.
The widget declares meta/private imports for the Manual implementations it snapshots,
so those body changes rebuild that package despite ordinary opaque imports.
The replay tests
decoding, rendering, page changes, edit refresh, stale replies, malformed input
recovery and disposal. Its RPC transport is controlled, not a real VS Code/LSP
connection. Screenshots are written under `_out/reference-manual/`.

## Runtime assets

`cast-assets` reads `Vir.Resources.Runtime.bundle`, checks the Lean compiler
identity and writes `.vir/runtime.wasm` plus its identity metadata. SSR tests
also verify the Wasm SHA-256. Runtime assets and host bindings come from the
pinned VIR dependency; use the same toolchain and revisions for the Lean build
and runtime.

Build outputs, runtime assets, browser bundles and dependencies are ignored by
Git. Only source, tests and dependency lock files belong in commits.
