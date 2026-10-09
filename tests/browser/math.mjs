import { createElement, useLayoutEffect } from "react";
import { createRoot } from "react-dom/client";
import katex from "katex";
import "katex/dist/katex.css";
import { createMathComponent } from "verso-cast/katex";
import { openReactRuntime } from "../../tools/browser-runtime.mjs";

const runtime = await openReactRuntime();
let root;
try {
  let typesetCount = 0;
  const MathFormula = createMathComponent({ renderToString: (...args) => {
    typesetCount++;
    return katex.renderToString(...args);
  } });
  root = createRoot(document.getElementById("app"));
  let disposed = false;
  let revision = 0;
  let committedRevision = 0;
  // Test/demo-only commit barrier; no clocks or renderer instrumentation.
  function Commit({ node, revision }) {
    useLayoutEffect(() => { committedRevision = revision; });
    return node;
  }
  const update = (source, display = false) => {
    if (disposed) throw Error("math demo disposed");
    const node = runtime.call("VersoCastTests.Math.render", MathFormula, source, display);
    root.render(createElement(Commit, { node, revision: ++revision }));
    return revision;
  };
  const form = document.querySelector("form");
  const submit = event => {
    event.preventDefault();
    update(form.elements.source.value, form.elements.display.checked);
  };
  const dispose = () => {
    if (disposed) return;
    disposed = true;
    form.removeEventListener("submit", submit);
    window.removeEventListener("pagehide", dispose);
    try { root.unmount(); } finally { runtime.dispose(); }
  };
  window.castMath = Object.freeze({ update, dispose, typesetCount: () => typesetCount,
    committedRevision: () => committedRevision });
  form.addEventListener("submit", submit);
  window.addEventListener("pagehide", dispose, { once: true });
  update(form.elements.source.value, form.elements.display.checked);
} catch (error) {
  try { root?.unmount(); } finally { runtime.dispose(); }
  throw error;
}
