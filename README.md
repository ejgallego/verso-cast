# Verso Cast

Experimental native React rendering of `Verso.Doc.Part Verso.Genre.Manual`
through VIR. No Blueprint dependency, alternative document model or runtime
implementation. This is a local extraction checkpoint, not a published package.

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
    (document : Verso.Doc.Part Verso.Genre.Manual) :
    Lean.Vir.React.ReactM (Lean.Vir.Js Lean.Vir.React.Node) :=
  VersoCast.Renderer.render styles document
```

Create `Renderer.Styles.create` once in the component factory and capture the
result in its render callback. Styles are read-only native JavaScript objects;
the renderer constructs fresh node attributes. It returns a React subtree, not
a root, state store, widget, editor protocol or asset publisher.

`Renderer.Extensions` supplies optional inline/block render helpers and block
identities. Unknown extensions remain visible with their original children.
These helpers are not hook scopes: do not call React hooks inside them.
Math defaults to source-preserving output; a caller can supply a stable
`mathComponent?` leaf. No KaTeX bundle is included at this checkpoint.

For retained documents, keep `Fingerprint.State` in component state, advance it
with `Renderer.prepareIdentities` when document content changes, and pass it as
`Renderer.Options.identities?`. Preparation is pure and resolves hash collisions
with exact equality. React keys are sibling-local; navigation paths are separate.
Cursor/control changes need not recompute content identities.

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

The full renderer is browser/VIR code, not a native HTML generator. Native C
compilation of the renderer currently reaches VIR host marker externs such as
`__vir_js:react.node.createElement`, which are invalid C identifiers in this
producer. The standalone Lean import succeeds; native precompilation of that
whole import is not qualified. No consumer-side stubs or marker rewrite is added.

## Small widget boundary

`examples/VersoCastDemo.lean` uses VIR's native-props `vir_proof_widget` mechanism:
one Manual document, one retained checkbox, and no custom server/RPC/shell. The
factory constructs styles once. Its registration and generated IR build pass;
live VS Code display remains a manual acceptance step.

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
