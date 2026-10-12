# Rendering guide

Cast takes a `Verso.Doc.Part genre` and produces a React subtree. The
[README](../README.md#use-cast-in-a-project) shows a minimal component factory;
the [showcase](../examples/VersoCastShowcase.lean) adds a widget and React state.
Your application prepares the document and supplies its surrounding interface,
assets, resolved references and numbering.

Create `Renderer.Styles.create` once in the component factory. The styles are
read-only native objects, reused by rendering callbacks; each node gets fresh
props. Native styles, attributes and component handles belong to the VIR
runtime that created them. For live rendering, unmount the React tree before
disposing that runtime. Do not share its handles with another runtime.

## Genre extensions

Pass a `Renderer.Renderers genre` record to `Renderer.render` to handle your
genre's inline roles, block directives and section metadata. Here is a simple
component that displays every inline extension as highlighted text:

```lean
import VersoCast
open VersoCast Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

def createMarkedView {genre : Verso.Doc.Genre} (document : Verso.Doc.Part genre) :
    RuntimeM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let handlers : Renderer.Renderers genre := {
    renderInline? := fun key _ children => do
      return some (← <mark key={← JsValue.ofString key}>
        {Js.Array.ofArray (← children ())}</mark>) }
  FunctionComponent.ofLean fun _ =>
    Renderer.render styles document (renderers := handlers)
```

In an adapter, match the genre's extension values and return `none` for cases
you do not handle. Cast then displays an extension placeholder with its stored
children. `inlineName` and `blockName` supply names for those placeholders.
Invalid extension data can use the same fallback.

Callbacks receive lazy children, so a replacement can omit content without
rendering it first. The essential contract is:

| Action | Children/default callback | Return |
| --- | --- | --- |
| Decline | Do not call | `none` |
| Replace or decorate | Call once if needed | `some node` |
| Hide | Do not call | `some` keyed empty fragment |

Use the supplied sibling-local key on inline replacements. Block callbacks get
an attribute builder that adds the key, source address and focus/change markers.
Inline output must be valid phrasing content, such as `span` or `code`.

Extension callbacks are render helpers, not React hook scopes. For a stateful
extension, create a stable ordinary component in the factory and return a node
for it. React owns that component's hooks and state. The same callbacks work
for live rendering and SSR; content created only by effects is absent from SSR.

### Sections

`renderPart?` receives a part's metadata, the part without its own metadata,
and a lazy `renderDefault` callback. Descendant metadata is preserved.
Return `none` to use the ordinary section layout, or delegate to
`renderDefault none` when decorating it. `renderDefault (some header)` replaces
the heading without copying section traversal. The header receives rendered
title nodes, fresh attributes and a level clamped to h6; return the matching
hN element. Call the default at most once and return `some` after using it.

The showcase supplies all three hooks: a badge role, a callout directive and
heading anchors derived from section metadata.

### Structured block children

`Renderer.BlockChildren` offers several views of a directive's stored content:

- `render ()` keeps the ordinary block wrappers.
- `splitParagraph? ()` exposes a leading paragraph's attributes/inlines and a
  separate lazy body, useful for summaries and captions.
- `listItems? ()` exposes cells of a single unordered list as lazy attributes
  and block contents. `Renderer.Table.render` groups them into a table with
  explicit `thead`/`tbody`; malformed dimensions consume no cells.
- `renderWith decorate` applies a decorator to fresh props while constructing
  each visible child root, rather than inspecting finished React nodes.

Shape inspection renders nothing. Choose one view and consume each selected
child at most once. Source addresses and sibling keys preserve their original
positions when wrappers are omitted. With positional identities, preparing
these child views is linear in the selected sequence.

Concatenations forward decorators; transparent adapters can forward them by
using `renderWith`. Ordinary wrappers decorate only their own root. Nested
decorators run inner-first, outer-last. Preserve source and identity fields;
Cast writes reserved key/navigation fields afterward. `Renderer.appendClass`
appends a cached native suffix, including its leading space, without a
Lean/native string round trip for each child.

## Manual documents

Import `VersoCast.Manual`, create `Manual.createRenderers styles` in the factory,
and pass the result as `renderers`. It renders built-in Lean source, compiler
output, inline Lean, tactic snippets, signatures, docstrings, tables, file
examples, paragraph groups and syntax-error diagnostics. Output preserves
message severity, summary flags and trace-expansion settings. Tables retain
headers and alignment. Glossary terms display without unresolved links.
Valid `index` and `see` annotations do not display their indexing metadata;
any supplied children remain visible. No index or target anchors are generated,
and malformed annotation data keeps the visible fallback.

Styles use VS Code CSS variables with browser fallbacks. Token colours
approximate semantic categories; interactive hovers are not implemented.
`Manual.renderers` is a smaller record that supplies extension names only,
useful when building your own adapter. The core `VersoCast` import does not
import Manual.

Reference-manual-specific examples, proof states, grammar, attribute roles,
syntax-kind labels and TODO notes belong to the
[validation consumer](../tests/reference-manual/CastManualPreview/Extensions.lean).
They are not part of the generic Manual adapter. See the
[reference-manual setup](DEVELOPMENT.md#lean-reference-manual-validation) to try it.

For custom code presentation, `VersoCast.Highlighting` renders stored SubVerso
tokens. Create its styles once and call `Highlighting.render styles value key`.
The optional root key defaults to `"root"`; supply distinct sibling-local keys
when composing multiple highlighting leaves.

## Blog pages and posts

Import `VersoCast.Blog` and create `Blog.createRenderers genre styles` in the
factory. It supports Page and Post through their `BlogGenre` instances, handling
highlighted Lean, compiler messages, lexed text, HTML spans/divs and docstring
containers. Blog and Manual share token and compiler-message presentation.
Summarized messages use native disclosures; ordinary messages stay expanded.
Disclosure state survives redraws while the block's React identity is retained.
Docstring sections turn their leading title paragraph into a heading and retain
the following body blocks. Levels 0–5 map to `h1`–`h6`; a missing title paragraph
or an out-of-range level keeps the visible fallback and its children.

The client supplies publication metadata, heading IDs, authors/dates and themes.
References, registered site components and arbitrary HTML blobs/wrappers/details
retain named fallbacks. Hover data is not interactive. The
[Post fixture](../tests/VersoCastTests/Blog.lean) shows the metadata hook and
distinct DOM ID prefixes for multiple document instances.

## Optional Slides package

Slides support lives in `packages/slides`. Add it at the Cast revision you pin:

```lean
require «verso-cast-slides» from git "https://github.com/ejgallego/verso-cast" @
  "<cast-commit>" / "packages/slides"
```

For a local checkout:

```lean
require «verso-cast-slides» from "/path/to/verso-cast/packages/slides"
```

The package uses its same-checkout Cast core and pins Verso Slides; no separate
core dependency is needed. Keep the matching Lean toolchain.

```lean
import VersoCastSlides
open VersoCast Lean.Vir.React

def createSlidesView (document : Verso.Doc.Part VersoSlides.Slides) :
    ReactM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let handlers ← VersoCast.Slides.createRenderers styles
  FunctionComponent.ofLean fun _ =>
    Renderer.render styles document (renderers := handlers)
```

The adapter shows the whole deck with notes and fragments visible. It supports
class roles/directives, nested decorations, code and compiler output, images,
and basic column-header tables. Vertical/background metadata is annotated;
navigation and Reveal.js grouping are left to the client. Arbitrary HTML/CSS,
diagrams, animations and richer tables remain named fallbacks. Row headers,
striped tables and separator/custom-padding flags are declined; supported
tables use Cast's preview styles rather than Reveal.js border styling.

Attribute extensions accept strings for `class`, `id`, `title`, `role`, `lang`,
`dir`, `aria-label`, `aria-hidden`, `aria-labelledby`, `aria-describedby`, and
lowercase `data-*` names outside Cast's `data-verso-*` namespace. A rejected
field declines the whole extension, preserving its children. Generic wrappers
have neutral styles so authored layout classes can take effect.

`createRenderers styles resolveImage` optionally accepts a pure
`VersoSlides.ImgSrc → Option String` URL mapping. The default `Slides.imageUrl?`
preserves remote URLs and declines project-relative paths. Empty/unresolved
URLs keep the fallback; clients publish assets and supply their mapping.
Image alt text, class and width/height are retained.

Stored Lean/slide code uses shared token styles. Fragments, click targets,
tactic ranges, diagnostic severity and panel/stretch requests are annotated,
but hover/panel/reveal behavior is not implemented. Hidden hover/goal content
is omitted. Command output is escaped, and non-Lean code preserves its source
without syntax highlighting. Code decoders operate on checked compiler exports
per render; malformed data keeps the fallback. Cyclic reference graphs and
resource limits are not validated, so this is not a hostile-input decoder.
The returned renderer record can be extended with your math and metadata hooks.

## Optional math leaf

Without a math component, Cast shows formula source. The optional JS helper
creates a stable KaTeX component shared by live rendering and SSR:

```js
import katex from "katex";
import "katex/dist/katex.css";
import { createMathComponent } from "verso-cast/katex";

const MathFormula = createMathComponent(katex); // once, outside render
```

The helper is exported by this repository's npm package, currently not published
to the registry. A client must make that package available to its JS bundler
separately from its Lake dependency. The Lean-only build needs neither npm nor
KaTeX.

Pass the native React function as `Renderer.Renderers.mathComponent?`. It
receives `source`, `data-verso-math-mode` and caller attributes. Clients supply
KaTeX, CSS/fonts and any genre-specific source preparation, including preludes.

The leaf uses `renderToString` with HTML and accessible MathML during rendering.
Memoization depends only on source and display mode; correctness does not rely
on retaining the memo. TeX is untrusted (`trust: false`), parse failures remain
visible, and every computation gets a fresh macro table. Only KaTeX-produced
HTML enters the inner-HTML boundary. See the [math demo](DEVELOPMENT.md#demos).

## Identities and retained state

Basic rendering uses positional React keys and needs no JSON, equality or hash
instances. Body edits at the same position preserve state, but insertion or
reordering can reuse positional state or remount subtrees. Use
`Renderers.blockIdentity?` for semantic identities of stateful authored blocks.
Labels are opaque strings, including separators and Unicode; sibling duplicates
are disambiguated. React keys are sibling-local and distinct from navigation
addresses.

Content identities are opt-in. For matching retained document contents, keep
`Fingerprint.State genre` in React state and advance it using
`Renderer.prepareIdentities previous document renderers`. This requires equality
and hashing for the genre's extensions. Pass
`{ fingerprint? := some (fun value => some (identities.key value)) }` in render
options, with the state prepared for that document and the same `blockIdentity?`
policy. Reprepare when either changes, not for cursor/control-only updates.
Preparation is pure and resolves hash collisions with exact equality.

For stateless serialized-content keys, use:

```lean
{ fingerprint? := some (fun value => some (VersoCast.Fingerprint.canonicalKey value)) }
```

This serializes content and remounts a container when that content changes, so
it is usually unsuitable for interactive previews. `Renderers.fingerprint`
supplies a shared stateless policy for rendering and change comparison;
`Options.fingerprint?` overrides it for a render, including with prepared state.

List and description-list item keys are positional. An identified block inside
an item cannot override the ancestor's identity; stable state through item
reordering needs a client-owned keyed list component. Changing an ancestor's
content key remounts its subtree. Ordered lists retain their signed `start`,
including zero and negative values.

## Focus and change highlighting

`Options.focus` marks a source-navigation address. It does not move keyboard
focus or scroll. Blocks, headings and list items select their matching nodes;
fragments mark visible child roots. A description-item address marks both term
and value, while `-term` and `-description` addresses select them separately.
Hidden, empty or missing addresses do not select a substitute.

`changedBlockIds*` compares raw heading/block contents using the stateless
`Renderers.fingerprint` policy, not a state prepared only for the current
document. It excludes part metadata and presentation/visibility changes, visits
stored children even when hidden, and returns only current-document paths.
Lists and blockquotes are coarse units; concatenations have no entry of their
own. Extension blocks and their stored children both contribute entries.
Neither comparison nor retained content hashing guarantees linear cost over
the whole document.

`changedBlockIdsAndCount` returns a comparison-snapshot count, not a visible DOM
count. The root's `data-verso-changed-block-count` counts supplied changed paths.
`renderBlockIds` returns initial comparison paths without equality/hash/JSON
instances. For finer highlighting, supply paths directly in `Options.changedIds`.
Focus and change markers are independent.

## Native attributes and ownership

`Options.debug` defaults to `false`. Source addresses, node kinds, focus/change
markers and visible fallbacks remain available; debug adds identity labels,
generated path tooltips and root inspection summaries. It does not change keys
or run an extra tree traversal. Client-owned tooltips remain under client control.

Root/math attributes are immutable arrays of `Renderer.Attribute` pairs.
`Attribute.of nativeKey nativeValue` widens only the value's phantom type, without
conversion or a host call. Cache keys/values with the factory's styles/components.
Rendering applies defaults, caller attributes and then reserved fields to fresh
props. Caller style/class/id override defaults; debug summaries and math
key/mode/source fields are reserved. Values are borrowed, not deep-copied or
mutated. Cast imposes no fixed document DOM ID.

Applying p supplied attributes takes O(p) native writes. Extension dispatch
adds O(1) work per visited extension, excluding the callback, its children and
opt-in identity policy. These describe the algorithm, not measured latency.

## Execution backends

Rendering, including Node SSR, executes through VIR. At the pinned revision,
the renderer's JavaScript host externs cannot run as native Lean C functions.
The pure `VersoCast.Fingerprint` helpers support native execution.
