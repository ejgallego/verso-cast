# Consumer adapter migration

The VBP adapter remains VBP-owned. The reviewed reference is its old
`src/VersoBlueprintVir/Preview/Renderer.lean` at the provenance checkpoint in
[ORIGIN.md](../ORIGIN.md), not an execution comparison across toolchains. Its
extension dispatch fits Cast's existing hooks; no Blueprint registry or second
document traversal belongs in Cast.

| Old adapter responsibility | Cast boundary / migration |
| --- | --- |
| `Extensions` for Manual | `Renderer.Renderers Genre.Manual`, starting from `Manual.renderers` when retaining the old stateless content-key policy |
| Math roles | `renderInline?` and `renderMath`; VBP decodes role data and owns malformed-role output |
| Informal statements/proofs | `renderBlock?` with the supplied fresh attributes and lazy children; VBP owns labels, facet wording and presentation |
| External markup | The same block hook supports hidden, summary and source modes; hidden mode must not invoke children |
| Semantic labels | `blockIdentity?`; keep decoding/label semantics and malformed-data tests in VBP |
| Version/correlation/cursor diagnostics | Explicit native `Attribute` pairs in `Options.attributes`; no mutation of a caller-owned props object |
| Prepared identity state | `prepareIdentities` plus the state's key function in `Options.fingerprint?`, separate from the stateless change-comparison policy |
| Math class/prelude attributes | Native `Attribute` pairs; source/key/mode are reserved by `renderMath` |

For KaTeX, VBP must prepare the formula source or supply a small stable component
wrapper that prepares it before calling Cast's math leaf. The generic leaf does
not read Blueprint prelude attributes. Keep raw-source fallback behavior
explicit, avoid sharing mutable macro tables across formulas, and qualify
prelude isolation/recovery in VBP. CSS/fonts and third-party loading are client
responsibilities. The old opaque attribute object cannot be passed as-is: cache
fixed native keys/values once and assemble the explicit pairs for each render.

The consumer parity gate should cover statement/proof labels and children;
external-markup hidden/summary/source modes and source escaping; malformed and
unknown extensions; native root/math attribute precedence; math with and
without preludes; identity/state retention through edits; and focus/change
markers. Cast's generic fixtures do not qualify these Blueprint semantics.
Manual metadata and traversal-dependent numbering/reference resolution remain
client responsibilities, even though Cast provides a part-metadata hook.

Consume a reviewed Git commit rather than this mutable working directory:

```lean
require «verso-cast» from git
  "file:///home/egallego/lean/verso-cast" @ "<reviewed-cast-commit>"
```

This is a workspace-local dependency until the repository is published. Preserve
the old VBP demo until the consumer's parity gates pass. Use the same exact Lean,
Verso and VIR identities for source and runtime assets; no 4.34 artifact is
transferred by the extraction. Codecs, FIR qualification and editor-shell
integration are separate gates, not prerequisites for reviewing the adapter.
