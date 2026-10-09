import { createRoot } from "react-dom/client";
import { openReactRuntime } from "../../tools/browser-runtime.mjs";

const runtime = await openReactRuntime();
let root;
try {
  root = createRoot(document.getElementById("app"));
  let disposed = false;
  const update = path => {
    if (disposed) throw Error("navigation test disposed");
    root.render(runtime.call("VersoCastTests.Navigation.render", path));
  };
  const dispose = () => {
    if (disposed) return;
    disposed = true;
    window.removeEventListener("pagehide", dispose);
    try { root.unmount(); } finally { runtime.dispose(); }
  };
  window.castNavigation = Object.freeze({ update, dispose });
  window.addEventListener("pagehide", dispose, { once: true });
  update("");
} catch (error) {
  try { root?.unmount(); } finally { runtime.dispose(); }
  throw error;
}
