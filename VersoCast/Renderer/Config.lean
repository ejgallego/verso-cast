/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

module

public import VersoCast.Renderer.Style
public import VersoCast.Fingerprint

/-! Client extension hooks and per-render configuration. -/
public section
namespace VersoCast.Renderer
open Lean.Vir Lean.Vir.React
open _root_.Verso

/-- A replacement heading receives the level, fresh attributes and title nodes. -/
abbrev HeaderRenderer := Nat → Js Props → Array (Js Node) → ReactM (Js Node)

/--
Application-owned genre renderers. Unhandled extensions remain visible together
with their children. Callbacks may return ordinary component nodes, but are not
hook scopes. Children are lazy: call at most once, and return `some` after using
them. Returning `none` delegates to fallback rendering. Inline renderers must
produce phrasing content, so paragraphs remain valid HTML.
-/
structure Renderers (g : Doc.Genre) where
  /-- Optional stable leaf component. It receives source, mode and caller attributes. -/
  mathComponent? : Option (FunctionComponent Props) := none
  /-- Replace an inline extension using its sibling-local React key (not a source path),
  or return `none` for the visible fallback. -/
  renderInline? : (key : String) → g.Inline →
      (children : Unit → ReactM (Array (Js Node))) → ReactM (Option (Js Node)) :=
    fun _ _ _ => pure none
  /--
  Replace a block extension, or return `none` for the visible fallback.
  `attributes kind style` supplies the existing key, identity, focus and change
  markers. Call `children ()` once when needed; hidden blocks can skip it.
  -/
  renderBlock? : (key : String) → (attributes : String → Js Props → ReactM (Js Props)) →
      g.Block → (children : Unit → ReactM (Array (Js Node))) →
      ReactM (Option (Js Node)) :=
    fun _ _ _ _ => pure none
  /-- Optional opaque semantic identity; any string is accepted, including separators.
  Sibling duplicates are disambiguated by the renderer. -/
  blockIdentity? : g.Block → Option String := fun _ => none
  /-- Optional content identities; basic rendering uses positional keys. -/
  fingerprint : Fingerprint.Value g → Option String := fun _ => none
  /-- Names used only in visible unsupported-extension placeholders. -/
  inlineName : g.Inline → String := fun _ => "unknown"
  blockName : g.Block → String := fun _ => "unknown"
  /-- Customize metadata-bearing parts without copying section traversal.
  The part has its own metadata removed; descendant metadata is preserved.
  `renderDefault none` uses the normal heading. A custom heading receives its
  level, fresh key/focus/change props, and rendered title. It must return an hN
  at that level (clamped to h6). Call the default at most once and return `some`.
  No child or title rendering has happened before this callback. -/
  renderPart? : (key : String) → g.PartMetadata →
      (part : Doc.Part g) →
      (renderDefault : Option HeaderRenderer → ReactM (Js Node)) → ReactM (Option (Js Node)) :=
    fun _ _ _ _ => pure none

/-- An exact native attribute pair. Cache keys/values in the component factory.
The renderer borrows values and writes only to its own fresh props object. -/
structure Attribute where
  name : Js String
  value : Js.Any

/-- Build a field while widening only the value's phantom shape. No value
conversion, native allocation or host call; the small Lean record can be cached. -/
@[inline] def Attribute.of {α : Type} (name : Js String) (value : Js α) : Attribute :=
  { name, value := by unfold Js.Any Js at *; exact value }

/-- Options computed by the stateful component before constructing the Verso VDOM. -/
structure Options (g : Doc.Genre) where
  /-- Opt-in inspection labels/tooltips and document diagnostic summaries.
  React keys, source addresses, focus/change markers and fallbacks are unaffected. -/
  debug : Bool := false
  changedIds : Array String := #[]
  /-- Source-navigation address, separate from React keys. It marks matching
  blocks/headings or list items. Fragments mark their visible child roots;
  a description-item address marks both term and value, whose own addresses
  select them separately. Hidden/missing addresses do not select a substitute.
  No DOM focus or scrolling is performed. -/
  focus : Option String := none
  /-- Later attributes override style/class defaults, never mutate their values.
  When debug is enabled, Cast's diagnostic summary attributes are written last. -/
  attributes : Array Attribute := #[]
  /-- Override the adapter identity policy, e.g. with a prepared state key. -/
  fingerprint? : Option (Fingerprint.Value g → Option String) := none

end VersoCast.Renderer
