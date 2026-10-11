/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

module

import VersoCast.Renderer.Identity
meta import VersoCast.Renderer.Identity

namespace VersoCastTests.Identity
open VersoCast.Renderer.Internal

#guard
  let explicit := ({
    explicitId? := some "author"
    fingerprint? := some "content"
  } : IdentityHints).resolve "block" 0 "part-root-block-0"
  let fingerprint := ({ fingerprint? := some "content" } : IdentityHints).resolve
    "block" 0 "part-root-block-0"
  let positional := ({} : IdentityHints).resolve "block" 0 "part-root-block-0"
  explicit.origin == .explicit && explicit.reactKey == "explicit:author" &&
  fingerprint.origin == .fingerprint && positional.origin == .positional

#guard
  let duplicate := ({ fingerprint? := some "same" } : IdentityHints)
  let identities := allocateSiblingIdentities "root" "part-root" "block" "block"
    #[duplicate, duplicate]
  identities[0]!.reactKey != identities[1]!.reactKey &&
  identities[0]!.friendlyId != identities[1]!.friendlyId

#guard
  let before := allocateSiblingIdentities "same-parent" "part-root-block-0" "block" "block" #[{}, {}]
  let moved := allocateSiblingIdentities "same-parent" "part-root-block-1" "block" "block" #[{}, {}]
  before[0]!.reactKey == moved[0]!.reactKey &&
  before[0]!.semanticKey == moved[0]!.semanticKey &&
  before[0]!.debugPath != moved[0]!.debugPath &&
  before[0]!.reactKey != before[1]!.reactKey

end VersoCastTests.Identity
