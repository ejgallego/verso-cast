import React from "react";
import { createRoot } from "react-dom/client";
import { ReferencePage } from "./widget.mjs";
import { peer } from "./infoview-peer.mjs";

export async function checkEditorOwner() {
  const check = (value, message) => { if (!value) throw Error(message); };
  const act = action => React.act(async () => { await action(); });
  const uri = "file:///Page.lean";
  let version = 1;
  const calls = [];
  peer.session = { call(_method, params, options) {
    check(params.expectedVersion === undefined || params.expectedVersion === version, "selected version");
    let resolve;
    const promise = new Promise(accept => { resolve = accept; });
    const reply = { uri, version, snapshotRef: {}, hasErrors: false, documentJson: `page ${version}` };
    calls.push({ signal: options.abortSignal, resolve: () => resolve(reply) });
    return promise;
  } };
  const decode = (_session, reply) => ({ ok: true, value: reply.documentJson });
  const view = ({ data }) => React.createElement("article", null, data);
  const root = createRoot(document.getElementById("app"));
  const render = () => root.render(React.createElement(React.StrictMode, null,
    React.createElement(ReferencePage, { uri, decode, view })));
  const progress = processing => peer.notify("$/lean/fileProgress", { textDocument: { uri }, processing });
  const current = () => document.querySelector("section").dataset.castPreviewCurrent === "true";
  try {
    await act(render);
    await act(() => calls.at(-1).resolve());
    check(calls.length === 1 && current(), "initial checked page");
    await act(() => { progress([{}]); progress([]); });
    check(calls.length === 2 && calls[0].signal.aborted && !current(),
      "batched busy/finished replaces a same-version selection exactly once");
    await act(() => calls.at(-1).resolve());
    check(current(), "same-version preview recovers");
    await act(() => { progress([]); progress([]); render(); });
    check(calls.length === 2 && current(), "idle/cursor-only updates do not refetch");
    await act(() => { progress([{}]); progress([{}]); });
    check(calls.at(-1).signal.aborted && calls.length === 2, "duplicate busy notifications only invalidate");
    await act(() => { progress([]); progress([]); });
    check(calls.length === 3, "one replacement after a processing run");
    const late = calls.at(-1);
    await act(() => {
      version++;
      peer.notify("textDocument/didChange", { textDocument: { uri, version }, contentChanges: [{ text: "edited" }] });
      progress([{}]); progress([]);
    });
    check(late.signal.aborted && calls.length === 4, "edit and batched completion replace once");
    await act(() => late.resolve());
    check(!current(), "late reply cannot revive an aborted selection");
    await act(() => calls.at(-1).resolve());
    check(current(), "edited page accepted");
    await act(() => peer.notify("textDocument/didChange", { textDocument: { uri, version }, contentChanges: [] }));
    check(current() && calls.length === 4, "empty edits ignored like Lean's worker");
    await act(() => peer.notify("stopped"));
    check(calls.at(-1).signal.aborted && !current(), "server stop aborts immediately");
    await act(() => peer.notify("restarted"));
    check(calls.length === 5, "server restart creates a fresh selection");
    await act(() => calls.at(-1).resolve());
    check(current(), "restarted page accepted");
  } finally { await act(() => root.unmount()); }
  check(peer.subscriptions === 0 && calls.at(-1).signal.aborted, "native owner unsubscribes and aborts on unmount");
  return "Editor owner: batched/duplicate progress, edits, late replies and restart/unmount PASS";
}
