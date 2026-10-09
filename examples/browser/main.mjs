import { createElement } from "react";
import { createRoot } from "react-dom/client";
import { openReactRuntime } from "../../tools/browser-runtime.mjs";

const runtime = await openReactRuntime();
let root;
try {
  const View = runtime.call("VersoCastDemo.View");
  root = createRoot(document.getElementById("app"));
  let disposed = false;
  const updateProps = revision => {
    if (disposed) throw Error("demo disposed");
    root.render(createElement(View, { revision }));
  };
  const dispose = () => {
    if (disposed) return;
    disposed = true;
    window.removeEventListener("pagehide", dispose);
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
} catch (error) {
  try { root?.unmount(); } finally { runtime.dispose(); }
  throw error;
}
