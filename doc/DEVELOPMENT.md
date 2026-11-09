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
(cd tests/downstream && lake build Consumer Consumer.GenreAdapters && lake exe consumer)
```

For fresh Git consumers of committed `HEAD`, rather than working-tree edits:

```sh
npm run test:git-consumer
```

This gate needs only Node, Git and Lean, so it can run before `npm ci`. It checks
core, Manual/Page/Post factories and Slides-subdirectory consumption, dependency
pins and public APIs in temporary checkouts. The directories are removed on success or failure.
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

Use the shown working directories: Slides image directives resolve local paths
relative to the compiler process's working directory, not Lake's `-d` argument.

The root, local consumers and reference-manual copy share dependency build
directories: do not build them concurrently. [CI](../.github/workflows/ci.yml)
runs the suites sequentially on Ubuntu with build caches disabled.

### Choosing a test

Each named test below runs with `npm run <name>`.

| Command | Coverage |
| --- | --- |
| `lake test` | Identities, hash collisions, retirement and change comparison |
| Consumer build/executable | Public core and Manual/Page/Post factory APIs (compile-only); native identity helpers |
| `test:git-consumer`, `test:js-package` | Lean Git packages and packaged JS helper |
| `test:renderer`, `test:offline` | Rendered nodes, extension contracts and live/SSR fidelity |
| `test:comparison-demo` | Core/Blog/Slides comparison servers with no Playwright browser installation |
| `test:identity`, `test:navigation` | Retained state, focus addresses and change markers |
| `test:widget`, `test:showcase` | Component state, callbacks, retained DOM and disposal |
| `test:math`, `test:manual`, `test:blog`, `test:slides` | Math and genre adapters |
| `test:reference-setup` | Reference-manual setup patching |
| `test:preview-server` | Actual Lean LSP/RPC checked-page references, version/processing rejection and error recovery |
| `test:reference-manual` | Six real Manual pages, generated-codec rendering parity, consumer extensions and widget lifecycle |
| `test:json-safe` | Generated native writer, matched public SDK, typed Manual observations on both Wasm profiles |

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

## Generated document codec acceptance

The generated codec test uses the SDK from the pinned VIR `v4.36.0-rc1` release.
VIR's normal Lake acquisition downloads and verifies the matching SDK:

```sh
npm run test:json-safe
```

The test verifies all SDK payload hashes and runs a compiled native writer →
JSON-RPC String envelope → JavaScript parse → public `callWith` on both Wasm
profiles. Independent Lean observations cover every Manual metadata field,
exact numbers, recursive parts and checked NameMap construction. Rejection,
recovery and disposal are checked as well. This does not exercise an editor
connection, rendering, retained React state or performance.

Native JSX uses the explicit `jsx%{…}` delimiter. The ordinary preview currently
keeps its existing string decoder; generated-codec widget adoption is separate
from the typed document gate above.

The opt-in `VersoCast.Manual.Codec` module supplies
`VersoCast.Manual.Codec.encodeDocument : Part Manual → String` and registers the
checked `NameMap String` construction rule. It uses public insertion/iteration
operations, preserves Name components, rejects invalid keys and keeps the last
value for duplicate keys. Import it in the writer and typed-entry modules;
select `argumentRepresentation: "json-safe-v1"` in the receiving public
`callWith`. Its format is tied to the matched VIR compiler/runtime, not Verso's
`ToJson` schema or a stable document interchange format. It is not imported by
the core renderer or the ordinary Manual adapter.

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

Refreshes retain the last successful preview. Loading and error feedback stays
on one line beside Debug, without moving the document; hover truncated feedback
to read the full message.

For the automated replay:

```sh
npm run test:reference-manual
npm run test:preview-server
```

This prepares the copy, builds the widget and six pages, and checks live/SSR
agreement, controls, retained disclosures, refresh, stale replies, malformed
input recovery and disposal. It uses the retained package emitted by the widget
RPC, with a controlled transport rather than a real editor/LSP connection.
React `act` drains test updates; stale-reply checks require a held request to be
aborted on a page switch and delivered before checking the current page.
Edits in this replay change serialized input, not the saved Manual source.

The public preview component is additionally exercised with supplied processing
tokens and replacement sessions. Its callbacks must invalidate old execution
authority before accepting a new one, and preserve the exact native RPC reference.
The separate server test launches a genuine Lean LSP process with unsaved edits:
it checks reference round-trips, version guards, error-page admission and recovery,
and rejection from a substituted same-version processing context. That last
control is not an actual imported-module rebuild. Actual VS Code reprocessing,
session replacement, cursor-only request suppression and runnable-control
shutdown remain consumer acceptance gates; do not infer them from this replay.

The same pages also pass through the generated native writer, a controlled
JSON-RPC String envelope, JavaScript parsing and public typed `callWith`.
Their React SSR output must equal that from the existing decoder; Chromium
checks live output and retained disclosure DOM after typed reconstruction.
This direct-call gate is separate from the all-Lean widget, which still uses
its existing decoder pending a public VIR client-side codec connection.

The consumer adapter renders examples, proof states, grammar, attributes,
syntax-kind labels and TODO notes. It is a raw-document preview: references,
citations and generated license/index data can remain visible fallbacks.
Math is source-only and hover information is not interactive. Browser tests
stage the sample images; VS Code asset-URL mapping is not implemented.
Debug enables inspection metadata, not timings. Neither decoding path is a
renderer performance baseline.

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
- `Manual/Preview.lean` and `Manual/Preview/Server.lean` are the opt-in checked-page
  component and server API. The core renderer and ordinary Manual adapter do not
  import them. `Manual/Codec.lean` is independent of preview acquisition.
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
