module
public import VersoCast

public def Consumer.renderDocument (styles : VersoCast.Renderer.Styles)
    {genre : Verso.Doc.Genre} (document : Verso.Doc.Part genre) :
    Lean.Vir.React.ReactM (Lean.Vir.Js Lean.Vir.React.Node) :=
  VersoCast.Renderer.render styles document

open VersoCast Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js Lean.Vir.ProofWidgets.Jsx

-- This separate consumer deliberately stays polymorphic in the genre. Requiring
-- equality, hashing or JSON instances in an extension hook would break its build.
-- It imports only the public root, not Cast's fixtures or internal modules.
public def Consumer.createView {genre : Verso.Doc.Genre}
    (document : Verso.Doc.Part genre) : RuntimeM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let attributes := #[Renderer.Attribute.of (← JsValue.ofString "id")
    (← JsValue.ofString "consumer-document")]
  let handlers : Renderer.Renderers genre := {
    renderInline? := fun key _ children => do
      let props ← js%{ "key" := (← JsValue.ofString key) }
      return some (← <mark @props={props}>{Js.Array.ofArray (← children ())}</mark>)
    renderBlock? := fun _ attributes _ children => do
      let props ← attributes "consumer-note" styles.unsupported
      return some (← <aside @props={props}>{Js.Array.ofArray (← children.render ())}</aside>)
    renderPart? := fun _ _ _ renderDefault => do
      let header : Renderer.HeaderRenderer := fun level props title => do
        Node.createElement (← ElementType.tag (← JsValue.ofString s!"h{level}"))
          props (← Js.Array.ofArray title)
      return some (← renderDefault (some header)) }
  let options : Renderer.Options genre := {
    attributes
    focus := some (RenderPath.heading RenderPath.root)
    changedIds := Renderer.renderBlockIds document }
  FunctionComponent.ofLean fun _ => Renderer.render styles document options handlers
