module
public import VersoCast.Manual
public import VersoCast.Blog
public import VersoCast.Manual.Preview

public section
namespace Consumer
open Verso VersoCast Lean.Vir Lean.Vir.React

-- Public factories compile in a separate package without internal Cast imports.
-- They are browser components: keep this module out of the native executable's
-- import closure, which would otherwise request native C for VIR's JS bindings.
def createManualView (document : Doc.Part Genre.Manual) :
    RuntimeM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let handlers ← Manual.createRenderers styles
  FunctionComponent.ofLean fun _ => Renderer.render styles document (renderers := handlers)

def createPageView (document : Doc.Part Genre.Blog.Page) :
    RuntimeM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let handlers ← Blog.createRenderers Genre.Blog.Page styles
  FunctionComponent.ofLean fun _ => Renderer.render styles document (renderers := handlers)

def createPostView (document : Doc.Part Genre.Blog.Post) :
    RuntimeM (FunctionComponent Props) := do
  let styles ← Renderer.Styles.create
  let handlers ← Blog.createRenderers Genre.Blog.Post styles
  FunctionComponent.ofLean fun _ => Renderer.render styles document (renderers := handlers)

-- Preview and snapshot authority are optional public imports, not test internals.
def createCheckedManualPreview := Manual.Preview.create

meta def validateCheckedPage
    (ref : Lean.Server.WithRpcRef Manual.Preview.Server.CheckedPage) : Lean.Server.RequestM Nat := do
  Manual.Preview.Server.requireCurrent ref.val
  pure ref.val.meta.version

end Consumer
