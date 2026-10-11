/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

module

public import VersoCast.Renderer.Config
public import VersoCast.RenderPath

/-! Internal sibling identity allocation shared by comparison and rendering.
Not re-exported by the public Cast root. -/
public section
namespace VersoCast.Renderer.Internal
open _root_.Verso
variable {g : Doc.Genre}

inductive IdentityOrigin where
  | structural
  | explicit
  | fingerprint
  | positional
  deriving BEq, Inhabited

def IdentityOrigin.label : IdentityOrigin → String
  | .structural => "structural"
  | .explicit => "explicit"
  | .fingerprint => "fingerprint"
  | .positional => "positional"

/--
Identity sources are ordered from strongest to weakest. Content-keyed blocks
reach the fingerprint branch; extension metadata can provide stronger semantic
identities where the application owns their meaning.
-/
structure IdentityHints where
  explicitId? : Option String := none
  fingerprint? : Option String := none
  deriving Inhabited

structure IdentityBase where
  reactKey : String
  friendlyId : String
  origin : IdentityOrigin

structure Identity where
  reactKey : String
  debugPath : String
  semanticKey : String
  friendlyId : String
  origin : IdentityOrigin
  deriving Inhabited

def fingerprintFriendlyId (value : String) : String :=
  s!"fp-{(hash value : UInt64)}"

-- The segment is a fixed internal role; the key is opaque client data and may
-- contain separators. This encoding is separate from React keys and navigation.
def semanticChild (parent segment key : String) : String :=
  s!"{parent}/{segment}/{key.length}:{key}"

def IdentityHints.resolve
    (kind : String) (index : Nat) (debugPath : String) (hints : IdentityHints) : IdentityBase :=
  match hints.explicitId?, hints.fingerprint? with
  | some value, _ =>
      { reactKey := s!"explicit:{value}", friendlyId := value, origin := .explicit }
  | none, some value =>
      -- The full canonical value stays in the React key. The short hash is
      -- human-facing only, so collisions cannot alias siblings.
      { reactKey := s!"fingerprint:{kind}:{value.length}:{value}"
        friendlyId := fingerprintFriendlyId value
        origin := .fingerprint }
  | none, none =>
      { reactKey := s!"position:{kind}:{index}", friendlyId := debugPath, origin := .positional }

def allocateSiblingIdentities
    (parentSemanticKey debugParent segment kind : String)
    (hints : Array IdentityHints) : Array Identity := Id.run do
  let mut seen : Std.HashMap String Nat := {}
  let mut identities := #[]
  for index in [:hints.size] do
    let debugPath := RenderPath.child debugParent segment index
    let base := hints[index]!.resolve kind index debugPath
    let occurrence := seen.getD base.reactKey 0
    seen := seen.insert base.reactKey (occurrence + 1)
    let reactKey := s!"{base.reactKey}:occurrence:{occurrence}"
    let friendlyId :=
      if occurrence == 0 then base.friendlyId else s!"{base.friendlyId}~{occurrence}"
    identities := identities.push {
      reactKey
      debugPath
      semanticKey := semanticChild parentSemanticKey segment reactKey
      friendlyId
      origin := base.origin
    }
  return identities

partial def blockIdentitySource (renderers : Renderers g)
    (block : _root_.Verso.Doc.Block g) : String ⊕ Doc.Block g :=
  match block with
  | .concat content =>
      if content.size == 1 then
        blockIdentitySource renderers content[0]!
      else
        .inr block
  | .other extension _ =>
      match renderers.blockIdentity? extension with
      | some identity => .inl identity
      | none => .inr block
  | _ => .inr block

def blockIdentityHints (renderers : Renderers g) (block : Doc.Block g)
    (fingerprint : Fingerprint.Value g → Option String) : IdentityHints :=
  match blockIdentitySource renderers block with
  | .inl identity => { explicitId? := some identity }
  | .inr block => { fingerprint? := fingerprint (.inl block) }

def partIdentityHints
    (part : _root_.Verso.Doc.Part g)
    (fingerprint : Fingerprint.Value g → Option String) : IdentityHints :=
  -- A section title identifies the section without coupling its key to body edits.
  { fingerprint? := fingerprint (.inr part.title) }

def blockIdentities (renderers : Renderers g)
    (parentSemanticKey debugParent : String)
    (blocks : Array (_root_.Verso.Doc.Block g))
    (fingerprint : Fingerprint.Value g → Option String := renderers.fingerprint) : Array Identity :=
  allocateSiblingIdentities parentSemanticKey debugParent "block" "block"
    (blocks.map (fun block => blockIdentityHints renderers block fingerprint))

def partIdentities (renderers : Renderers g)
    (parentSemanticKey debugParent : String)
    (parts : Array (_root_.Verso.Doc.Part g))
    (fingerprint : Fingerprint.Value g → Option String := renderers.fingerprint) : Array Identity :=
  allocateSiblingIdentities parentSemanticKey debugParent "part" "part"
    (parts.map (fun part => partIdentityHints part fingerprint))

def rootIdentity : Identity := {
  reactKey := "structural:root"
  debugPath := RenderPath.root
  semanticKey := "root"
  friendlyId := "root"
  origin := .structural
}

def headingIdentity (part : Identity) : Identity := {
  reactKey := "structural:heading"
  debugPath := RenderPath.heading part.debugPath
  semanticKey := semanticChild part.semanticKey "heading" ""
  friendlyId := s!"{part.friendlyId}/heading"
  origin := .structural
}

end VersoCast.Renderer.Internal
