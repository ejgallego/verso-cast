# Rendering API

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

## Genre extensions

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

Block callbacks receive `Renderer.BlockChildren`: `children.render ()` renders
ordinary wrapped blocks. `children.splitParagraph? ()` exposes a leading
paragraph's fresh attributes/inlines and a separate lazy body, useful for rich
summaries and captions. `children.listItems? ()` exposes cells of a single
unordered list as lazy fresh attributes/block contents. Shape inspection renders
nothing; choose one view and consume each selected child at most once. Source
addresses and sibling keys retain their original positions, even when wrappers
are omitted. With positional identities, these views prepare children in linear
time; opt-in fingerprinting retains its own documented cost.
The genre-independent `Renderer.Table` helper groups those cells, styles headers
and emits explicit `thead`/`tbody`; malformed dimensions consume no cells.
These helpers are not hook scopes: do not call React hooks inside them.
Inline extensions must return phrasing content. Cast footnotes use inline
`span`/`sup` markup rather than invalid `details` inside paragraphs.
Stateful extensions should return a normal component node with a stable component
function. Roles/directives already elaborate into Verso nodes; Cast does not
register or elaborate them again. Resolved references, numbering and other
traversal-dependent data remain client/genre responsibilities.
Math defaults to source-preserving output; a caller can supply a stable
`mathComponent?` leaf. The optional [KaTeX leaf](../js/katex.mjs) is shared by live
React and offline SSR; the core Lean renderer does not depend on KaTeX.

The [standalone showcase](../examples/VersoCastShowcase.lean) is a complete,
checked client: it defines a genre, creates styles once, supplies all three hooks
and renders a document with ordinary React checkbox state. Its `renderInline?`
returns a badge, `renderBlock?` returns a callout using the supplied attributes,
and `renderPart?` adds heading anchors by delegating to `renderDefault`.
There is no registration step for these callbacks.

| Hook outcome | Children/default callback | Result |
| --- | --- | --- |
| Decline | Do not call | `none`, allowing Cast's fallback |
| Replace or decorate | Call once if needed | `some node` |
| Hide | Do not call | `some` keyed empty fragment |

Keep a stateful extension's component function stable by creating it in the
factory, not during document traversal. Return a node for that component;
React then owns its hooks and retained state. Live and offline rendering use
the same callbacks. Content created only by effects is absent from offline HTML.

## Identities and retained state

Basic rendering requires no JSON, equality or hash instances and uses positional
keys. `Renderers.blockIdentity?` can supply semantic extension keys, while
`Renderers.fingerprint` optionally supplies content identities. For Manual,
import `VersoCast.Manual` and extend `Manual.renderers`; its default names
unsupported extensions but does not fingerprint document content.
Author-supplied identities take priority; other blocks use positional keys.
Stateless serialized-content matching is explicitly opt-in:

```lean
{ fingerprint? := some (fun value => some (VersoCast.Fingerprint.canonicalKey value)) }
```

This policy serializes content and remounts a container when that content changes.
It is not the default for interactive previews. Positional fallback preserves
state through body edits at the same position, but not arbitrary insertion or
reordering; provide stable semantic keys for stateful authored extensions.
For readable built-in Lean blocks and compiler output, call
`Manual.createRenderers styles` once in the component factory and pass the
result to `Renderer.render`. It preserves source text, message severity,
summary flags and trace-expansion settings. Native token styles also cover
inline Lean/names, tactic snippets and Markdown Lean; docstring sections and
constructor/internal/field signatures render their stored children. Tables keep
headers and alignment; file examples label their stored input/output contents.
Paragraph groups retain block structure. Syntax errors show their
source and diagnostics. Styles are cached in the factory and use VS Code CSS
variables with browser fallbacks; token colours approximate semantic categories,
not the editor's full TextMate theme. Interactive hover information is pending.
Glossary terms render without inventing unresolved cross-reference links.
Malformed data and unknown
extensions keep the named fallback. Reference-manual-specific extensions
(`Manual.example`, `Manual.proofState`) are implemented by the validation
consumer, not registered globally in Cast.
The core `VersoCast` import does not import Manual.

Semantic block labels are opaque strings; separators and Unicode are allowed.
Internal comparison paths encode their components unambiguously. These paths
are not the React keys or positional navigation addresses.

For retained documents, keep `Fingerprint.State genre` in component state and
advance it with `Renderer.prepareIdentities` when document content changes.
This opt-in path requires equality/hash instances for the genre's extensions.
Pass `{ fingerprint? := some (fun value => some (identities.key value)) }` as
render options, using the state prepared for that document and the same
`blockIdentity?` policy as rendering. Reprepare if either changes. Preparation
is pure and resolves hash collisions with exact equality. React keys are
sibling-local; navigation paths are separate.
Cursor/control changes need not recompute content identities.

List and description-list item keys are positional. Inserting or reordering
items may reuse state at a position or remount subtrees; an identified block
inside an item does not override its ancestor's React identity. A content
fingerprint that changes a container's key also remounts its subtree. For stable
state through item reordering, use a client-owned keyed list component in a
block extension.

