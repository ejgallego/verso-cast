/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Manual
public import Vir.Infoview.Client.Types
public meta import VersoCast.Manual.Preview.Server

public section
namespace VersoCast.Manual.Preview
open Lean.Vir Lean.Vir.React
open scoped Lean.Vir.Js

/-- Immutable provenance of a rendered page, not permission to execute it.
Keep snapshotRef on the ordinary RPC path and use only its captured session. -/
structure PageInfo where
  session : Js Infoview.RpcSession
  uri : String
  version : Nat
  snapshotRef : Js.Any
  hasErrors : Bool

/-- Opaque to JavaScript; the native request hook retains this through a LeanRef. -/
structure Snapshot where
  document : Verso.Doc.Part Verso.Genre.Manual
  page : PageInfo

/-- Stable extension factories run once. The returned function receives the
displayed page and a derived matchesSelection flag, never a mutable freshness
claim. Stateful extensions remain ordinary React components. -/
structure Config where
  createRenderers : Renderer.Styles →
    RuntimeM (PageInfo → Bool → Renderer.Renderers Verso.Genre.Manual) := fun styles => do
      let handlers ← Manual.createRenderers styles
      pure fun _ _ => handlers

/-- Native React composes these with the public usePage/renderPage helpers.
decode returns an explicit parse result; unexpected runtime failures propagate.
view expects data, matchesSelection and debug props supplied by renderPage. -/
structure Bridge where
  decode : Js.Function2 (Js Infoview.RpcSession) Js.Object Js.Object
  view : FunctionComponent (Props.WithData Snapshot)

/-- Prepare the Lean decoder and renderer once per runtime. Request ownership and
UI chrome stay in the native host, so cleanup does not need a healthy interpreter. -/
def create (config : Config := {}) : RuntimeM Bridge := do
  let styles ← Renderer.Styles.create
  let renderers ← config.createRenderers styles
  let decode ← Js.Function.ofLean2 fun (session : Js Infoview.RpcSession) (reply : Js.Object) => do
    let encoded ← JsValue.toString (← Js.String.fromAny (← Js.Object.get reply (← js#"documentJson")))
    match Lean.Json.parse encoded >>= Lean.fromJson? with
    | .error error =>
      js%{ "ok" := (← JsValue.ofBool false), "error" := (← JsValue.ofString error) }
    | .ok document =>
      let uri ← JsValue.toString (← Js.String.fromAny (← Js.Object.get reply (← js#"uri")))
      let version ← JsValue.toFloat (← Js.Number.fromAny (← Js.Object.get reply (← js#"version")))
      let hasErrors ← JsValue.toBool (← Js.Boolean.fromAny (← Js.Object.get reply (← js#"hasErrors")))
      let page : PageInfo := {
        session, uri, version := version.toUInt64.toNat
        snapshotRef := ← Js.Object.get reply (← js#"snapshotRef")
        hasErrors }
      let value ← LeanRef.toJSL ({ document, page } : Snapshot)
      js%{ "ok" := (← JsValue.ofBool true), "value" := value }
  let view ← FunctionComponent.ofLean fun props => do
    let snapshot : Snapshot ← LeanRef.fromJSL (← Props.WithData.data props)
    let matchesSelection ← JsValue.toBool (← Js.Boolean.fromAny
      (← Js.Object.get props (← js#"matchesSelection")))
    let debug ← JsValue.toBool (← Js.Boolean.fromAny (← Js.Object.get props (← js#"debug")))
    Renderer.render styles snapshot.document { debug }
      (renderers := renderers snapshot.page matchesSelection)
  return { decode, view }

end VersoCast.Manual.Preview
