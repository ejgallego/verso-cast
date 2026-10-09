module
public import VersoCast

public def Consumer.renderDocument (styles : VersoCast.Renderer.Styles)
    (document : Verso.Doc.Part Verso.Genre.Manual) :
    Lean.Vir.React.ReactM (Lean.Vir.Js Lean.Vir.React.Node) :=
  VersoCast.Renderer.render styles document