Ordered lists preserve their signed `start` value, including negative values
and zero.

## Focus and change highlighting

`Options.focus` is a source-navigation address, not a React key or DOM ID.
It adds a visual marker without moving keyboard focus or scrolling. Ordinary
block/heading and list-item addresses select their matching nodes. A fragment
has no DOM wrapper, so it marks its visible child roots (through nested
fragments). A description-item address selects both term and value; the exposed
`-term` and `-description` addresses select those separately. Hidden, empty or
missing addresses do not fall back to another node. Focus and change markers
are independent. Editor selection, cursor tracking and scroll policy remain
with the client.

Pass a current-document state's key function only in `Options.fingerprint?`.
The `changedBlockIds*` helpers compare both documents using the stateless
`Renderers.fingerprint` policy; a state prepared only for the new document may
not contain the old values. These helpers track raw heading/block contents,
not part metadata, presentation changes or extension visibility. Preparation
visits all stored blocks, including hidden content; it does not call render
callbacks. Neither identity helper is a promise of linear whole-document cost.

Change comparison is deliberately coarse for lists and blockquotes: editing a
term, list start or nested paragraph marks the whole container. Concatenations
have no comparison entry; extensions contribute both their own entry and stored
children, even when a rendering callback hides them. Removed nodes have no
current path to return. A fingerprint policy that changes an ancestor's identity
also changes its descendants' identity context.
`changedBlockIdsAndCount` returns the current **comparison-snapshot count**,
not visible DOM nodes or changed-node count. The root's
`data-verso-changed-block-count` is the number of supplied changed paths, also
not a visibility-aware count. `renderBlockIds` computes initial comparison paths
without equality/hash/JSON instances. Finer-grained client highlighting can
supply nested paths directly through `Options.changedIds`; the default helper
does not introduce another analyzed document or visibility pass.

## Native attributes and ownership

`Renderer.Options.debug` defaults to `false`. Source/navigation addresses,
node kinds, focus/change markers and visible unsupported-extension output are
always available. Inspection-only identity labels, generated path tooltips and
root diagnostic summaries are emitted only with `{ debug := true }`; disabling
them does not change React keys or run an extra document traversal. Client-owned
tooltips and explicitly supplied attributes remain under client control.

Extra root/math attributes are immutable `Array Renderer.Attribute` values.
`Attribute.of nativeKey nativeValue` only widens the native value's phantom type;
it performs no conversion or host call. Cache the array with styles/components
in the factory. Each render allocates fresh props and applies defaults, then
caller attributes, then reserved fields. Caller style/class/id override defaults;
root diagnostic attributes (when debug is enabled) and math key/mode (plus
component source) are reserved. Values are borrowed, not deep-copied or mutated.
No fixed document DOM ID is imposed.
Attribute application is O(p) in explicitly supplied fields, with one native
write per field; it never enumerates an opaque native object. The ordinary
extension dispatch adds O(1) work per visited extension, excluding its renderer,
child rendering and any opt-in content identity policy. These are structural
cost claims, not measured latency results.

## Client-owned semantics

Clients supply prepared documents and interpret their own extension data,
including labels, resolved references, numbering and external markup. Use the
block hook's attributes and lazy children for custom statements, callouts or
source/summary views; hiding an extension should skip its children entirely.
Define malformed-data and unsupported-extension output in the client adapter.
Cast's fallback is a visible placeholder, not a genre-specific error policy.

## Optional math leaf

```js
import katex from "katex";
import "katex/dist/katex.css";
import { createMathComponent } from "verso-cast/katex";

const MathFormula = createMathComponent(katex); // once, outside render
```

Pass this native React function as `Renderer.Renderers.mathComponent?` on the
Lean side. It receives `source` and `data-verso-math-mode` from Cast and preserves
the caller's other attributes. Both browser rendering and React SSR use
`renderToString`, including accessible MathML; no effect is needed to populate
the formula. The memoized computation depends only on source and display mode.
React may recompute it, so correctness does not rely on memoization. Input is
untrusted (`trust: false`), parse failures remain visible, and each computation
gets a fresh macro table. Only KaTeX-produced HTML enters the inner-HTML boundary.
Clients own source preparation (including genre-specific preludes), KaTeX
version and CSS/font delivery. No Blueprint-specific attribute is interpreted.

The tests pin KaTeX in npm dev dependencies and bundle CSS/fonts for a small
live/offline comparison. This does not add an npm requirement to `lake build`:

```sh
npm run test:math -- --serve
```

Open the printed URL to edit a formula and toggle display mode. The offline pane
is the initial formula rendered through the same Lean document path and native
component; it is intentionally static. Ctrl-C stops the server.

## Execution backends

The React renderer executes through VIR, including for Node SSR. Native Lean C
precompilation of the renderer is unsupported at the pinned VIR revision:
its JavaScript host externs cannot be compiled as native C functions.
The pure `VersoCast.Fingerprint` helpers support native execution.
