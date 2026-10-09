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
in their owning projects. Optional KaTeX integration is not yet extracted.
