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
  VIR's public SDK and host bindings, not a shadow VDOM or copied adapter:

```sh
lake build +VersoCastTests:vir @lean_vir:virSdk
npm ci
npm run test:renderer
```

The selected VIR revision's default SDK URL currently returns HTTP 404.
Therefore the React execution gate is **pending SDK availability**, not passed.
An independently verified matching archive may be supplied through VIR's
`VIR_SDK_ARCHIVE` option; do not substitute old JavaScript/Wasm or infer compatibility
from a version label. The Lean build does not need that SDK or npm.

The full renderer is browser/VIR code, not a native HTML generator. Native C
compilation of the renderer currently reaches VIR host marker externs such as
`__vir_js:react.node.createElement`, which are invalid C identifiers in this
producer. The standalone Lean import succeeds; native precompilation of that
whole import is not qualified. No consumer-side stubs or marker rewrite is added.

## Small widget boundary

Pinned VIR offers `Vir.Infoview.Widget` and `vir_proof_widget` for a native-props
component factory. This is the candidate for a small example, not a reason to
copy VBP's full shell. Its generated infoview bundle and exact matching Wasm
assets need separate qualification before claiming a live demo. The simpler
`createProgram` resource facade does not accept custom React host bindings.
No local widget bridge, JSON converter or provider abstraction is added here.

See [ORIGIN.md](ORIGIN.md) for extraction provenance and deliberately excluded
experiments. VBP retains Blueprint adaptation and widget/application policy.
