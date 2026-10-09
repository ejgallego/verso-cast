import { createElement } from "react";
import { createRoot } from "react-dom/client";
import { createVirRuntime } from "lean-vir";
import { createBrowserHostBindings } from "lean-vir/host-bindings";
import { createBrowserReactHostBindings } from "lean-vir/react-host-bindings";

const runtime = await createVirRuntime({
  wasmUrl: new URL("runtime.wasm", import.meta.url).href,
  irPackageSet: new URL("document.irpkg-set.json", import.meta.url).href,
  defaultHostBindings: () => createBrowserHostBindings({
    reactHostBindings: createBrowserReactHostBindings,
  }),
});
const View = runtime.call("VersoCastDemo.View");
const root = createRoot(document.getElementById("app"));
let disposed = false;
const updateProps = revision => root.render(createElement(View, { revision }));
const dispose = () => {
  if (disposed) return;
  disposed = true;
  try { root.unmount(); } finally { runtime.dispose(); }
};
// A demo-only replay surface. The library exports no browser globals or root API.
window.castDemo = Object.freeze({
  updateProps,
  dispose,
  invokeAfterDisposal: () => runtime.call("VersoCastDemo.View"),
  invokeRetainedAfterDisposal: () => View({}),
});
window.addEventListener("pagehide", dispose, { once: true });
updateProps(0);
