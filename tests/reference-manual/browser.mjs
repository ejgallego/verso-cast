import React from "react";
import { createRoot } from "react-dom/client";
import { createVirRuntime } from "lean-vir";
import { createBrowserHostBindings } from "lean-vir/host-bindings";
import { createBrowserReactHostBindings } from "lean-vir/react-host-bindings";

// Controlled RPC transport only: real Wasm, Lean decoder, Cast, React and DOM.
// This tests the client lifecycle, not the actual editor/LSP connection.
const documents = await Promise.all(["intro", "empty"].map(async name =>
  (await fetch(`${name}.json`)).text()));
let current = 0, malformed = false, hold = false, pending = [], calls = 0;
const handlers = new Set();
const session = { call(method, params, options) {
  if (method !== "CastManualPreview.Server.document" || params.line !== 0 || params.character !== 0)
    throw Error(`unexpected preview request: ${method}; line=${String(params.line)} (${typeof params.line}); character=${String(params.character)}`);
  calls++;
  const result = malformed ? "not JSON" : documents[current];
  // Deliberately ignore abort for held replies: the Lean active guard must work.
  if (hold) return new Promise(resolve => pending.push(() => resolve(result)));
  if (options.abortSignal.aborted) return Promise.reject(Error("aborted"));
  return Promise.resolve(result);
} };
const runtime = await createVirRuntime({
  wasmUrl: new URL("runtime.wasm", location.href).href,
  irPackageSet: new URL("document.irpkg-set.json", location.href).href,
  defaultHostBindings: () => createBrowserHostBindings({
    reactHostBindings: createBrowserReactHostBindings,
    infoviewUseRpcSession: () => session,
    infoviewUseClientNotificationEffect: (method, callback, deps) => {
      if (method !== "textDocument/didChange") throw Error("unexpected notification");
      React.useEffect(() => { handlers.add(callback); return () => handlers.delete(callback); }, deps);
    },
  }),
});
const View = runtime.call("CastManualPreview.View");
const root = createRoot(document.getElementById("app"));
let uri = "file:///Manual/Intro.lean";
const render = () => root.render(React.createElement(View, { pos: { uri, line: 35, character: 0 } }));
const edit = (target = uri) => {
  for (const handler of handlers) handler({ textDocument: { uri: target } });
};
window.manualPreview = {
  get calls() { return calls; },
  get subscriptions() { return handlers.size; },
  select(index) { current = index; uri = index ? "file:///Manual/BasicTypes/Empty.lean" : "file:///Manual/Intro.lean"; render(); },
  edit, render,
  malformed(value) { malformed = value; edit(); },
  hold(value) { hold = value; },
  release() { const replies = pending; pending = []; replies.forEach(resolve => resolve()); },
  dispose() { try { root.unmount(); } finally { runtime.dispose(); } },
};
render();
