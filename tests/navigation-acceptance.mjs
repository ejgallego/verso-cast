import assert from "node:assert/strict";
import { copyFile } from "node:fs/promises";
import { resolve } from "node:path";
import { Children, isValidElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { build } from "esbuild";
import { chromium } from "playwright";
import { openTestRuntime, root } from "./runtime.mjs";
import { stageProgram, serveDemo } from "../tools/demo.mjs";

const b = index => `part-root-block-${index}`;
const fragmentChildren = [`${b(1)}-block-1-block-0`, `${b(1)}-block-1-block-1`, `${b(1)}-block-2`];
const term = `${b(4)}-item-0-term`;
const description = `${b(4)}-item-0-description`;
const cases = [
  ["part-root-heading", [["H1", "part-root-heading"]]],
  [b(0), [["P", b(0)]]],
  [b(1), fragmentChildren.map(path => ["P", path])],
  [`${b(1)}-block-1`, fragmentChildren.slice(0, 2).map(path => ["P", path])],
  ...fragmentChildren.map(path => [path, [["P", path]]]),
  [b(2), [["UL", b(2)]]],
  [`${b(2)}-item-0`, [["LI", `${b(2)}-item-0`]]],
  [`${b(2)}-item-0-block-0`, [["P", `${b(2)}-item-0-block-0`]]],
  [`${b(2)}-item-0-block-1-item-0`, [["LI", `${b(2)}-item-0-block-1-item-0`]]],
  [`${b(2)}-item-0-block-1-item-0-block-0`, [["P", `${b(2)}-item-0-block-1-item-0-block-0`]]],
  [`${b(3)}-item-0`, [["LI", `${b(3)}-item-0`]]],
  [`${b(4)}-item-0`, [["DT", term], ["DD", description]]],
  [term, [["DT", term]]],
  [description, [["DD", description]]],
  [`${description}-block-0`, [["P", `${description}-block-0`]]],
  [b(5), [["BLOCKQUOTE", b(5)]]],
  [`${b(5)}-block-0`, [["P", `${b(5)}-block-0`]]],
  [b(6), [["ASIDE", b(6)]]],
  [`${b(6)}-block-0`, [["P", `${b(6)}-block-0`]]],
  [b(7), [["DIV", b(7)]]],
  [`${b(7)}-block-0`, [["P", `${b(7)}-block-0`]]],
  ["part-root-part-0-heading", [["H2", "part-root-part-0-heading"]]],
  [`${b(1)}-block-0`, []], // Empty fragment.
  [`${b(1)}-block-3`, []], // Hidden extension inside a focused fragment.
  [b(8), []],
  [`${b(8)}-block-0`, []],
  ["not-a-path", []],
  ["", []], // Clear focus without losing the independent change marker.
];
const changed = fragmentChildren[0];
const signature = nodes => nodes.map(({ tag, path, key }) => [tag, path, key]);
function collect(node, nodes = []) {
  if (!isValidElement(node)) return nodes;
  const path = node.props["data-verso-block"] ?? node.props["data-verso-list-item"];
  if (path) nodes.push({ tag: node.type.toUpperCase(), path, key: node.key,
    focused: node.props["data-verso-focus"] === "cursor",
    changed: node.props["data-verso-change"] === "changed", classes: node.props.className });
  Children.forEach(node.props.children, child => collect(child, nodes));
  return nodes;
}
const { runtime } = await openTestRuntime("+VersoCastTests.Navigation:vir");
try {
  const render = path => runtime.call("VersoCastTests.Navigation.render", path);
  const initial = collect(render(""));
  assert.deepEqual(initial.filter(node => /^H\d$/.test(node.tag)).map(node => node.tag),
    ["H1", "H2", "H3", "H4", "H5", "H6", "H6", "H6"], "custom heading levels clamp at h6");
  assert.match(renderToStaticMarkup(render("")), /id="nav-leaf"/);
  for (const [path, expected] of cases) {
    const nodes = collect(render(path));
    assert.deepEqual(nodes.filter(node => node.focused).map(node => [node.tag, node.path]).sort(),
      [...expected].sort(), `SSR focus ${path}`);
    assert.deepEqual(signature(nodes), signature(initial), "focus never changes content keys or addresses");
    assert.deepEqual(nodes.filter(node => node.changed).map(node => node.path), [changed]);
    for (const node of nodes) assert.equal(node.classes.includes("vir-verso-block-focused"), node.focused);
  }
  assert.doesNotMatch(renderToStaticMarkup(render(b(8))), /HIDDEN/);
  console.log(`Navigation SSR: ${cases.length} focus cases, stable keys, independent change markers and clamped custom headings PASS`);
} finally { runtime.dispose(); }

const directory = resolve(root, "_out/navigation");
await stageProgram("+VersoCastTests.Navigation:vir", directory);
await copyFile(resolve(root, "examples/browser/index.html"), resolve(directory, "index.html"));
await build({ absWorkingDir: root, entryPoints: ["tests/browser/navigation.mjs"],
  outfile: resolve(directory, "app.js"), bundle: true, format: "esm", target: "es2022" });
const { server, url } = await serveDemo(directory);
let browser;
try {
  browser = await chromium.launch();
  const page = await browser.newPage();
  page.setDefaultTimeout(15_000);
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  page.on("console", message => { if (message.type() === "error") errors.push(message.text()); });
  await page.goto(url);
  await page.locator("#app article").waitFor();
  await page.evaluate(() => { window.retainedNavigation = [...document.querySelectorAll(
    "#app [data-verso-block], #app [data-verso-list-item]")]; });
  for (const [path, expected] of cases) {
    await page.evaluate(path => window.castNavigation.update(path), path);
    await page.waitForFunction(path => document.querySelector("#app article")?.dataset.versoFocusBlock === path, path);
    const actual = await page.locator('#app [data-verso-focus="cursor"]').evaluateAll(nodes => nodes.map(node =>
      [node.tagName, node.dataset.versoBlock ?? node.dataset.versoListItem]));
    assert.deepEqual(actual.sort(), [...expected].sort(), `Chromium focus ${path}`);
    assert.equal(await page.evaluate(() => {
      const current = [...document.querySelectorAll("#app [data-verso-block], #app [data-verso-list-item]")];
      return current.length === window.retainedNavigation.length &&
        current.every((node, index) => node === window.retainedNavigation[index]);
    }), true, "focus changes preserve every addressed DOM node");
    assert.deepEqual(await page.locator('#app [data-verso-change="changed"]').evaluateAll(nodes =>
      nodes.map(node => node.dataset.versoBlock)), [changed]);
  }
  await page.evaluate(() => window.castNavigation.dispose());
  assert.equal(await page.locator("#app").textContent(), "");
  assert.deepEqual(errors, []);
  console.log(`Navigation Chromium: ${cases.length} focus cases, marker clearing, DOM retention and disposal PASS`);
} finally {
  try { await browser?.close(); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
