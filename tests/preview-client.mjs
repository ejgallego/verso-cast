import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { build } from "esbuild";
import { chromium } from "playwright";
import { serveDemo } from "../tools/demo.mjs";

const output = resolve("_out/preview-client");
await mkdir(output, { recursive: true });
await writeFile(resolve(output, "index.html"), '<div id="app"></div><script type="module" src="app.js"></script>');
await build({ entryPoints: ["tests/preview-client.browser.mjs"], outfile: resolve(output, "app.js"),
  bundle: true, format: "esm", plugins: [{ name: "editor-peer", setup(builder) {
    builder.onResolve({ filter: /^@leanprover\/infoview$/ }, () =>
      ({ path: resolve("tests/reference-manual/infoview-peer.mjs") }));
    builder.onResolve({ filter: /^__VIR_SHELL__$/ }, () => ({ path: "shell", namespace: "fixture" }));
    builder.onLoad({ filter: /.*/, namespace: "fixture" }, () =>
      ({ contents: "export default function Shell() {}" }));
  } }] });
const { server, url } = await serveDemo(output);
let browser;
try {
  browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  page.on("console", message => { if (message.type() === "error") errors.push(message.text()); });
  await page.goto(url);
  await page.waitForFunction(() => window.checkPreview);
  console.log(await page.evaluate(() => window.checkPreview()));
  console.log(await page.evaluate(() => window.checkEditorOwner()));
  assert.deepEqual(errors, []);
} finally {
  try { await browser?.close(); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
