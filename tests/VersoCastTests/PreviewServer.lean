/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoManual
public meta import VersoCast.Manual.Preview.Server

public section

open Verso Genre
open Lean Server VersoCast.Manual.Preview.Server

meta structure PageQuery where
  snapshotRef : WithRpcRef CheckedPage
  deriving RpcEncodable

@[server_rpc_method]
meta def PreviewServerProbe.title (query : PageQuery) : RequestM (RequestTask String) :=
  RequestM.asTask do
    requireCurrent query.snapshotRef.val
    pure query.snapshotRef.val.document.titleString

-- An explicit same-version processing-identity control, not a claim to have
-- triggered an actual imported-module rebuild through the editor.
@[server_rpc_method]
meta def PreviewServerProbe.reprocessed (query : PageQuery) : RequestM (RequestTask String) :=
  RequestM.asTask do
    withReader (fun context => { context with doc := {
        context.doc with reporter := ServerTask.pure () } }) do
      requireCurrent query.snapshotRef.val
      pure "stale authority accepted"

@[server_rpc_method]
meta def PreviewServerProbe.allowErrors (_ : Unit) : RequestM (RequestTask Bool) :=
  withCheckedPage (allowErrors := true) fun page => pure page.hasErrors

#doc (Manual) "Preview original" =>
A checked page.
