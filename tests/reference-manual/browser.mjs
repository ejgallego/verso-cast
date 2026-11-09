import React from "react";
import { createRoot } from "react-dom/client";
import { createVirRuntime } from "lean-vir";
import { createBrowserHostBindings } from "lean-vir/host-bindings";
import { createBrowserReactHostBindings } from "lean-vir/react-host-bindings";
import { openReactRuntime } from "../../tools/browser-runtime.mjs";
import { pages } from "./pages.mjs";
import { usePage } from "../../js/preview.mjs";
import { PanelView } from "./panel.mjs";

// Controlled RPC transport only: real Wasm, Lean decoder, Cast, React and DOM.
// This tests the client lifecycle, not the actual editor/LSP connection.
const documents = await Promise.all(pages.map(async ({ name }) =>
  (await fetch(`${name}.json`)).text()));
const staticPages = await Promise.all(pages.map(async ({ name }) =>
  (await fetch(`${name}.ssr.html`)).text()));
const typedDocuments = await Promise.all(pages.map(async ({ name }) =>
  (await fetch(`${name}.typed.json`)).json()));
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
let current = 0, malformed = false, hold = false, pending = [], calls = 0, documentVersion = 1;
let lastReply;
const session = { call(method, params, options) {
  if (method !== "VersoCast.Manual.Preview.Server.document" || params.expectedVersion !== documentVersion)
    throw Error(`unexpected preview request: ${method}`);
  calls++;
  const result = { uri, version: documentVersion, snapshotRef: Object.freeze({ __rpcref: calls }),
    documentJson: malformed ? "not JSON" : documents[current], hasErrors: false };
  lastReply = result;
  // Deliberately ignore abort for held replies: the native selection guard must work.
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
  }),
});
const View = runtime.call("CastManualPreview.createComponent");
const root = createRoot(document.getElementById("app"));
let typedRuntime;
let publicSession = session, loadedPage, selection, controller;
const lifecycle = [];
// Observe committed state in a test-only layout effect, never a precommit
// publication callback. Production request and presentation code are unchanged.
function TestHost({ selection, decode, view, inspect }) {
  const state = usePage(selection, decode);
  React.useLayoutEffect(() => {
    if (!state.matchesSelection) return;
    loadedPage = inspect(state.lastGood.value);
    lifecycle.push("committed");
  }, [state.lastGood, state.matchesSelection, inspect]);
  return React.createElement(PanelView, { bridge: { view }, state });
}
let uri = "file:///Manual/Intro.lean";
const render = () => root.render(React.createElement(View,
  { pos: { uri, line: 35, character: 0 }, pageHost: TestHost, selection }));
const replaceSelection = () => {
  if (controller) { controller.abort(); lifecycle.push("invalidated"); }
  controller = new AbortController();
  selection = Object.freeze({ session: publicSession, uri, expectedVersion: documentVersion,
    signal: controller.signal });
  render();
};
const edit = (target = uri) => {
  if (target !== uri) return;
  documentVersion++;
  replaceSelection();
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
  get loadedPage() { return loadedPage; },
  get referencePreserved() { return loadedPage?.snapshotRef === lastReply?.snapshotRef; },
  get sessionPreserved() { return loadedPage?.session === publicSession; },
  get lifecycle() { return [...lifecycle]; },
  refreshPublic: () => settle(replaceSelection),
  renderPublic: () => settle(render),
  replaceSession: () => settle(() => { publicSession = { ...session }; replaceSelection(); }),
  // A direct typed-call gate, not a replacement RPC shell. The live all-Lean
  // widget keeps its current decoder until VIR exposes that composition seam.
  async renderTyped(index) {
    if (!pages[index]) throw Error("unknown sample page");
    typedRuntime ??= await openReactRuntime();
    await settle(() => root.render(typedRuntime.callWith(
      { argumentRepresentation: "json-safe-v1" }, "CastManualPreview.renderPart", typedDocuments[index])));
  },
  get calls() { return calls; },
  get activeRequest() { return !!controller && !controller.signal.aborted; },
  get pendingCount() { return pending.length; },
  get abortedCount() { return pending.filter(reply => reply.signal.aborted).length; },
  async select(index) {
    if (!pages[index]) throw Error("unknown sample page");
    current = index; uri = `file:///${pages[index].module.replaceAll(".", "/")}.lean`;
    const picker = document.getElementById("sample");
    if (picker) picker.value = String(index);
    showStatic(index); await settle(replaceSelection);
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
  dispose() {
    try { controller.abort(); root.unmount(); }
    finally { try { typedRuntime?.dispose(); } finally { runtime.dispose(); } }
  },
};
const picker = document.getElementById("sample");
if (picker) {
  pages.forEach(({ title }, index) => picker.add(new Option(title, String(index))));
  picker.addEventListener("change", () => window.manualPreview.select(Number(picker.value)));
}
showStatic(0);
await settle(replaceSelection);
