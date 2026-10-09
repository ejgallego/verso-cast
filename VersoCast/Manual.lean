/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Renderer
public import VersoManual.Basic

public section
namespace VersoCast.Manual

/-- Manual's named extension placeholders and stateless content-key policy.
Clients extend this ordinary record with their own rendering callbacks.
This adapter does not run Manual traversal or resolve cross-references. -/
def renderers : Renderer.Renderers Verso.Genre.Manual where
  inlineName := fun extension => extension.name.toString
  blockName := fun extension => extension.name.toString
  fingerprint := fun value => some (Fingerprint.canonicalKey value)

end VersoCast.Manual
