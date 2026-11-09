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
structure Page where
  «meta» : DocumentMeta
  env : Environment
  options : Options
  document : Verso.Doc.Part Verso.Genre.Manual
  hasErrors : Bool
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

/-- Reject cancellation by either an explicit request or an intervening edit. -/
def checkCancelled : RequestM Unit := do
  RequestM.checkCancelled
  if ← (← readThe RequestContext).cancelTk.wasCancelledByEdit then
    throw .fileChanged

/-- Validate a captured page against this request's URI/version.
This is relative to the request context, not a lease.
Call before/after costly work. Lean's session-scoped RPC reference decoder owns
worker/session retirement; no scheduler identity or client-supplied stamp is used. -/
def requireMatchingVersion (page : Page) : RequestM Unit := do
  checkCancelled
  let current ← RequestM.readDoc
  unless page.meta.uri == current.meta.uri && page.meta.version == current.meta.version do
    throw .fileChanged

/-- Select and evaluate one final, checked page. Return its
reported diagnostics as facts, without deciding whether an entry may execute.
Diagnostic reporting is awaited so hasErrors is complete for this snapshot.
No frontend restart, traversal, website generation or saved-IR lookup occurs. -/
def withPage (consume : Page → RequestM α)
    (expectedVersion? : Option Nat := none) :
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
          let options := snap.cmdState.scopes.head!.opts
          let part ← match evalDocument snap.env options (Verso.Doc.docName doc.meta.mod) with
            | .ok part => pure part
            | .error message => throw ⟨.invalidParams, message⟩
          let page : Page := {
            «meta» := doc.meta
            env := snap.env
            options
            document := part
            hasErrors := errors }
          requireMatchingVersion page
          let result ← consume page
          requireMatchingVersion page
          pure result)

/-- An execution consumer may choose whole-page error-free admission. Preview
availability is independent: a recovered document can still be displayed. -/
def requireErrorFree (page : Page) : RequestM Unit := do
  requireMatchingVersion page
  if page.hasErrors then
    throw ⟨.invalidParams, "The selected Manual page has errors"⟩

/-- Optional version expectation for a whole-page request, independent of cursor. -/
structure DocumentParams where
  expectedVersion? : Option Nat := none
  deriving ToJson, FromJson

/-- Keep this envelope on the ordinary RPC path: its reference is opaque native
RPC data, not part of the document String's JSON schema. -/
structure DocumentReply where
  uri : Lsp.DocumentUri
  version : Nat
  snapshotRef : WithRpcRef Page
  documentJson : String
  hasErrors : Bool
  deriving RpcEncodable

/-- A complete checked Manual page and a reference for consumer RPCs.
This initial API deliberately uses Verso's existing JSON schema. -/
@[server_rpc_method]
def document (params : DocumentParams) : RequestM (RequestTask DocumentReply) :=
  withPage (expectedVersion? := params.expectedVersion?) fun page => do
    pure {
      uri := page.meta.uri
      version := page.meta.version
      snapshotRef := ← WithRpcRef.mk page
      documentJson := (toJson page.document).compress
      hasErrors := page.hasErrors }

end VersoCast.Manual.Preview.Server
