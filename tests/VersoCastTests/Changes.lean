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
  let kind := scenario / 2
  let before := document kind "before"
  let current := document kind (if scenario % 2 == 0 then "before" else "after")
  let (changedIds, _snapshotCount) := Renderer.changedBlockIdsAndCount (some before) current renderers
  Renderer.render styles current { changedIds } renderers

end VersoCastTests.Changes
