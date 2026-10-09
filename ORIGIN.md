# Extraction provenance

The initial renderer, render paths, fixed JavaScript strings, fingerprint state,
Lean fixtures and React assertions were extracted from
`leanprover/verso-blueprint`, commit
`9aa9d8892cf9c243e12771fc29418e9f2b777f3b`, directory
`packages/verso-react` (Lean 4.34.0-rc2).

Copyright, authorship and Apache-2.0 licensing are preserved. The initial port
renames `VersoReact` to `VersoCast` and selects exact public Lean 4.35 dependency
revisions; it does not change rendering or identity algorithms. No generated
IR, SDK or Wasm from the old toolchain was transferred.

`VersoReact/Json.lean` was deliberately excluded: its private-API serialization
writer is not part of the rendering boundary. Blueprint-specific adapters,
server/RPC/session controls, low-level codec experiments and FIR packages remain
in their owning projects.

Subsequent Cast changes are not an unchanged copy of the old renderer: the core
is genre-agnostic, with client-owned render/identity hooks, part-metadata hooks,
immutable attribute pairs and no fixed document DOM ID. Footnotes use valid
inline markup, description-list halves accept their own focus addresses, and
initial change paths no longer require equality instances. Change comparison
remains coarse for lists/quotes; its count describes snapshots, not visible DOM.

The optional `web/katex.mjs` leaf replaces the old effect-only integration with
render-time HTML/MathML, usable by both live React and offline SSR. It does not
interpret `data-bp-tex-prelude`; Blueprint source/prelude policy stays in VBP.
The core Lean renderer remains usable without npm or KaTeX.
