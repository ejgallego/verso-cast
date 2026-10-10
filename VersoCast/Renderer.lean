/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

module

public import VersoCast.Renderer.Config
public import Vir.ProofWidgets.Jsx
public import VersoCast.RenderPath
public meta import VersoCast.RenderPath

/-! Genre-agnostic identity/change helpers and document-to-React traversal.
The client-facing hooks and styles are re-exported from `Renderer.Config`. -/
public section

namespace VersoCast.Renderer

open Lean.Vir
open Lean.Vir.React
open Lean.Doc.Syntax
open _root_.Verso
open Verso.Doc

variable {g : Doc.Genre}
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def applyAttributes (props : Js Props) (attributes : Array Attribute) : ReactM Unit := do
  for field in attributes do
    Js.Construction.field props field.name field.value

private inductive IdentityOrigin where
  | structural
  | explicit
  | fingerprint
  | positional
  deriving BEq, Inhabited

private def IdentityOrigin.label : IdentityOrigin → String
  | .structural => "structural"
  | .explicit => "explicit"
  | .fingerprint => "fingerprint"
  | .positional => "positional"

private def IdentityOrigin.jsLabel (strings : JsStrings.Fixed) : IdentityOrigin → Js String
  | .structural => strings.values.structural
  | .explicit => strings.values.explicit
  | .fingerprint => strings.values.fingerprint
  | .positional => strings.values.positional

/--
Identity sources are ordered from strongest to weakest. Content-keyed blocks
reach the fingerprint branch; extension metadata can provide stronger semantic
identities where the application owns their meaning.
-/
private structure IdentityHints where
  explicitId? : Option String := none
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

-- The segment is a fixed internal role; the key is opaque client data and may
-- contain separators. This encoding is separate from React keys and navigation.
private def semanticChild (parent segment key : String) : String :=
  s!"{parent}/{segment}/{key.length}:{key}"

private def IdentityHints.resolve
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
      semanticKey := semanticChild parentSemanticKey segment reactKey
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
  semanticKey := semanticChild part.semanticKey "heading" ""
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

private def blockProps
    (styles : Styles)
    (debug : Bool)
    (identity : Identity)
    (kind : String)
    (style : Js Props)
    (changed focused : Bool)
    (decorate : Option (Js Props → ReactM Unit) := none) : ReactM (Js Props) := do
  let props ← Js.Object.empty
  Js.Object.set props styles.strings.keys.style style
  let classes := if focused then
    if changed then "vir-verso-block vir-verso-block-changed vir-verso-block-focused"
    else "vir-verso-block vir-verso-block-focused"
  else if changed then "vir-verso-block vir-verso-block-changed" else "vir-verso-block"
  Js.Object.set props styles.strings.keys.className (← JsValue.ofString classes)
  if let some decorate := decorate then decorate props
  Js.Object.set props styles.strings.keys.key (← JsValue.ofString identity.reactKey)
  Js.Object.set props styles.strings.keys.dataVersoBlock (← JsValue.ofString identity.debugPath)
  Js.Object.set props styles.strings.keys.dataVersoKind (← JsValue.ofString kind)
  if debug then
    Js.Object.set props styles.strings.keys.dataVersoRenderId (← JsValue.ofString identity.friendlyId)
    Js.Object.set props styles.strings.keys.dataVersoIdentityOrigin (identity.origin.jsLabel styles.strings)
    Js.Object.set props styles.strings.keys.title (← JsValue.ofString s!"render path: {identity.debugPath}\nidentity: {identity.friendlyId} ({identity.origin.label})")
  if changed then Js.Object.set props styles.strings.keys.dataVersoChange styles.strings.values.changed
  if focused then Js.Object.set props styles.strings.keys.dataVersoFocus styles.strings.values.cursor
  pure props

private def listItemProps
    (styles : Styles)
    (debug : Bool)
    (key path kind : String)
    (style : Js Props)
    (focused : Bool) : ReactM (Js Props) := do
  let props ← Js.Object.empty
  Js.Object.set props styles.strings.keys.style style
  Js.Object.set props styles.strings.keys.key (← JsValue.ofString key)
  Js.Object.set props styles.strings.keys.className (← JsValue.ofString (if focused then "vir-verso-list-item vir-verso-block-focused" else "vir-verso-list-item"))
  Js.Object.set props styles.strings.keys.dataVersoListItem (← JsValue.ofString path)
  Js.Object.set props styles.strings.keys.dataVersoKind (← JsValue.ofString kind)
  if debug then Js.Object.set props styles.strings.keys.title (← JsValue.ofString s!"source list item: {path}")
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

