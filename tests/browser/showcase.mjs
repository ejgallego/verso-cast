import { createElement } from "react";
import { createRoot } from "react-dom/client";
import { openReactRuntime } from "../../tools/browser-runtime.mjs";

const runtime = await openReactRuntime();
let root;
try {
  const View = runtime.call("VersoCastShowcase.View");
  root = createRoot(document.getElementById("app"));
  let disposed = false;
  const dispose = () => {
    if (disposed) return;
    disposed = true;
    window.removeEventListener("pagehide", dispose);
    try { root.unmount(); } finally { runtime.dispose(); }
  };
  window.castShowcase = Object.freeze({ dispose });
  window.addEventListener("pagehide", dispose, { once: true });
  root.render(createElement(View, {}));
} catch (error) {
  try { root?.unmount(); } finally { runtime.dispose(); }
  throw error;
}
