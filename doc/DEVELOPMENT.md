# Development

For library usage and supported rendering behavior, see the
[rendering guide](RENDERING.md).

## Setup and tests

Run from the repository root with Node 24 and the checked-in Lean toolchain.
Build the Lean targets before `npm ci`, since the local VIR npm dependency
lives in Lake's pinned checkout. Build widget examples after installing npm
dependencies.

```sh
lake build VersoCast VersoCastTests cast-assets cast-standard-html cast-blog-html
lake test
npm ci
npx playwright install chromium
lake build VersoCastExamples
npm test
npm run test:js-package
npm run test:reference-setup
```

On Linux, `npx playwright install --with-deps chromium` also installs the system
libraries needed by the browser tests.

Run the local-path consumer after the root build:

```sh
(cd tests/downstream && lake build && lake exe consumer)
```

For fresh Git consumers of committed `HEAD`, rather than working-tree edits:

```sh
npm run test:git-consumer
```

This gate needs only Node, Git and Lean, so it can run before `npm ci`. It checks
core and Slides-subdirectory consumption, dependency pins and public APIs in
temporary checkouts. The directories are removed on success or failure.
The JS package test separately extracts an npm tarball and imports its KaTeX
helper from an external consumer, reusing installed test dependencies.
Neither test publishes a package.

Build the optional Slides package and its consumer sequentially:

```sh
(cd packages/slides && lake build)
(cd tests/slides && lake build CastSlides CastSlides.PublicApi)
npm run test:slides
npm run test:comparison-demo
```

The root, local consumers and reference-manual copy share dependency build
directories: do not build them concurrently. [CI](../.github/workflows/ci.yml)
runs the suites sequentially on Ubuntu with build caches disabled.

### Choosing a test

Each named test below runs with `npm run <name>`.

| Command | Coverage |
| --- | --- |
| `lake test` | Identities, hash collisions, retirement and change comparison |
| Consumer build/executable | Public API boundary and native identity helpers |
| `test:git-consumer`, `test:js-package` | Lean Git packages and packaged JS helper |
| `test:renderer`, `test:offline` | Rendered nodes, extension contracts and live/SSR fidelity |
| `test:comparison-demo` | Core/Blog/Slides comparison servers with no Playwright browser installation |
| `test:identity`, `test:navigation` | Retained state, focus addresses and change markers |
| `test:widget`, `test:showcase` | Component state, callbacks, retained DOM and disposal |
| `test:math`, `test:manual`, `test:blog`, `test:slides` | Math and genre adapters |
| `test:reference-setup` | Reference-manual setup patching |
| `test:reference-manual` | Six real Manual pages, consumer extensions and widget lifecycle |

Browser tests use real React and Chromium. They check components, not VS Code
itself, and are correctness tests rather than performance benchmarks.

## Demos

After setup, these commands print a local URL. Stop the server with Ctrl-C:

```sh
npm run demo
npm run compare:serve
npm run compare:blog:serve
npm run compare:slides:serve
npm run test:math -- --serve
```

The plain demo and comparison servers need no Playwright browser installation.
The math command still runs its browser checks before serving, so it needs
Chromium. Prepare the Slides consumer above before viewing its comparison.

The comparisons show one document through live Cast, React SSR and Verso's
standard HTML renderer. Live/SSR structures must agree; comparisons with Verso
check fixture content, not identical themes or whole generated sites.
`npm run compare` generates the core comparison without serving or validating it.
Run `npm run test:offline`, `test:blog` or `test:slides` for browser validation;
those tests use the same generated views as the servers.
The math demo has editable source and display mode; its SSR pane shows the
initial formula. Outputs and screenshots are under `_out/`.

For VS Code, prepare the runtime and open the showcase:

```sh
lake exe cast-assets
code examples/VersoCastShowcase.lean
```

Place the cursor inside `showcase_ready`. The smaller
[Manual demo](../examples/VersoCastDemo.lean) uses `castDemo_and_comm` as its
cursor anchor. These widgets display math source; the browser math demo typesets
it. Restart the Lean server or reopen the file after refreshing runtime assets.

## Lean reference manual validation

The setup helper creates a pinned copy under `.local/reference-manual`, adds
the test widget to document pages and shares Cast's checked dependency revisions.
Its source pin is defined in [the helper](../tools/setup-reference-manual.mjs).
It preserves page edits and refuses to overwrite edited configuration or helper
files. First setup needs network access.

For an editor preview:

```sh
node tools/setup-reference-manual.mjs --build
code --new-window .local/reference-manual --goto .local/reference-manual/Manual/Intro.lean:35
```

Select a position in a page under `Manual/`. The widget displays that module's
checked document and refreshes on edits. Setup builds six sample pages; other
pages may build imports when opened. To prepare every page, run `lake build Manual`
inside the copy. Legacy pages may emit missing-`module` warnings.

For the automated replay:

```sh
npm run test:reference-manual
```

This prepares the copy, builds the widget and six pages, and checks live/SSR
agreement, controls, retained disclosures, refresh, stale replies, malformed
input recovery and disposal. It uses the retained package emitted by the widget
RPC, with a controlled transport rather than a real editor/LSP connection.
React `act` drains test updates; stale-reply checks require a held request to be
aborted on a page switch and delivered before checking the current page.
Edits in this replay change serialized input, not the saved Manual source.

The consumer adapter renders examples, proof states, grammar, attributes,
syntax-kind labels and TODO notes. It is a raw-document preview: references,
citations and generated license/index data can remain visible fallbacks.
Math is source-only and hover information is not interactive. Browser tests
stage the sample images; VS Code asset-URL mapping is not implemented.
Debug enables inspection metadata, not timings. The test codec uses Lean's JSON
parser and is not a renderer performance baseline.

Fixtures and the Lake patch live in [tests/reference-manual](../tests/reference-manual).
Changes to captured renderer bodies must invalidate the widget package; its
`meta import all` declarations establish those dependencies. Screenshots and
the extension/fallback inventory are written to `_out/reference-manual/`.

## Source layout

The public entry point is `VersoCast.lean`. The main implementation is arranged by
responsibility:

- `VersoCast/Renderer.lean` traverses documents; `Renderer/` contains its
  extension contracts, styles, change comparison, internal identity allocation
  and table helper.
- `Fingerprint.lean` supplies opt-in retained identities; `RenderPath.lean`
  defines navigation addresses; `JsStrings.lean` caches native property strings.
- `Manual.lean`, `Blog.lean` and `Highlighting.lean` implement genre adapters and
  shared token rendering. The optional Slides adapter lives in `packages/slides/`.
- `js/katex.mjs` is the optional math component. `examples/` contains small
  clients, `tests/` contains fixtures and acceptance checks, and `tools/` stages
  and serves demos. `tools/comparison.mjs` prepares the shared comparison views;
  tests add assertions and browser interaction separately.

Keep genre-specific editor behavior in consumers. New renderer behavior should
have Lean or runtime tests as appropriate; stateful changes need retained React
DOM checks. Internal sibling identity types are deliberately not root-exported,
and the public consumer tests that boundary.

## Runtime assets

`lake exe cast-assets` obtains the runtime bundled by pinned VIR, checks its Lean
compiler identity and writes `.vir/runtime.wasm` and metadata. SSR tests verify
the Wasm checksum. Use matching source and runtime revisions; do not substitute
an artifact from another toolchain.

Dependencies, runtime assets and generated output are ignored by Git. Exact
dependency revisions belong in Lake/npm lockfiles, and validation reports belong
under `_out/`, not in checked-in status documents.
