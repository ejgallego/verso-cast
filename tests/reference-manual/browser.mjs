import React from "react";
import { createRoot } from "react-dom/client";
import { createVirRuntime } from "lean-vir";
import { createBrowserHostBindings } from "lean-vir/host-bindings";
import { createBrowserReactHostBindings } from "lean-vir/react-host-bindings";
import { pages } from "./pages.mjs";

// Controlled RPC transport only: real Wasm, Lean decoder, Cast, React and DOM.
// This tests the client lifecycle, not the actual editor/LSP connection.
const documents = await Promise.all(pages.map(async ({ name }) =>
  (await fetch(`${name}.json`)).text()));
const staticPages = await Promise.all(pages.map(async ({ name }) =>
  (await fetch(`${name}.ssr.html`)).text()));
const showStatic = index => {
  const pane = document.getElementById("ssr");
  if (pane) pane.innerHTML = staticPages[index];
};
// Test-only synchronization: act drains React updates/effects and reply handlers,
// including stale replies. Interactive controls still use ordinary React events.
async function settle(action) {
  const previous = globalThis.IS_REACT_ACT_ENVIRONMENT;
  globalThis.IS_REACT_ACT_ENVIRONMENT = true;
  try { await React.act(async () => { await action(); }); }
  finally { globalThis.IS_REACT_ACT_ENVIRONMENT = previous; }
}
let current = 0, malformed = false, hold = false, pending = [], calls = 0;
const handlers = new Set();
const session = { call(method, params, options) {
  if (method !== "CastManualPreview.Server.document" || params.line !== 0 || params.character !== 0)
    throw Error(`unexpected preview request: ${method}; line=${String(params.line)} (${typeof params.line}); character=${String(params.character)}`);
  calls++;
  const result = malformed ? "not JSON" : documents[current];
  // Deliberately ignore abort for held replies: the Lean active guard must work.
  if (hold) return new Promise(resolve => pending.push({
    signal: options.abortSignal, resolve: () => resolve(result),
  }));
  if (options.abortSignal.aborted) return Promise.reject(Error("aborted"));
  return Promise.resolve(result);
} };
const runtime = await createVirRuntime({
  wasmUrl: new URL("runtime.wasm", location.href).href,
  irPackageSet: [new Uint8Array(await (await fetch("widget.irpkg")).arrayBuffer())],
  defaultHostBindings: () => createBrowserHostBindings({
    reactHostBindings: createBrowserReactHostBindings,
    infoviewUseRpcSession: () => session,
    infoviewUseClientNotificationEffect: (method, callback, deps) => {
      if (method !== "textDocument/didChange") throw Error("unexpected notification");
      React.useEffect(() => { handlers.add(callback); return () => handlers.delete(callback); }, deps);
    },
  }),
});
const View = runtime.call("CastManualPreview.createComponent");
const root = createRoot(document.getElementById("app"));
let uri = "file:///Manual/Intro.lean";
const render = () => root.render(React.createElement(View, { pos: { uri, line: 35, character: 0 } }));
const edit = (target = uri) => {
  for (const handler of handlers) handler({ textDocument: { uri: target } });
};
const editExample = text => {
  const document = JSON.parse(documents[0]);
  let edited = false;
  const visit = value => {
    if (!value || typeof value !== "object" || edited) return;
    if (value.other?.container?.name === "Manual.example") {
      // The first child is the summary; change the actual first body paragraph.
      const paragraph = value.other.content.slice(1).find(child => child.para);
      if (!paragraph) throw Error("reference example has no body paragraph");
      paragraph.para = [{ text }];
      edited = true;
      return;
    }
    Object.values(value).forEach(child => Array.isArray(child) ? child.forEach(visit) : visit(child));
  };
  visit(document);
  if (!edited) throw Error("reference example not found");
  documents[0] = JSON.stringify(document);
  edit();
};
window.manualPreview = {
  get calls() { return calls; },
  get subscriptions() { return handlers.size; },
  get pendingCount() { return pending.length; },
  get abortedCount() { return pending.filter(reply => reply.signal.aborted).length; },
  async select(index) {
    if (!pages[index]) throw Error("unknown sample page");
    current = index; uri = `file:///${pages[index].module.replaceAll(".", "/")}.lean`;
    const picker = document.getElementById("sample");
    if (picker) picker.value = String(index);
    showStatic(index); await settle(render);
  },
  edit: target => settle(() => edit(target)),
  editExample: text => settle(() => editExample(text)),
  render: () => settle(render),
  malformed: value => settle(() => { malformed = value; edit(); }),
  hold(value) { hold = value; },
  async release() {
    const replies = pending; pending = [];
    await settle(() => { replies.forEach(reply => reply.resolve()); });
    return replies.length;
  },
  dispose() { try { root.unmount(); } finally { runtime.dispose(); } },
};
const picker = document.getElementById("sample");
if (picker) {
  pages.forEach(({ title }, index) => picker.add(new Option(title, String(index))));
  picker.addEventListener("change", () => window.manualPreview.select(Number(picker.value)));
}
showStatic(0);
await settle(render);
