/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoManual
public meta import VersoCast.Manual.Preview.Server

public section

open Verso Genre
open Lean Server VersoCast.Manual.Preview.Server

meta structure PageQuery where
  snapshotRef : WithRpcRef Page
  deriving RpcEncodable

@[server_rpc_method]
meta def PreviewServerProbe.title (query : PageQuery) : RequestM (RequestTask String) :=
  RequestM.asTask do
    requireMatchingVersion query.snapshotRef.val
    pure query.snapshotRef.val.document.titleString

@[server_rpc_method]
meta def PreviewServerProbe.admit (query : PageQuery) : RequestM (RequestTask String) :=
  RequestM.asTask do
    requireErrorFree query.snapshotRef.val
    pure query.snapshotRef.val.document.titleString

#doc (Manual) "Preview original" =>
A checked page.
