/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public meta import VersoManual.Basic
public meta import Verso.Doc.Name
public meta import Lean.Server.Rpc.RequestHandling

public section
namespace CastManualPreview.Server
open Lean Server

-- The document is runtime code. Check its complete type before crossing staging.
private meta unsafe def evalPartUnsafe (env : Environment) (opts : Options)
    (name : Name) : Except String (Verso.Doc.Part Verso.Genre.Manual) := do
  let some decl := env.find? name | throw "This module has no Verso document"
  unless decl.type == mkApp (mkConst ``Verso.Doc.VersoDoc) (mkConst ``Verso.Genre.Manual) do
    throw "This document does not use the Manual genre"
  let doc ← env.evalConst (Verso.Doc.VersoDoc Verso.Genre.Manual) opts name (checkMeta := false)
  pure doc.toPart

@[implemented_by evalPartUnsafe]
private meta opaque evalPart (env : Environment) (opts : Options)
    (name : Name) : Except String (Verso.Doc.Part Verso.Genre.Manual)

/-- The current page, not the manual's aggregated root or the block under the cursor. -/
@[server_rpc_method]
meta def document (_pos : Lsp.Position) : RequestM (RequestTask String) := do
  let doc ← RequestM.readDoc
  RequestM.bindWaitFindSnap doc (·.isAtEnd)
    (notFoundX := throw ⟨.invalidParams, "The manual page is still elaborating"⟩)
    (x := fun snap => do
      let checked : ServerTask Kernel.Environment := snap.env.checked
      RequestM.mapTaskCostly checked fun _ => do
        RequestM.checkCancelled
        let part ← match evalPart snap.env snap.cmdState.scopes.head!.opts
            (Verso.Doc.docName doc.meta.mod) with
          | .ok part => pure part
          | .error message => throw ⟨.invalidParams, message⟩
        let encoded := (toJson part).compress
        RequestM.checkCancelled
        pure encoded)

end CastManualPreview.Server
