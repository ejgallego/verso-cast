import { createElement } from "react";
import { createRoot } from "react-dom/client";
import { openReactRuntime } from "./runtime.mjs";

const runtime = await openReactRuntime();
let root;
try {
  const View = runtime.call("VersoCastTests.Retention.View");
  root = createRoot(document.getElementById("app"));
  let disposed = false;
  const dispose = () => {
    if (disposed) return;
    disposed = true;
    try { root.unmount(); } finally { runtime.dispose(); }
  };
  // Test-only lifetime handle, not a renderer or protocol API.
  window.castRetention = Object.freeze({ dispose });
  window.addEventListener("pagehide", dispose, { once: true });
  root.render(createElement(View));
} catch (error) {
  try { root?.unmount(); } finally { runtime.dispose(); }
  throw error;
}