private def renderInlines (styles : Styles) (renderers : Renderers g)
    (content : Array (_root_.Verso.Doc.Inline g)) : ReactM (Array (Lean.Vir.Js Node)) :=
  renderInline.renderInlines styles renderers content

private def headingNode
    (styles : Styles)
    (debug : Bool)
    (identity : Identity)
    (level : Nat)
    (content : Array (Lean.Vir.Js Node))
    (changed focused : Bool)
    (header? : Option HeaderRenderer := none) : ReactM (Lean.Vir.Js Node) := do
  let props ← blockProps styles debug identity "heading" (styles.heading) changed focused
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
    (debug : Bool)
    (decorate : Option (Js Props → ReactM Unit))
    (identity : Identity) : _root_.Verso.Doc.Block g → ReactM (Lean.Vir.Js Node)
  | .para content => do
      let props ← blockProps styles debug identity "paragraph" (styles.paragraph) (changedIds.contains identity.debugPath) (focus == some identity.debugPath) decorate
      let children ← renderInlines styles renderers content
      return ← <p @props={props}>{Js.Array.ofArray children}</p>
  | .code source => do
      let text ← Node.text (← JsValue.ofString source)
      let codeProps ← Js.Object.empty
      Js.Object.set codeProps styles.strings.keys.dataLanguage styles.strings.values.empty
      let code ← <code @props={codeProps}>{pure text}</code>
      let props ← blockProps styles debug identity "code" (styles.codeBlock) (changedIds.contains identity.debugPath) (focus == some identity.debugPath) decorate
      return ← <pre @props={props}>{pure code}</pre>
  | .ul items => do
      let props ← blockProps styles debug identity "unordered-list" (styles.list) (changedIds.contains identity.debugPath) (focus == some identity.debugPath) decorate
      let children ← items.mapIdxM fun index item => renderListItem styles renderers fingerprint changedIds focus debug identity.semanticKey s!"item:{index}" s!"{identity.debugPath}-item-{index}" item
      return ← <ul @props={props}>{Js.Array.ofArray children}</ul>
  | .ol start items => do
      let props ← blockProps styles debug identity "ordered-list" (styles.list) (changedIds.contains identity.debugPath) (focus == some identity.debugPath) decorate
      Js.Object.set props styles.strings.keys.start (← JsValue.ofString (toString start))
      let children ← items.mapIdxM fun index item => renderListItem styles renderers fingerprint changedIds focus debug identity.semanticKey s!"item:{index}" s!"{identity.debugPath}-item-{index}" item
      return ← <ol @props={props}>{Js.Array.ofArray children}</ol>
  | .dl items => do
      let children ← items.mapIdxM fun index item =>
        renderDescItem styles renderers fingerprint changedIds focus debug identity.semanticKey s!"item:{index}" s!"{identity.debugPath}-item-{index}" item
      let props ← blockProps styles debug identity "description-list" (styles.descriptionList) (changedIds.contains identity.debugPath) (focus == some identity.debugPath) decorate
      return ← <dl @props={props}>{Js.Array.ofArray children.flatten}</dl>
  | .blockquote content => do
      let props ← blockProps styles debug identity "blockquote" (styles.blockquote) (changedIds.contains identity.debugPath) (focus == some identity.debugPath) decorate
      let children ← renderBlocks styles renderers fingerprint changedIds focus debug identity.semanticKey identity.debugPath content
      return ← <blockquote @props={props}>{Js.Array.ofArray children}</blockquote>
  | .concat content => do
      -- Concatenations are React fragments, not DOM nodes. A source block may
      -- expand to several children; mark those children without adding a wrapper.
      let props ← Js.Object.empty
      Js.Object.set props styles.strings.keys.key (← JsValue.ofString identity.reactKey)
      Node.fragment props
        (← Js.Array.ofArray
          (← renderBlocks styles renderers fingerprint changedIds focus debug identity.semanticKey identity.debugPath content
            (focusChildren := focus == some identity.debugPath) (decorate := decorate)))
  | .other extension content => do
      let changed := changedIds.contains identity.debugPath
      let focused := focus == some identity.debugPath
      let attributes := fun kind style => blockProps styles debug identity kind style changed focused decorate
      let children : BlockChildren := {
        render := fun _ =>
          renderBlocks styles renderers fingerprint changedIds focus debug identity.semanticKey identity.debugPath content
        renderWith := fun inner =>
          renderBlocks styles renderers fingerprint changedIds focus debug identity.semanticKey identity.debugPath content
            (focusChildren := focused)
            (decorate := some fun props => do
              inner props
              if let some outer := decorate then outer props)
        splitParagraph? := fun _ => do
          let some first := content[0]? | none
          let .para inlines := first | none
          let identities := blockIdentities renderers identity.semanticKey identity.debugPath content fingerprint
          let leading := identities[0]!
          let summary : Unit → ReactM (Js Props × Array (Js Node)) := fun _ => do
            let props ← blockProps styles debug leading "paragraph" styles.paragraph
              (changedIds.contains leading.debugPath) (focus == some leading.debugPath)
            return (props, ← renderInlines styles renderers inlines)
          let body : Unit → ReactM (Array (Js Node)) := fun _ => (content.extract 1 content.size).mapIdxM fun index block =>
            renderBlock styles renderers fingerprint changedIds focus debug none identities[index + 1]! block
          some (summary, body)
        listItems? := fun _ => do
          let #[.ul items] := content | none
          let list := (blockIdentities renderers identity.semanticKey identity.debugPath content fingerprint)[0]!
          some (items.mapIdx fun index item => fun _ : Unit => do
            let key := s!"item:{index}"
            let path := RenderPath.child list.debugPath "item" index
            let props ← listItemProps styles debug key path "list-item" styles.listItem
              (focus == some path || focus == some list.debugPath)
            let nodes ← renderBlocks styles renderers fingerprint changedIds focus debug
              (semanticChild list.semanticKey "item" key) path item.contents
            return (props, nodes)) }
      match ← renderers.renderBlock? identity.reactKey attributes extension children with
      | some rendered => pure rendered
      | none =>
          let markerStyle := styles.inlineCode
          let markerProps ← Js.Object.empty
          Js.Object.set markerProps styles.strings.keys.style markerStyle
          let marker ← <code @props={markerProps}>{Lean.Vir.React.Node.text (← JsValue.ofString s!"[block extension: {renderers.blockName extension}]")}</code>
          let props ← attributes "unsupported-extension" (styles.unsupported)
          Js.Object.set props styles.strings.keys.dataVersoExtension (← JsValue.ofString (renderers.blockName extension))
          let childNodes ← children.render ()
          return ← <div @props={props}>{pure marker}{Js.Array.ofArray childNodes}</div>

