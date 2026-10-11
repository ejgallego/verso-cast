/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

module

public import VersoCast.Renderer.Changes
import VersoCast.Renderer.Identity
public import Vir.ProofWidgets.Jsx
public import VersoCast.RenderPath
public meta import VersoCast.RenderPath

/-! Genre-agnostic document-to-React traversal.
Pure preparation/comparison helpers are re-exported from `Renderer.Changes`;
client hooks and styles come from `Renderer.Config`. -/
public section

namespace VersoCast.Renderer

open Lean.Vir
open Lean.Vir.React
open Lean.Doc.Syntax
open _root_.Verso
open Verso.Doc
open Internal

variable {g : Doc.Genre}
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

private def applyAttributes (props : Js Props) (attributes : Array Attribute) : ReactM Unit := do
  for field in attributes do
    Js.Construction.field props field.name field.value

private def Internal.IdentityOrigin.jsLabel (strings : JsStrings.Fixed) : IdentityOrigin → Js String
  | .structural => strings.values.structural
  | .explicit => strings.values.explicit
  | .fingerprint => strings.values.fingerprint
  | .positional => strings.values.positional

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

end VersoCast.Renderer
