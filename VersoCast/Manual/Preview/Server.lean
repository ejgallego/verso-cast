/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public meta import VersoManual.Basic
public meta import Verso.Doc.Name
public meta import Lean.Server.Rpc.RequestHandling

public meta section
namespace VersoCast.Manual.Preview.Server
open Lean Server

/-- A checked page retained only by its ordinary, session-scoped RPC reference.
The environment/options/document all come from the same final snapshot. -/
structure CheckedPage where
  «meta» : DocumentMeta
  env : Environment
  options : Options
  document : Verso.Doc.Part Verso.Genre.Manual
  hasErrors : Bool
  private processing : FileWorker.EditableDocument
  deriving TypeName

private unsafe def evalDocumentUnsafe (env : Environment) (opts : Options)
    (name : Name) : Except String (Verso.Doc.Part Verso.Genre.Manual) := do
  let some decl := env.find? name | throw "This module has no Verso document"
  unless decl.type == mkApp (mkConst ``Verso.Doc.VersoDoc) (mkConst ``Verso.Genre.Manual) do
    throw "This document does not use the Manual genre"
  let doc ← env.evalConst (Verso.Doc.VersoDoc Verso.Genre.Manual) opts name (checkMeta := false)
  pure doc.toPart

@[implemented_by evalDocumentUnsafe]
private opaque evalDocument (env : Environment) (opts : Options)
    (name : Name) : Except String (Verso.Doc.Part Verso.Genre.Manual)

-- Processing identity is deliberately conservative: two separately created
-- processing runs are not interchangeable even for identical URI/version/text.
-- Compare retained server objects only; no pointer or task is sent to clients.
private unsafe def sameProcessingUnsafe (a b : FileWorker.EditableDocument) : Bool :=
  ptrEq a.initSnap b.initSnap && ptrEq a.reporter b.reporter

@[implemented_by sameProcessingUnsafe]
private opaque sameProcessing (a b : FileWorker.EditableDocument) : Bool

/-- Reject cancellation by either an explicit request or an intervening edit. -/
def checkCancelled : RequestM Unit := do
  RequestM.checkCancelled
  if ← (← readThe RequestContext).cancelTk.wasCancelledByEdit then
    throw .fileChanged

/-- Validate a captured page against this request's processing run, including
same-version reprocessing. Call before and after costly consumer work. Session
replacement is additionally enforced by Lean's normal RPC reference decoder. -/
def requireCurrent (page : CheckedPage) : RequestM Unit := do
  checkCancelled
  let current ← RequestM.readDoc
  unless page.meta.uri == current.meta.uri && page.meta.version == current.meta.version &&
      sameProcessing page.processing current do
    throw .fileChanged

/-- Select and evaluate one final, checked page. By default reject pages with
reported errors; allowing them is an explicit preview policy, not Run admission.
No frontend restart, traversal, website generation or saved-IR lookup occurs. -/
def withCheckedPage (consume : CheckedPage → RequestM α)
    (expectedVersion? : Option Nat := none) (allowErrors : Bool := false) :
    RequestM (RequestTask α) := do
  let doc ← RequestM.readDoc
  if let some version := expectedVersion? then
    unless version == doc.meta.version do throw .fileChanged
  RequestM.bindWaitFindSnap doc (·.isAtEnd)
    (notFoundX := throw ⟨.invalidParams, "The Manual page has no final snapshot"⟩)
    (x := fun snap => do
      RequestM.bindTaskCostly doc.reporter fun _ => do
        let checked : ServerTask Kernel.Environment := snap.env.checked
        RequestM.mapTaskCostly checked fun _ => do
          checkCancelled
          let errors := (← doc.collectCurrentDiagnostics).any
            (fun diagnostic => diagnostic.severity? == some .error)
          if errors && !allowErrors then
            throw ⟨.invalidParams, "The Manual page has errors; keeping the last successful preview"⟩
          let options := snap.cmdState.scopes.head!.opts
          let part ← match evalDocument snap.env options (Verso.Doc.docName doc.meta.mod) with
            | .ok part => pure part
            | .error message => throw ⟨.invalidParams, message⟩
          let page : CheckedPage := {
            «meta» := doc.meta
            env := snap.env
            options
            document := part
            hasErrors := errors
            processing := doc }
          let result ← consume page
          requireCurrent page
          pure result)

/-- Optional version expectation for a whole-page request, independent of cursor. -/
structure DocumentParams where
  expectedVersion? : Option Nat := none
  deriving ToJson, FromJson

/-- Keep this envelope on the ordinary RPC path: its reference is opaque native
RPC data, not part of the document String's JSON schema. -/
structure DocumentReply where
  uri : Lsp.DocumentUri
  version : Nat
  snapshotRef : WithRpcRef CheckedPage
  documentJson : String
  deriving RpcEncodable

/-- A complete checked Manual page and its server-side execution authority.
This initial API deliberately uses Verso's existing JSON schema. -/
@[server_rpc_method]
def document (params : DocumentParams) : RequestM (RequestTask DocumentReply) :=
  withCheckedPage (expectedVersion? := params.expectedVersion?) fun page => do
    pure {
      uri := page.meta.uri
      version := page.meta.version
      snapshotRef := ← WithRpcRef.mk page
      documentJson := (toJson page.document).compress }

end VersoCast.Manual.Preview.Server
