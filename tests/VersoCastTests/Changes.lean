/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast
public import VersoCastTests.Fixture
public import VersoManual.Basic
meta import VersoCast.Renderer
meta import VersoCastTests.Fixture

public section
namespace VersoCastTests.Changes
open Verso Verso.Doc VersoCast Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def paragraph (text : String) : Block Genre.Manual := .para #[.text text]

private def block (kind : Nat) (text : String) : Block Genre.Manual :=
  let child := paragraph text
  match kind with
  | 0 => .ul #[.mk #[child]]
  | 1 => .ol 7 #[.mk #[child]]
  | 2 => .dl #[.mk #[.text "Term"] #[child]]
  | 3 => .blockquote #[child]
  | 4 => .other { name := `Changes.visible, data := .null } #[child]
  | 5 => .other { name := `Changes.hidden, data := .null } #[child]
  | _ => .concat #[.concat #[], child]

private def document (kind : Nat) (text : String) : Part Genre.Manual :=
  .mk #[.text "Change tracking"] "Change tracking" none #[block kind text] #[]

-- This genre deliberately has no equality/hash/JSON instances. Initial
-- comparison addresses depend only on structure and the chosen identity policy.
def genericInitialIds : Array String := Renderer.renderBlockIds Fixture.document
#guard genericInitialIds.contains "part-root-block-7-block-0-block-0"

private def expectedPaths (kind : Nat) : Array String :=
  if kind ≤ 3 then #["part-root-block-0"]
  else if kind ≤ 5 then #["part-root-block-0", "part-root-block-0-block-0"]
  else #["part-root-block-0-block-1"]

def policyChecks : Bool := Id.run do
  for kind in [:7] do
    let before := document kind "before"
    let after := document kind "after"
    let initial := #["part-root-heading"] ++ expectedPaths kind
    if Renderer.renderBlockIds after != initial then return false
    if Renderer.changedBlockIdsAndCount none after != (initial, initial.size) then return false
    if Renderer.changedBlockIdsAndCount (some before) after != (expectedPaths kind, initial.size) then return false
    if !(Renderer.changedBlockIds after after).isEmpty then return false
  -- Removed nodes have no current address to highlight, even when the snapshot
  -- count shrinks. Fragments themselves never add a phantom comparison node.
  let empty : Part Genre.Manual := .mk #[] "" none #[.concat #[]] #[]
  if Renderer.renderBlockIds empty != #["part-root-heading"] then return false
  if Renderer.changedBlockIds (document 0 "before") empty != #["part-root-heading"] then return false
  -- Description-term and ordered-start edits are whole-list changes too.
  let desc : Part Genre.Manual := .mk #[.text "Change tracking"] "Change tracking" none
    #[.dl #[.mk #[.text "New term"] #[paragraph "before"]]] #[]
  let ordered : Part Genre.Manual := .mk #[.text "Change tracking"] "Change tracking" none
    #[.ol 9 #[.mk #[paragraph "before"]]] #[]
  return Renderer.changedBlockIds (document 2 "before") desc == #["part-root-block-0"] &&
    Renderer.changedBlockIds (document 1 "before") ordered == #["part-root-block-0"]

#guard policyChecks

private def labeled (label : String) (children : Array (Block Genre.Manual)) : Block Genre.Manual :=
  .other { name := `Changes.label, data := .str label } children

private def labelRenderers : Renderer.Renderers Genre.Manual where
  blockIdentity? := fun extension => match extension.data with
    | .str label => some label
    | _ => none

private def labeledDocument (nested sibling : String) : Part Genre.Manual :=
  .mk #[] "" none #[
    labeled "a" #[labeled "b" #[paragraph nested]],
    labeled "a:occurrence:0/block/explicit:b" #[paragraph sibling]
  ] #[]

/-- Opaque client labels must not alias nested comparison paths. -/
def identityPathChecks : Bool := Id.run do
  let before := labeledDocument "nested" "sibling"
  if !(Renderer.changedBlockIds before before labelRenderers).isEmpty then return false
  if Renderer.changedBlockIdsAndCount (some before) before labelRenderers != (#[], 6) then
    return false
  if Renderer.changedBlockIds before (labeledDocument "edited" "sibling") labelRenderers !=
      #["part-root-block-0", "part-root-block-0-block-0", "part-root-block-0-block-0-block-0"] then
    return false
  if Renderer.changedBlockIds before (labeledDocument "nested" "edited") labelRenderers !=
      #["part-root-block-1", "part-root-block-1-block-0"] then return false
  let moved := { before with content := before.content.reverse }
  if !(Renderer.changedBlockIds before moved labelRenderers).isEmpty then return false
  let onlySibling := { before with content := #[before.content[1]!] }
  if !(Renderer.changedBlockIds before onlySibling labelRenderers).isEmpty then return false
  -- No restrictions on separator characters or Unicode in a client's label.
  for label in #["", "/", "heading", "0:", "α/🧭:occurrence:0"] do
    let document : Part Genre.Manual := .mk #[] "" none
      #[labeled label #[paragraph "one"], labeled label #[paragraph "two"]] #[]
    if !(Renderer.changedBlockIds document document labelRenderers).isEmpty then return false
  return true

#guard identityPathChecks

private def renderers : Renderer.Renderers Genre.Manual where
  renderBlock? := fun key _attributes extension _children => do
    if extension.name == `Changes.hidden then
      let props ← js%{ "key" := (← JsValue.ofString key) }
      return some (← Node.fragment props (← Js.Array.empty))
    else return none

/-- Rendering checks consume the real diff results, not hand-written markers. -/
def render (scenario : Nat) : ReactM (Js Node) := do
  let styles ← Renderer.Styles.create
  if scenario == 14 then
    return ← Renderer.render styles Fixture.document { changedIds := genericInitialIds }
  if scenario ≥ 15 then
    let before := labeledDocument "nested" "sibling"
    let current := match scenario with
      | 16 => labeledDocument "edited" "sibling"
      | 17 => labeledDocument "nested" "edited"
      | _ => before
    let changedIds := Renderer.changedBlockIds before current labelRenderers
    return ← Renderer.render styles current { changedIds } labelRenderers
  let kind := scenario / 2
  let before := document kind "before"
  let current := document kind (if scenario % 2 == 0 then "before" else "after")
  let (changedIds, _snapshotCount) := Renderer.changedBlockIdsAndCount (some before) current renderers
  Renderer.render styles current { changedIds, debug := true } renderers

end VersoCastTests.Changes
