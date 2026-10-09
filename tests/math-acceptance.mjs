import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import katex from "katex";
import { build } from "esbuild";
import { chromium } from "playwright";
import { createMathComponent } from "../web/katex.mjs";
import { stageProgram, serveDemo } from "../tools/demo.mjs";
import { openTestRuntime, root } from "./runtime.mjs";

const MathFormula = createMathComponent(katex);
const cases = [
  { source: "x < y", display: false },
  { source: String.raw`\sum_{i=1}^{n} i`, display: false },
  { source: String.raw`\sum_{i=1}^{n} i`, display: true },
  { source: "{", display: false, error: true },
  { source: String.raw`\frac{a}{b}`, display: false },
  { source: String.raw`\text{<img src=x onerror=alert(1)>}`, display: false },
];
const { runtime } = await openTestRuntime("+VersoCastTests.Math:vir");
try {
  for (const input of cases) {
    input.html = renderToStaticMarkup(runtime.call("VersoCastTests.Math.render",
      MathFormula, input.source, input.display));
    assert.match(input.html, input.error ? /katex-error/ : /class="katex"/);
    assert.equal(input.html.includes("katex-display"), input.display);
    assert.equal(input.html.includes("<img"), false, "formula text is not raw HTML");
  }
} finally { runtime.dispose(); }

// Attribute preservation and macro isolation also apply to SSR, without a DOM.
const callerStyle = Object.freeze({ color: "purple" });
const props = Object.freeze({ source: "x", className: "caller-math", id: "formula",
  style: callerStyle, "data-verso-math-mode": "inline" });
const attributeHtml = renderToStaticMarkup(createElement(MathFormula, props));
assert.match(attributeHtml, /id="formula"/);
assert.match(attributeHtml, /class="caller-math"/);
assert.match(attributeHtml, /style="color:purple"/);
assert.equal(props.style, callerStyle);
const formula = source => renderToStaticMarkup(createElement(MathFormula, { source }));
assert.match(formula(String.raw`\gdef\castleak{Z}\castleak`), />Z</);
assert.doesNotMatch(formula(String.raw`\castleak`), />Z</, "macros never leak to another evaluation");
const blocked = formula(String.raw`\href{javascript:alert(1)}{unsafe}`);
assert.doesNotMatch(blocked, /<a\b|href=/, "untrusted TeX cannot create a link");
console.log("Math SSR: document injection, inline/display, malformed recovery, escaping, attributes and macro isolation PASS");

const directory = resolve(root, "_out/math");
await stageProgram("+VersoCastTests.Math:vir", directory);
await build({ absWorkingDir: root, entryPoints: ["web/math.mjs"],
  outfile: resolve(directory, "app.js"), bundle: true, format: "esm", target: "es2022",
  loader: { ".woff2": "file", ".woff": "file", ".ttf": "file" } });
await writeFile(resolve(directory, "index.html"), `<!doctype html><html lang="en"><meta charset="utf-8">
<title>Cast math · live and offline</title><link rel="stylesheet" href="app.css">
<style>body{font:16px system-ui;max-width:70rem;margin:2rem auto;padding:0 1rem}
input[type=text]{width:28rem;max-width:70%}body>section{border:1px solid #ccc;margin:1rem 0;padding:1rem}
form{display:flex;align-items:center;gap:0.5rem;flex-wrap:wrap}</style>
<h1>Cast math · same leaf, live and offline</h1>
<form><input aria-label="TeX source" type="text" name="source" value="x &lt; y">
<label><input type="checkbox" name="display"> Display</label><button>Render</button></form>
<section><h2>Live React</h2><div id="app"></div></section>
<section><h2>Offline React</h2><div id="offline">${cases[0].html}</div></section>
<script type="module" src="app.js"></script></html>`);
const { server, url } = await serveDemo(directory);
let browser;
let passed = false;
try {
  browser = await chromium.launch();
  const page = await browser.newPage();
  page.setDefaultTimeout(15_000);
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  page.on("console", message => { if (message.type() === "error") errors.push(message.text()); });
  await page.goto(url);
  await page.locator("#app .katex").waitFor();
  await page.evaluate(() => { window.retainedMath = document.querySelector("#app [data-verso-math-mode]"); });
  const update = async input => {
    const revision = await page.evaluate(input => window.castMath.update(input.source, input.display), input);
    await page.waitForFunction(revision => window.castMath.committedRevision() === revision, revision);
  };
  for (const input of cases) {
    await update(input);
    await page.waitForFunction(input => {
      const leaf = document.querySelector("#app [data-verso-math-mode]");
      return leaf?.dataset.versoMathMode === (input.display ? "display" : "inline") &&
        (input.error ? leaf.querySelector(".katex-error")?.textContent === input.source :
          leaf.querySelector("annotation")?.textContent === input.source);
    }, input);
    const markup = await page.evaluate(html => {
      const expected = document.createElement("template");
      expected.innerHTML = html;
      // Compare KaTeX's complete subtree. React's outer style serialization and
      // DOM attribute order legitimately differ between SSR and live rendering.
      return { actual: document.querySelector("#app [data-verso-math-mode]").innerHTML,
        expected: expected.content.querySelector("[data-verso-math-mode]").innerHTML };
    }, input.html);
    assert.equal(markup.actual, markup.expected, "live and SSR math markup agree after HTML parsing");
    assert.equal(await page.evaluate(() => window.retainedMath ===
      document.querySelector("#app [data-verso-math-mode]")), true, "math leaf survives updates");
  }
  const before = await page.evaluate(() => window.castMath.typesetCount());
  await update(cases.at(-1));
  assert.equal(await page.evaluate(() => window.castMath.typesetCount()), before,
    "unchanged source/mode does not typeset again");
  const fonts = await page.evaluate(async () => { await document.fonts.ready;
    return [...document.fonts].filter(font => font.family.startsWith("KaTeX") && font.status === "loaded").length; });
  assert.ok(fonts > 0, "KaTeX fonts are reachable");
  await update(cases[0]);
  await mkdir(directory, { recursive: true });
  await page.screenshot({ path: resolve(directory, "math.png"), fullPage: true });
  await page.evaluate(() => window.castMath.dispose());
  assert.equal(await page.locator("#app").textContent(), "");
  assert.equal(await page.evaluate(() => { try { window.castMath.update("x"); return false; }
    catch { return true; } }), true);
  assert.deepEqual(errors, [], "no React/runtime warnings or asset failures");
  console.log("Math Chromium: SSR/live parity, source/mode updates, malformed recovery, retained DOM, memoization, fonts and disposal PASS");
  passed = true;
} finally {
  try { await browser?.close(); }
  finally {
    if (passed && process.argv.includes("--serve")) {
      console.log(`Cast math comparison: ${url}`);
      process.once("SIGINT", () => server.close());
      process.once("SIGTERM", () => server.close());
    } else await new Promise(resolve => server.close(resolve));
  }
}
