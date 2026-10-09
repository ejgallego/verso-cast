import { createElement } from "react";
import { createRoot } from "react-dom/client";
import { openReactRuntime } from "../../tools/browser-runtime.mjs";

const status = document.getElementById("live-status");
try {
  const runtime = await openReactRuntime();
  let root;
  try {
    const View = runtime.call("VersoCastTests.Offline.View", "live-");
    root = createRoot(document.getElementById("live"));
    let revision = 0;
    let disposed = false;
    const update = () => {
      if (disposed) throw Error("comparison disposed");
      root.render(createElement(View, { revision: revision++ }));
    };
    const dispose = () => {
      if (disposed) return;
      disposed = true;
      try { root.unmount(); } finally { runtime.dispose(); }
    };
    document.getElementById("live-update").addEventListener("click", update);
    window.addEventListener("pagehide", dispose, { once: true });
    window.castComparison = Object.freeze({ update, dispose });
    update();
    status.textContent = "Live React · click the yellow highlight to set state; redraw retains it.";
  } catch (error) {
    try { root?.unmount(); } finally { runtime.dispose(); }
    throw error;
  }
} catch (error) {
  status.textContent = `Live view failed: ${error.message}`;
  throw error;
}
