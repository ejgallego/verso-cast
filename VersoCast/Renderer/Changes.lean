/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

module

public import VersoCast.Renderer.Config
import VersoCast.Renderer.Identity

/-! Pure document identity preparation and change-comparison helpers.
These visit stored document values, not rendered React nodes. -/
public section
namespace VersoCast.Renderer
open _root_.Verso
open Internal
variable {g : Doc.Genre}

private partial def appendFingerprintValues (renderers : Renderers g)
    (values : Array (Fingerprint.Value g)) (block : Doc.Block g) : Array (Fingerprint.Value g) := Id.run do
  let values := match blockIdentitySource renderers block with
    | .inl _ => values
    | .inr value => values.push (.inl value)
  match block with
  | .para _ | .code _ => return values
  | .concat blocks | .blockquote blocks | .other _ blocks =>
    return blocks.foldl (appendFingerprintValues renderers) values
  | .ul items | .ol _ items =>
    return items.foldl (fun values item => item.contents.foldl (appendFingerprintValues renderers) values) values
  | .dl items =>
    return items.foldl (fun values item => item.desc.foldl (appendFingerprintValues renderers) values) values

private partial def partFingerprintValues (renderers : Renderers g)
    (values : Array (Fingerprint.Value g)) (part : Doc.Part g) : Array (Fingerprint.Value g) :=
  let values := part.content.foldl (appendFingerprintValues renderers) (values.push (.inr part.title))
  part.subParts.foldl (partFingerprintValues renderers) values

/-- Advance one mounted preview's content identities. Explicit labels retain
their existing policy. Preparation visits document blocks but never renders
extension children or invokes JavaScript. Retain the result in React state. -/
def prepareIdentities [BEq g.Inline] [BEq g.Block] [Hashable g.Inline] [Hashable g.Block] (previous : Fingerprint.State g) (document : Doc.Part g)
    (renderers : Renderers g := {}) : Fingerprint.State g :=
  previous.advance (partFingerprintValues renderers #[] document)

private inductive SnapshotValue (g : Doc.Genre) where
  | heading (content : Array (_root_.Verso.Doc.Inline g))
  | block (content : _root_.Verso.Doc.Block g)

private instance [BEq g.Inline] [BEq g.Block] : BEq (SnapshotValue g) where
  beq
    | .heading left, .heading right => left == right
    | .block left, .block right => left == right
    | _, _ => false

private structure Snapshot (g : Doc.Genre) where
  debugPath : String
  semanticKey : String
  value : SnapshotValue g

private partial def appendBlockSnapshots (renderers : Renderers g)
    (snapshots : Array (Snapshot g))
    (identity : Identity) : _root_.Verso.Doc.Block g → Array (Snapshot g)
  | .concat content =>
      appendChildBlockSnapshots renderers snapshots identity.semanticKey identity.debugPath content
  | block@(.other _ content) =>
      let snapshots := snapshots.push {
        debugPath := identity.debugPath
        semanticKey := identity.semanticKey
        value := .block block
      }
      appendChildBlockSnapshots renderers snapshots identity.semanticKey identity.debugPath content
  | block => snapshots.push {
      debugPath := identity.debugPath
      semanticKey := identity.semanticKey
      value := .block block
    }
where
  appendChildBlockSnapshots (renderers : Renderers g)
      (snapshots : Array (Snapshot g))
      (parentSemanticKey debugParent : String)
      (content : Array (_root_.Verso.Doc.Block g)) : Array (Snapshot g) := Id.run do
    let identities := blockIdentities renderers parentSemanticKey debugParent content
    let mut snapshots := snapshots
    for index in [:content.size] do
      snapshots := appendBlockSnapshots renderers snapshots identities[index]! content[index]!
    return snapshots

private partial def appendSnapshots (renderers : Renderers g)
    (snapshots : Array (Snapshot g))
    (identity : Identity)
    (part : _root_.Verso.Doc.Part g) : Array (Snapshot g) := Id.run do
  let heading := headingIdentity identity
  let mut snapshots := snapshots.push {
    debugPath := heading.debugPath
    semanticKey := heading.semanticKey
    value := .heading part.title
  }
  let blocks := blockIdentities renderers identity.semanticKey identity.debugPath part.content
  for index in [:part.content.size] do
    snapshots := appendBlockSnapshots renderers snapshots blocks[index]! part.content[index]!
  let subParts := partIdentities renderers identity.semanticKey identity.debugPath part.subParts
  for index in [:part.subParts.size] do
    snapshots := appendSnapshots renderers snapshots subParts[index]! part.subParts[index]!
  return snapshots

private def snapshots (renderers : Renderers g) (document : Doc.Part g) : Array (Snapshot g) :=
  appendSnapshots renderers #[] rootIdentity document

/--
Renderer paths changed relative to the optional previous document, together
with the current comparison-snapshot count, not a DOM/visible-node count.
Headings and ordinary blocks are snapshots; lists and quotes are compared as
whole blocks. Concatenations have no snapshot of their own. Extension blocks
and their stored children are visited without invoking rendering callbacks,
including hidden content. Only current-document paths are returned.
The current snapshot tree is collected once for both results. Comparisons use
the stateless `renderers.fingerprint` policy, not a current-only prepared state.
-/
def changedBlockIdsAndCount [BEq g.Inline] [BEq g.Block]
    (previous : Option (Doc.Part g))
    (current : Doc.Part g)
    (renderers : Renderers g := {}) : Array String × Nat :=
  let currentSnapshots := snapshots renderers current
  let changedIds :=
    match previous with
    | none => currentSnapshots.map (·.debugPath)
    | some previous =>
        let previousByKey := snapshots renderers previous |>.foldl
          (init := ({} : Std.HashMap String (SnapshotValue g))) fun entries snapshot =>
            entries.insert snapshot.semanticKey snapshot.value
        currentSnapshots.filterMap fun snapshot =>
          match previousByKey.get? snapshot.semanticKey with
          | some prior => if prior == snapshot.value then none else some snapshot.debugPath
          | none => some snapshot.debugPath
  (changedIds, currentSnapshots.size)

/-- Initial comparison paths, including stored extension children irrespective
of rendering visibility. No equality/hash/JSON instances are required. -/
def renderBlockIds (document : Doc.Part g)
    (renderers : Renderers g := {}) : Array String :=
  (snapshots renderers document).map (·.debugPath)

/-- Renderer paths whose semantic nodes are new or changed in `current`. -/
def changedBlockIds [BEq g.Inline] [BEq g.Block] (previous current : Doc.Part g)
    (renderers : Renderers g := {}) : Array String :=
  (changedBlockIdsAndCount (some previous) current renderers).1

end VersoCast.Renderer
