import { createElement, useMemo } from "react";

// Optional leaf: the caller owns the KaTeX bundle, CSS/fonts and source policy.
// Create once, then pass this stable component to Renderers.mathComponent?.
export function createMathComponent(katex) {
  return function MathFormula({ source, children: _children, ...attributes }) {
    const displayMode = attributes["data-verso-math-mode"] === "display";
    const html = useMemo(() => katex.renderToString(source, {
      displayMode,
      output: "htmlAndMathml",
      throwOnError: false,
      trust: false,
      // KaTeX mutates this object for definitions. Never share it across leaves.
      macros: {},
    }), [source, displayMode]);
    // Only KaTeX-produced HTML enters this boundary; not caller-provided markup.
    // Producing content during render also makes this leaf usable by React SSR.
    return createElement("span", { ...attributes, dangerouslySetInnerHTML: { __html: html } });
  };
}