where
  renderListItem (styles : Styles) (renderers : Renderers g) (fingerprint : Fingerprint.Value g → Option String)
      (changedIds : Array String)
      (focus : Option String)
      (debug : Bool)
      (parentSemanticKey key path : String)
      (item : Lean.Doc.ListItem (_root_.Verso.Doc.Block g)) :
      ReactM (Lean.Vir.Js Node) := do
    let .mk content := item
    let props ← listItemProps styles debug key path "list-item" (styles.listItem) (focus == some path)
    let children ← renderBlocks styles renderers fingerprint changedIds focus debug
      (semanticChild parentSemanticKey "item" key) path content
    return ← <li @props={props}>{Js.Array.ofArray children}</li>

  renderDescItem (styles : Styles) (renderers : Renderers g) (fingerprint : Fingerprint.Value g → Option String)
      (changedIds : Array String)
      (focus : Option String)
      (debug : Bool)
      (parentSemanticKey key path : String)
      (item : Lean.Doc.DescItem
        (_root_.Verso.Doc.Inline g) (_root_.Verso.Doc.Block g)) :
      ReactM (Array (Lean.Vir.Js Node)) := do
    let .mk term description := item
    let termPath := s!"{path}-term"
    let descriptionPath := s!"{path}-description"
    -- The shared item address selects both halves. Each exposed DOM address
    -- also selects its own half, just like ordinary block/list-item addresses.
    let termProps ← listItemProps styles debug s!"{key}:term" termPath "description-term" (styles.descriptionTerm)
      (focus == some path || focus == some termPath)
    let termChildren ← renderInlines styles renderers term
    let termNode ← <dt @props={termProps}>{Js.Array.ofArray termChildren}</dt>
    let descriptionProps ← listItemProps styles debug s!"{key}:description" descriptionPath "description-value" (styles.descriptionValue)
      (focus == some path || focus == some descriptionPath)
    let descriptionChildren ← renderBlocks styles renderers fingerprint changedIds focus debug
      (semanticChild parentSemanticKey "description" key) descriptionPath description
    let descriptionNode ← <dd @props={descriptionProps}>{Js.Array.ofArray descriptionChildren}</dd>
    pure #[termNode, descriptionNode]

  renderBlocks (styles : Styles) (renderers : Renderers g) (fingerprint : Fingerprint.Value g → Option String)
      (changedIds : Array String)
      (focus : Option String)
      (debug : Bool)
      (parentSemanticKey debugParent : String)
      (content : Array (_root_.Verso.Doc.Block g))
      (focusChildren : Bool := false)
      (decorate : Option (Js Props → ReactM Unit) := none) :
      ReactM (Array (Lean.Vir.Js Node)) := do
    let identities := blockIdentities renderers parentSemanticKey debugParent content fingerprint
    content.mapIdxM fun index block =>
      let identity := identities[index]!
      renderBlock styles renderers fingerprint changedIds
        (if focusChildren then some identity.debugPath else focus) debug decorate identity block

