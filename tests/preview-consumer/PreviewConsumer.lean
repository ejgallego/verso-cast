module
public import VersoCast.Manual.Preview
public meta import VersoCast.Manual.Preview.Server

public section
open Lean.Vir VersoCast.Manual

-- Optional browser/server surface, outside the Node-free core consumer.
def createPreview : RuntimeM Preview.Bridge :=
  Preview.create {
    createRenderers := fun styles => do
      let handlers ← createRenderers styles
      pure fun _ _ => handlers }

public meta section
open Lean.Server Preview.Server

def inspectTitle (page : Page) : RequestM String := do
  requireMatchingVersion page
  pure page.document.titleString

def admitExecution (page : Page) : RequestM Unit := requireErrorFree page
