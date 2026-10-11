import assert from "node:assert/strict";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import katex from "katex";
import { createMathComponent } from "verso-cast/katex";

const MathFormula = createMathComponent(katex);
const html = renderToStaticMarkup(createElement(MathFormula, {
  source: String.raw`\frac{a}{b}`, id: "external-formula", "data-verso-math-mode": "display",
}));
assert.match(html, /id="external-formula"/);
assert.match(html, /class="katex-display"/);
assert.match(html, /<math\b/);
assert.doesNotMatch(html, /katex-error/);
assert.throws(() => import.meta.resolve("verso-cast/js/katex.mjs"),
  { code: "ERR_PACKAGE_PATH_NOT_EXPORTED" });