private partial def renderPart (styles : Styles) (renderers : Renderers g) (fingerprint : Fingerprint.Value g → Option String)
    (changedIds : Array String)
    (focus : Option String)
    (debug : Bool)
    (identity : Identity)
    (level : Nat)
    (part : _root_.Verso.Doc.Part g)
    (header? : Option HeaderRenderer := none) : ReactM (Lean.Vir.Js Node) := do
  if let some metadata := part.metadata then
    let renderDefault := fun header? =>
      renderPart styles renderers fingerprint changedIds focus debug identity level part.withoutMetadata header?
    if let some rendered ← renderers.renderPart? identity.reactKey metadata part.withoutMetadata renderDefault then
      return rendered
  let headingIdentity := headingIdentity identity
  let heading ← headingNode styles debug headingIdentity level
    (← renderInlines styles renderers part.title)
    (changedIds.contains headingIdentity.debugPath) (focus == some headingIdentity.debugPath) header?
  let identities := blockIdentities renderers identity.semanticKey identity.debugPath part.content fingerprint
  let content ← part.content.mapIdxM fun index block =>
    renderBlock styles renderers fingerprint changedIds focus debug none identities[index]! block
  let partIdentities := partIdentities renderers identity.semanticKey identity.debugPath part.subParts fingerprint
  let subParts ← part.subParts.mapIdxM fun index child =>
    renderPart styles renderers fingerprint changedIds focus debug partIdentities[index]! (level + 1) child
  let style := styles.part
  let props ← Js.Object.empty
  Js.Object.set props styles.strings.keys.style style
  Js.Object.set props styles.strings.keys.key (← JsValue.ofString identity.reactKey)
  Js.Object.set props styles.strings.keys.className styles.strings.values.partClass
  Js.Object.set props styles.strings.keys.dataVersoPart (← JsValue.ofString identity.debugPath)
  if debug then
    Js.Object.set props styles.strings.keys.dataVersoRenderId (← JsValue.ofString identity.friendlyId)
    Js.Object.set props styles.strings.keys.dataVersoIdentityOrigin (identity.origin.jsLabel styles.strings)
    Js.Object.set props styles.strings.keys.title (← JsValue.ofString s!"render path: {identity.debugPath}\nidentity: {identity.friendlyId} ({identity.origin.label})")
  return ← <section @props={props}>{pure heading}{Js.Array.ofArray content}{Js.Array.ofArray subParts}</section>

/-- Construct a native React subtree for any Verso genre. No JSON or equality instances are required. -/
def render (styles : Styles) (input : Doc.Part g) (options : Options g := {})
    (renderers : Renderers g := {}) : ReactM (Lean.Vir.Js Node) := do
  let fingerprint := options.fingerprint?.getD renderers.fingerprint
  let rootPart ← renderPart styles renderers fingerprint options.changedIds options.focus options.debug rootIdentity 1 input
  let props ← Js.Object.empty
  Js.Object.set props styles.strings.keys.style styles.document
  Js.Object.set props styles.strings.keys.className styles.strings.values.documentClass
  applyAttributes props options.attributes
  if options.debug then
    Js.Object.set props styles.strings.keys.dataVersoChangedBlockCount (← JsValue.ofString (toString options.changedIds.size))
    Js.Object.set props styles.strings.keys.dataVersoFocusBlock (← JsValue.ofString (options.focus.getD ""))
  return ← <article @props={props}>{pure rootPart}</article>

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

end VersoCast.Renderer
