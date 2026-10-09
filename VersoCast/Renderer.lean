/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

module

public import Vir.React
public import Vir.ProofWidgets.Jsx
public import Verso.Doc
public import VersoCast.RenderPath
public import VersoCast.Fingerprint
public import VersoCast.JsStrings
public meta import VersoCast.RenderPath

public section

namespace VersoCast.Renderer

open Lean.Vir
open Lean.Vir.React
open Lean.Doc.Syntax
open _root_.Verso
open Verso.Doc

variable {g : Doc.Genre}
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

namespace Style

private def vscodeColor (name fallback : String) : String :=
  "var(--vscode-" ++ name ++ ", " ++ fallback ++ ")"

private def border (color : String) : String :=
  "1px solid " ++ color

def foreground : String := vscodeColor "editor-foreground" "#24292f"
def muted : String := vscodeColor "descriptionForeground" "#57606a"
def background : String := vscodeColor "editor-background" "#ffffff"
def codeBackground : String := vscodeColor "textCodeBlock-background" "#f6f8fa"
def borderColor : String := vscodeColor "panel-border" "#d0d7de"

def document : ReactM (Js Props) := js%{ "display" := (← js#"grid"), "gap" := (← js#"10px"), "minWidth" := (← js#"0"), "padding" := (← js#"10px 12px"), "border" := (← JsValue.ofString (border borderColor)), "borderRadius" := (← js#"6px"), "background" := (← JsValue.ofString background), "color" := (← JsValue.ofString foreground), "colorScheme" := (← js#"light dark"), "fontFamily" := (← js#"Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"), "overflowWrap" := (← js#"anywhere") }
def part : ReactM (Js Props) := js%{ "display" := (← js#"grid"), "gap" := (← js#"10px"), "minWidth" := (← js#"0") }
def heading : ReactM (Js Props) := js%{ "margin" := (← js#"0"), "fontSize" := (← js#"1.12rem"), "lineHeight" := (← js#"1.3") }
def paragraph : ReactM (Js Props) := js%{ "margin" := (← js#"0"), "lineHeight" := (← js#"1.5") }
def list : ReactM (Js Props) := js%{ "display" := (← js#"grid"), "gap" := (← js#"6px"), "margin" := (← js#"0"), "paddingLeft" := (← js#"1.5rem") }
def listItem : ReactM (Js Props) := js%{ "paddingLeft" := (← js#"0.15rem") }
def blockquote : ReactM (Js Props) := js%{ "display" := (← js#"grid"), "gap" := (← js#"8px"), "margin" := (← js#"0"), "padding" := (← js#"2px 0 2px 12px"), "borderLeft" := (← JsValue.ofString (border borderColor)), "color" := (← JsValue.ofString muted) }
def descriptionList : ReactM (Js Props) := js%{ "display" := (← js#"grid"), "gridTemplateColumns" := (← js#"max-content minmax(0, 1fr)"), "gap" := (← js#"6px 10px"), "margin" := (← js#"0") }
def descriptionTerm : ReactM (Js Props) := js%{ "fontWeight" := (← js#"700") }
def descriptionValue : ReactM (Js Props) := js%{ "margin" := (← js#"0") }
def inlineCode : ReactM (Js Props) := js%{ "padding" := (← js#"0.08em 0.3em"), "borderRadius" := (← js#"3px"), "background" := (← JsValue.ofString codeBackground), "fontFamily" := (← js#"ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"), "fontSize" := (← js#"0.92em") }
def codeBlock : ReactM (Js Props) := js%{ "margin" := (← js#"0"), "padding" := (← js#"9px 10px"), "overflow" := (← js#"auto"), "borderRadius" := (← js#"5px"), "background" := (← JsValue.ofString codeBackground), "fontFamily" := (← js#"ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"), "fontSize" := (← js#"0.78rem"), "lineHeight" := (← js#"1.45"), "whiteSpace" := (← js#"pre") }
def mathInline : ReactM (Js Props) := js%{ "padding" := (← js#"0 0.08em"), "fontFamily" := (← js#"KaTeX_Main, Cambria Math, STIX Two Math, serif"), "fontSize" := (← js#"1.02em"), "whiteSpace" := (← js#"pre-wrap") }
def mathDisplay : ReactM (Js Props) := js%{ "display" := (← js#"block"), "padding" := (← js#"8px 10px"), "overflowX" := (← js#"auto"), "borderRadius" := (← js#"5px"), "background" := (← JsValue.ofString codeBackground), "fontFamily" := (← js#"KaTeX_Main, Cambria Math, STIX Two Math, serif"), "fontSize" := (← js#"1.02em"), "lineHeight" := (← js#"1.5"), "textAlign" := (← js#"center"), "whiteSpace" := (← js#"pre-wrap") }
def unsupported : ReactM (Js Props) := js%{ "padding" := (← js#"7px 9px"), "border" := (← JsValue.ofString (border borderColor)), "borderRadius" := (← js#"5px"), "color" := (← JsValue.ofString muted) }

end Style

/-- Constant styles owned by one component factory. Treat these objects as read-only;
node attributes remain fresh. CSS variables keep theme changes independent of React updates. -/
structure Styles where
  strings : JsStrings.Fixed
  document : Js Props
  part : Js Props
  heading : Js Props
  paragraph : Js Props
  list : Js Props
  listItem : Js Props
  blockquote : Js Props
  descriptionList : Js Props
  descriptionTerm : Js Props
  descriptionValue : Js Props
  inlineCode : Js Props
  codeBlock : Js Props
  mathInline : Js Props
  mathDisplay : Js Props
  unsupported : Js Props

def Styles.create : ReactM Styles := do
  return {
    strings := ← JsStrings.Fixed.create
    document := ← Style.document, part := ← Style.part, heading := ← Style.heading
    paragraph := ← Style.paragraph, list := ← Style.list, listItem := ← Style.listItem
    blockquote := ← Style.blockquote, descriptionList := ← Style.descriptionList
    descriptionTerm := ← Style.descriptionTerm, descriptionValue := ← Style.descriptionValue
    inlineCode := ← Style.inlineCode, codeBlock := ← Style.codeBlock
    mathInline := ← Style.mathInline, mathDisplay := ← Style.mathDisplay
    unsupported := ← Style.unsupported
  }

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
  /-- Optional semantic identity; sibling duplicates are disambiguated by the renderer. -/
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

private def applyAttributes (props : Js Props) (attributes : Array Attribute) : ReactM Unit := do
  for field in attributes do
    Js.Construction.field props field.name field.value

private inductive IdentityOrigin where
  | structural
  | explicit
  | verso
  | fingerprint
  | positional
  deriving BEq, Inhabited

private def IdentityOrigin.label : IdentityOrigin → String
  | .structural => "structural"
  | .explicit => "explicit"
  | .verso => "verso"
  | .fingerprint => "fingerprint"
  | .positional => "positional"

private def IdentityOrigin.jsLabel (strings : JsStrings.Fixed) : IdentityOrigin → Js String
  | .structural => strings.values.structural
  | .explicit => strings.values.explicit
  | .verso => strings.values.verso
  | .fingerprint => strings.values.fingerprint
  | .positional => strings.values.positional

/--
Identity sources are ordered from strongest to weakest. Content-keyed blocks
reach the fingerprint branch; extension metadata can provide stronger semantic
identities where the application owns their meaning.
-/
private structure IdentityHints where
  explicitId? : Option String := none
  versoId? : Option String := none
  fingerprint? : Option String := none
  deriving Inhabited

private structure IdentityBase where
  reactKey : String
  friendlyId : String
  origin : IdentityOrigin

private structure Identity where
  reactKey : String
  debugPath : String
  semanticKey : String
  friendlyId : String
  origin : IdentityOrigin
  deriving Inhabited

private def fingerprintFriendlyId (value : String) : String :=
  s!"fp-{(hash value : UInt64)}"

private def IdentityHints.resolve
    (kind : String) (index : Nat) (debugPath : String) (hints : IdentityHints) : IdentityBase :=
  match hints.explicitId?, hints.versoId?, hints.fingerprint? with
  | some value, _, _ =>
      { reactKey := s!"explicit:{value}", friendlyId := value, origin := .explicit }
  | none, some value, _ =>
      { reactKey := s!"verso:{value}", friendlyId := value, origin := .verso }
  | none, none, some value =>
      -- The full canonical value stays in the React key. The short hash is
      -- human-facing only, so collisions cannot alias siblings.
      { reactKey := s!"fingerprint:{kind}:{value.length}:{value}"
        friendlyId := fingerprintFriendlyId value
        origin := .fingerprint }
  | none, none, none =>
      { reactKey := s!"position:{kind}:{index}", friendlyId := debugPath, origin := .positional }

private def allocateSiblingIdentities
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
      semanticKey := s!"{parentSemanticKey}/{segment}/{reactKey}"
      friendlyId
      origin := base.origin
    }
  return identities

private partial def blockIdentitySource (renderers : Renderers g)
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

private def blockIdentityHints (renderers : Renderers g) (block : Doc.Block g)
    (fingerprint : Fingerprint.Value g → Option String) : IdentityHints :=
  match blockIdentitySource renderers block with
  | .inl identity => { explicitId? := some identity }
  | .inr block => { fingerprint? := fingerprint (.inl block) }

private def partIdentityHints
    (part : _root_.Verso.Doc.Part g)
    (fingerprint : Fingerprint.Value g → Option String) : IdentityHints :=
  -- A section title identifies the section without coupling its key to body edits.
  { fingerprint? := fingerprint (.inr part.title) }

private def blockIdentities (renderers : Renderers g)
    (parentSemanticKey debugParent : String)
    (blocks : Array (_root_.Verso.Doc.Block g))
    (fingerprint : Fingerprint.Value g → Option String := renderers.fingerprint) : Array Identity :=
  allocateSiblingIdentities parentSemanticKey debugParent "block" "block"
    (blocks.map (fun block => blockIdentityHints renderers block fingerprint))

private def partIdentities (renderers : Renderers g)
    (parentSemanticKey debugParent : String)
    (parts : Array (_root_.Verso.Doc.Part g))
    (fingerprint : Fingerprint.Value g → Option String := renderers.fingerprint) : Array Identity :=
  allocateSiblingIdentities parentSemanticKey debugParent "part" "part"
    (parts.map (fun part => partIdentityHints part fingerprint))

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

private def rootIdentity : Identity := {
  reactKey := "structural:root"
  debugPath := RenderPath.root
  semanticKey := "root"
  friendlyId := "root"
  origin := .structural
}

private def headingIdentity (part : Identity) : Identity := {
  reactKey := "structural:heading"
  debugPath := RenderPath.heading part.debugPath
  semanticKey := s!"{part.semanticKey}/heading"
  friendlyId := s!"{part.friendlyId}/heading"
  origin := .structural
}

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
with the current renderer-node count. The current snapshot tree is collected
once so change highlighting and diagnostics share the same traversal.
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

/-- Structural renderer paths used to highlight a newly mounted document. -/
def renderBlockIds [BEq g.Inline] [BEq g.Block] (document : Doc.Part g)
    (renderers : Renderers g := {}) : Array String :=
  (changedBlockIdsAndCount none document renderers).1

/-- Renderer paths whose semantic nodes are new or changed in `current`. -/
def changedBlockIds [BEq g.Inline] [BEq g.Block] (previous current : Doc.Part g)
    (renderers : Renderers g := {}) : Array String :=
  (changedBlockIdsAndCount (some previous) current renderers).1

private def blockProps
    (styles : Styles)
    (identity : Identity)
    (kind : String)
    (style : Js Props)
    (changed focused : Bool) : ReactM (Js Props) := do
  let props ← Js.Object.empty
  Js.Object.set props styles.strings.keys.style style
  let classes := if focused then
    if changed then "vir-verso-block vir-verso-block-changed vir-verso-block-focused"
    else "vir-verso-block vir-verso-block-focused"
  else if changed then "vir-verso-block vir-verso-block-changed" else "vir-verso-block"
  Js.Object.set props styles.strings.keys.key (← JsValue.ofString identity.reactKey)
  Js.Object.set props styles.strings.keys.className (← JsValue.ofString classes)
  Js.Object.set props styles.strings.keys.dataVersoBlock (← JsValue.ofString identity.debugPath)
  Js.Object.set props styles.strings.keys.dataVersoRenderId (← JsValue.ofString identity.friendlyId)
  Js.Object.set props styles.strings.keys.dataVersoIdentityOrigin (identity.origin.jsLabel styles.strings)
  Js.Object.set props styles.strings.keys.dataVersoKind (← JsValue.ofString kind)
  Js.Object.set props styles.strings.keys.title (← JsValue.ofString s!"render path: {identity.debugPath}\nidentity: {identity.friendlyId} ({identity.origin.label})")
  if changed then Js.Object.set props styles.strings.keys.dataVersoChange styles.strings.values.changed
  if focused then Js.Object.set props styles.strings.keys.dataVersoFocus styles.strings.values.cursor
  pure props

private def listItemProps
    (styles : Styles)
    (key path kind : String)
    (style : Js Props)
    (focused : Bool) : ReactM (Js Props) := do
  let props ← Js.Object.empty
  Js.Object.set props styles.strings.keys.style style
  Js.Object.set props styles.strings.keys.key (← JsValue.ofString key)
  Js.Object.set props styles.strings.keys.className (← JsValue.ofString (if focused then "vir-verso-list-item vir-verso-block-focused" else "vir-verso-list-item"))
  Js.Object.set props styles.strings.keys.dataVersoListItem (← JsValue.ofString path)
  Js.Object.set props styles.strings.keys.dataVersoKind (← JsValue.ofString kind)
  Js.Object.set props styles.strings.keys.title (← JsValue.ofString s!"source list item: {path}")
  if focused then Js.Object.set props styles.strings.keys.dataVersoFocus styles.strings.values.cursor
  pure props

/-- Source-preserving math node with a sibling-local React key;
caller attributes override style/class defaults. Key/mode and a component's
source are reserved; caller native values are borrowed and never mutated. -/
def renderMath
    (styles : Styles)
    (key : String)
    (mode : Lean.Doc.MathMode)
    (source : String)
    (attributes : Array Attribute := #[])
    (component? : Option (FunctionComponent Props) := none) : ReactM (Lean.Vir.Js Node) := do
  let modeValue : Js String := match mode with
    | Lean.Doc.MathMode.inline => styles.strings.values.inline
    | Lean.Doc.MathMode.display => styles.strings.values.display
  let classValue : Js String := match mode with
    | Lean.Doc.MathMode.inline => styles.strings.values.mathInlineClass
    | Lean.Doc.MathMode.display => styles.strings.values.mathDisplayClass
  let style : Js Props := match mode with
    | Lean.Doc.MathMode.inline => styles.mathInline
    | Lean.Doc.MathMode.display => styles.mathDisplay
  let props ← Js.Object.empty
  Js.Object.set props styles.strings.keys.style style
  Js.Object.set props styles.strings.keys.className classValue
  applyAttributes props attributes
  Js.Object.set props styles.strings.keys.key (← JsValue.ofString key)
  Js.Object.set props styles.strings.keys.dataVersoMathMode modeValue
  if let some component := component? then
    Js.Object.set props styles.strings.keys.source (← JsValue.ofString source)
    return ← Node.functionComponent component props (← js#[])
  return ← <code @props={props}>{Lean.Vir.React.Node.text (← JsValue.ofString source)}</code>

private partial def renderInline (styles : Styles) (renderers : Renderers g)
    (key : String) : _root_.Verso.Doc.Inline g → ReactM (Lean.Vir.Js Node)
  | .text value | .linebreak value => do Node.text (← JsValue.ofString value)
  | .code value => do
      let style := styles.inlineCode
      let props ← Js.Object.empty
      Js.Object.set props styles.strings.keys.style style
      Js.Object.set props styles.strings.keys.key (← JsValue.ofString key)
      return ← <code @props={props}>{Lean.Vir.React.Node.text (← JsValue.ofString value)}</code>
  | .math mode value => renderMath styles key mode value #[] renderers.mathComponent?
  | .emph content => do
      let children ← renderInlines styles renderers content
      return ← <em key={← JsValue.ofString key}>{Js.Array.ofArray children}</em>
  | .bold content => do
      let children ← renderInlines styles renderers content
      return ← <strong key={← JsValue.ofString key}>{Js.Array.ofArray children}</strong>
  | .link content destination => do
      let children ← renderInlines styles renderers content
      return ← <a key={← JsValue.ofString key} href={← JsValue.ofString destination}>{Js.Array.ofArray children}</a>
  | .footnote name content => do
      let label ← Node.text (← JsValue.ofString s!"[{name}]")
      let label ← <sup key="structural:label">{pure label}</sup>
      let children ← renderInlines styles renderers content
      -- Footnotes are inline values: details/summary would make a paragraph
      -- invalid and cause the HTML parser to relocate its children during SSR.
      return ← <span key={← JsValue.ofString key} className="vir-verso-footnote" role="note">
        {pure label}<span key="structural:body">{Js.Array.ofArray children}</span>
      </span>
  | .image alt destination => do return ← <img key={← JsValue.ofString key} src={← JsValue.ofString destination} alt={← JsValue.ofString alt}/>
  | .concat content => do
      let props ← Js.Object.empty
      Js.Object.set props styles.strings.keys.key (← JsValue.ofString key)
      Node.fragment props (← Js.Array.ofArray (← renderInlines styles renderers content))
  | .other extension content => do
      match ← renderers.renderInline? key extension (fun _ => renderInlines styles renderers content) with
      | some rendered => pure rendered
      | none =>
          let style := styles.inlineCode
          let props ← Js.Object.empty
          Js.Object.set props styles.strings.keys.style style
          Js.Object.set props styles.strings.keys.key styles.strings.values.structuralExtension
          Js.Object.set props styles.strings.keys.className styles.strings.values.unsupportedExtensionClass
          Js.Object.set props styles.strings.keys.dataVersoExtension (← JsValue.ofString (renderers.inlineName extension))
          let marker ← <code @props={props}>{Lean.Vir.React.Node.text (← JsValue.ofString s!"[inline extension: {renderers.inlineName extension}]")}</code>
          let fragmentProps ← Js.Object.empty
          Js.Object.set fragmentProps styles.strings.keys.key (← JsValue.ofString key)
          Node.fragment fragmentProps
            (← Js.Array.ofArray (#[marker] ++ (← renderInlines styles renderers content)))

where
  renderInlines (styles : Styles) (renderers : Renderers g)
      (content : Array (_root_.Verso.Doc.Inline g)) : ReactM (Array (Lean.Vir.Js Node)) :=
    content.mapIdxM fun index inline => renderInline styles renderers s!"inline:{index}" inline

private partial def renderInlines (styles : Styles) (renderers : Renderers g)
    (content : Array (_root_.Verso.Doc.Inline g)) : ReactM (Array (Lean.Vir.Js Node)) :=
  content.mapIdxM fun index inline => renderInline styles renderers s!"inline:{index}" inline

private def headingNode
    (styles : Styles)
    (identity : Identity)
    (level : Nat)
    (content : Array (Lean.Vir.Js Node))
    (changed focused : Bool)
    (header? : Option HeaderRenderer := none) : ReactM (Lean.Vir.Js Node) := do
  let props ← blockProps styles identity "heading" (styles.heading) changed focused
  if let some header := header? then return ← header (min level 6) props content
  match level with
  | 1 => <h1 @props={props}>{Js.Array.ofArray content}</h1>
  | 2 => <h2 @props={props}>{Js.Array.ofArray content}</h2>
  | 3 => <h3 @props={props}>{Js.Array.ofArray content}</h3>
  | 4 => <h4 @props={props}>{Js.Array.ofArray content}</h4>
  | 5 => <h5 @props={props}>{Js.Array.ofArray content}</h5>
  | _ => <h6 @props={props}>{Js.Array.ofArray content}</h6>

private partial def renderBlock (styles : Styles) (renderers : Renderers g) (fingerprint : Fingerprint.Value g → Option String)
    (changedIds : Array String)
    (focus : Option String)
    (identity : Identity) : _root_.Verso.Doc.Block g → ReactM (Lean.Vir.Js Node)
  | .para content => do
      let props ← blockProps styles identity "paragraph" (styles.paragraph) (changedIds.contains identity.debugPath) (focus == some identity.debugPath)
      let children ← renderInlines styles renderers content
      return ← <p @props={props}>{Js.Array.ofArray children}</p>
  | .code source => do
      let text ← Node.text (← JsValue.ofString source)
      let codeProps ← Js.Object.empty
      Js.Object.set codeProps styles.strings.keys.dataLanguage styles.strings.values.empty
      let code ← <code @props={codeProps}>{pure text}</code>
      let props ← blockProps styles identity "code" (styles.codeBlock) (changedIds.contains identity.debugPath) (focus == some identity.debugPath)
      return ← <pre @props={props}>{pure code}</pre>
  | .ul items => do
      let props ← blockProps styles identity "unordered-list" (styles.list) (changedIds.contains identity.debugPath) (focus == some identity.debugPath)
      let children ← items.mapIdxM fun index item => renderListItem styles renderers fingerprint changedIds focus identity.semanticKey s!"item:{index}" s!"{identity.debugPath}-item-{index}" item
      return ← <ul @props={props}>{Js.Array.ofArray children}</ul>
  | .ol start items => do
      let props ← blockProps styles identity "ordered-list" (styles.list) (changedIds.contains identity.debugPath) (focus == some identity.debugPath)
      Js.Object.set props styles.strings.keys.start (← JsValue.ofString (toString (max start 0)))
      let children ← items.mapIdxM fun index item => renderListItem styles renderers fingerprint changedIds focus identity.semanticKey s!"item:{index}" s!"{identity.debugPath}-item-{index}" item
      return ← <ol @props={props}>{Js.Array.ofArray children}</ol>
  | .dl items => do
      let children ← items.mapIdxM fun index item =>
        renderDescItem styles renderers fingerprint changedIds focus identity.semanticKey s!"item:{index}" s!"{identity.debugPath}-item-{index}" item
      let props ← blockProps styles identity "description-list" (styles.descriptionList) (changedIds.contains identity.debugPath) (focus == some identity.debugPath)
      return ← <dl @props={props}>{Js.Array.ofArray children.flatten}</dl>
  | .blockquote content => do
      let props ← blockProps styles identity "blockquote" (styles.blockquote) (changedIds.contains identity.debugPath) (focus == some identity.debugPath)
      let children ← renderBlocks styles renderers fingerprint changedIds focus identity.semanticKey identity.debugPath content
      return ← <blockquote @props={props}>{Js.Array.ofArray children}</blockquote>
  | .concat content => do
      -- Concatenations are React fragments, not DOM nodes. A source block may
      -- expand to several children; mark those children without adding a wrapper.
      let props ← Js.Object.empty
      Js.Object.set props styles.strings.keys.key (← JsValue.ofString identity.reactKey)
      Node.fragment props
        (← Js.Array.ofArray
          (← renderBlocks styles renderers fingerprint changedIds focus identity.semanticKey identity.debugPath content
            (focusChildren := focus == some identity.debugPath)))
  | .other extension content => do
      let changed := changedIds.contains identity.debugPath
      let focused := focus == some identity.debugPath
      let attributes := fun kind style => blockProps styles identity kind style changed focused
      let children := fun _ : Unit =>
        renderBlocks styles renderers fingerprint changedIds focus identity.semanticKey identity.debugPath content
      match ← renderers.renderBlock? identity.reactKey attributes extension children with
      | some rendered => pure rendered
      | none =>
          let markerStyle := styles.inlineCode
          let markerProps ← Js.Object.empty
          Js.Object.set markerProps styles.strings.keys.style markerStyle
          let marker ← <code @props={markerProps}>{Lean.Vir.React.Node.text (← JsValue.ofString s!"[block extension: {renderers.blockName extension}]")}</code>
          let props ← attributes "unsupported-extension" (styles.unsupported)
          Js.Object.set props styles.strings.keys.dataVersoExtension (← JsValue.ofString (renderers.blockName extension))
          let childNodes ← children ()
          return ← <div @props={props}>{pure marker}{Js.Array.ofArray childNodes}</div>

where
  renderListItem (styles : Styles) (renderers : Renderers g) (fingerprint : Fingerprint.Value g → Option String)
      (changedIds : Array String)
      (focus : Option String)
      (parentSemanticKey key path : String)
      (item : Lean.Doc.ListItem (_root_.Verso.Doc.Block g)) :
      ReactM (Lean.Vir.Js Node) := do
    let .mk content := item
    let props ← listItemProps styles key path "list-item" (styles.listItem) (focus == some path)
    let children ← renderBlocks styles renderers fingerprint changedIds focus s!"{parentSemanticKey}/{key}" path content
    return ← <li @props={props}>{Js.Array.ofArray children}</li>

  renderDescItem (styles : Styles) (renderers : Renderers g) (fingerprint : Fingerprint.Value g → Option String)
      (changedIds : Array String)
      (focus : Option String)
      (parentSemanticKey key path : String)
      (item : Lean.Doc.DescItem
        (_root_.Verso.Doc.Inline g) (_root_.Verso.Doc.Block g)) :
      ReactM (Array (Lean.Vir.Js Node)) := do
    let .mk term description := item
    let termProps ← listItemProps styles s!"{key}:term" s!"{path}-term" "description-term" (styles.descriptionTerm) (focus == some path)
    let termChildren ← renderInlines styles renderers term
    let termNode ← <dt @props={termProps}>{Js.Array.ofArray termChildren}</dt>
    let descriptionProps ← listItemProps styles s!"{key}:description" s!"{path}-description" "description-value" (styles.descriptionValue) (focus == some path)
    let descriptionChildren ← renderBlocks styles renderers fingerprint changedIds focus s!"{parentSemanticKey}/{key}/description" s!"{path}-description" description
    let descriptionNode ← <dd @props={descriptionProps}>{Js.Array.ofArray descriptionChildren}</dd>
    pure #[termNode, descriptionNode]

  renderBlocks (styles : Styles) (renderers : Renderers g) (fingerprint : Fingerprint.Value g → Option String)
      (changedIds : Array String)
      (focus : Option String)
      (parentSemanticKey debugParent : String)
      (content : Array (_root_.Verso.Doc.Block g))
      (focusChildren : Bool := false) :
      ReactM (Array (Lean.Vir.Js Node)) := do
    let identities := blockIdentities renderers parentSemanticKey debugParent content fingerprint
    content.mapIdxM fun index block =>
      let identity := identities[index]!
      renderBlock styles renderers fingerprint changedIds
        (if focusChildren then some identity.debugPath else focus) identity block

private partial def renderPart (styles : Styles) (renderers : Renderers g) (fingerprint : Fingerprint.Value g → Option String)
    (changedIds : Array String)
    (focus : Option String)
    (identity : Identity)
    (level : Nat)
    (part : _root_.Verso.Doc.Part g)
    (header? : Option HeaderRenderer := none) : ReactM (Lean.Vir.Js Node) := do
  if let some metadata := part.metadata then
    let renderDefault := fun header? =>
      renderPart styles renderers fingerprint changedIds focus identity level part.withoutMetadata header?
    if let some rendered ← renderers.renderPart? identity.reactKey metadata part.withoutMetadata renderDefault then
      return rendered
  let headingIdentity := headingIdentity identity
  let heading ← headingNode styles headingIdentity level
    (← renderInlines styles renderers part.title)
    (changedIds.contains headingIdentity.debugPath) (focus == some headingIdentity.debugPath) header?
  let identities := blockIdentities renderers identity.semanticKey identity.debugPath part.content fingerprint
  let content ← part.content.mapIdxM fun index block =>
    renderBlock styles renderers fingerprint changedIds focus identities[index]! block
  let partIdentities := partIdentities renderers identity.semanticKey identity.debugPath part.subParts fingerprint
  let subParts ← part.subParts.mapIdxM fun index child =>
    renderPart styles renderers fingerprint changedIds focus partIdentities[index]! (level + 1) child
  let style := styles.part
  let props ← Js.Object.empty
  Js.Object.set props styles.strings.keys.style style
  Js.Object.set props styles.strings.keys.key (← JsValue.ofString identity.reactKey)
  Js.Object.set props styles.strings.keys.className styles.strings.values.partClass
  Js.Object.set props styles.strings.keys.dataVersoPart (← JsValue.ofString identity.debugPath)
  Js.Object.set props styles.strings.keys.dataVersoRenderId (← JsValue.ofString identity.friendlyId)
  Js.Object.set props styles.strings.keys.dataVersoIdentityOrigin (identity.origin.jsLabel styles.strings)
  Js.Object.set props styles.strings.keys.title (← JsValue.ofString s!"render path: {identity.debugPath}\nidentity: {identity.friendlyId} ({identity.origin.label})")
  return ← <section @props={props}>{pure heading}{Js.Array.ofArray content}{Js.Array.ofArray subParts}</section>

/-- Options computed by the stateful component before constructing the Verso VDOM. -/
structure Options (g : Doc.Genre) where
  changedIds : Array String := #[]
  focus : Option String := none
  /-- Later attributes override style/class defaults, never mutate their values.
  Cast's diagnostic data attributes are reserved and written last. -/
  attributes : Array Attribute := #[]
  /-- Override the adapter identity policy, e.g. with a prepared state key. -/
  fingerprint? : Option (Fingerprint.Value g → Option String) := none

/-- Construct a native React subtree for any Verso genre. No JSON or equality instances are required. -/
def render (styles : Styles) (input : Doc.Part g) (options : Options g := {})
    (renderers : Renderers g := {}) : ReactM (Lean.Vir.Js Node) := do
  let fingerprint := options.fingerprint?.getD renderers.fingerprint
  let rootPart ← renderPart styles renderers fingerprint options.changedIds options.focus rootIdentity 1 input
  let props ← Js.Object.empty
  Js.Object.set props styles.strings.keys.style styles.document
  Js.Object.set props styles.strings.keys.className styles.strings.values.documentClass
  applyAttributes props options.attributes
  Js.Object.set props styles.strings.keys.dataVersoChangedBlockCount (← JsValue.ofString (toString options.changedIds.size))
  Js.Object.set props styles.strings.keys.dataVersoFocusBlock (← JsValue.ofString (options.focus.getD ""))
  return ← <article @props={props}>{pure rootPart}</article>

#guard
  let explicit := ({
    explicitId? := some "author"
    versoId? := some "verso"
    fingerprint? := some "content"
  } : IdentityHints).resolve "block" 0 "part-root-block-0"
  let verso := ({
    versoId? := some "verso"
    fingerprint? := some "content"
  } : IdentityHints).resolve "block" 0 "part-root-block-0"
  let fingerprint := ({ fingerprint? := some "content" } : IdentityHints).resolve
    "block" 0 "part-root-block-0"
  let positional := ({} : IdentityHints).resolve "block" 0 "part-root-block-0"
  explicit.origin == .explicit && explicit.reactKey == "explicit:author" &&
  verso.origin == .verso && verso.reactKey == "verso:verso" &&
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

end VersoCast.Renderer
