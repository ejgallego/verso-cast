import { createElement, useLayoutEffect } from "react";
import { createRoot } from "react-dom/client";
import { openReactRuntime } from "../../tools/browser-runtime.mjs";

const runtime = await openReactRuntime();
let root;
try {
  const args = document.body.dataset.fixture === "blog" ? ["live-"] : [];
  const View = runtime.call(document.body.dataset.entry, ...args);
  root = createRoot(document.getElementById("live"));
  let revision = 0, disposed = false, commits = 0;
  function ObservedView(props) {
    useLayoutEffect(() => { commits++; });
    return createElement(View, props);
  }
  const update = () => {
    if (disposed) throw Error("comparison disposed");
    root.render(createElement(ObservedView, { revision: revision++ }));
  };
  const dispose = () => {
    if (disposed) return;
    disposed = true;
    try { root.unmount(); } finally { runtime.dispose(); }
  };
  document.getElementById("redraw").addEventListener("click", update);
  window.addEventListener("pagehide", dispose, { once: true });
  window.genreComparison = Object.freeze({ update, dispose, get commits() { return commits; } });
  update();
} catch (error) {
  try { root?.unmount(); } finally { runtime.dispose(); }
  throw error;
}
