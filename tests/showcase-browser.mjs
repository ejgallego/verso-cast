import assert from "node:assert/strict";
import { copyFile } from "node:fs/promises";
import { resolve } from "node:path";
import { build } from "esbuild";
import { chromium } from "playwright";
import { root } from "./runtime.mjs";
import { stageProgram, serveDemo } from "../tools/demo.mjs";

const directory = resolve(root, "_out/showcase");
await stageProgram("+VersoCastShowcase:vir", directory);
await copyFile(resolve(root, "examples/browser/index.html"), resolve(directory, "index.html"));
await build({ absWorkingDir: root, bundle: true, format: "esm", target: "es2022",
  outfile: resolve(directory, "app.js"), stdin: { resolveDir: root, contents: `
    import {createElement} from "react";
    import {createRoot} from "react-dom/client";
    import {openReactRuntime} from "./tools/browser-runtime.mjs";
    const runtime = await openReactRuntime();
    const root = createRoot(document.getElementById("app"));
    try {
      const View = runtime.call("VersoCastShowcase.View");
      root.render(createElement(View, {}));
      window.disposeShowcase = () => { try { root.unmount(); } finally { runtime.dispose(); } };
    } catch (error) { try { root.unmount(); } finally { runtime.dispose(); } throw error; }
  ` } });
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
  const control = page.getByRole("checkbox", { name: "Show the callout" });
  await control.waitFor();
  assert.equal(await control.isChecked(), true);
  assert.equal(await page.locator("#showcase-welcome").textContent(), "A little document, a live React view");
  assert.equal(await page.locator("#showcase-try-it").textContent(), "Try the control");
  assert.equal(await page.locator("aside").count(), 1);
  await page.evaluate(() => { window.retainedShowcaseHeading = document.querySelector("h1"); });
  for (let update = 0; update < 4; update++) {
    await control.uncheck();
    await page.locator("aside").waitFor({ state: "detached" });
    await control.check();
    await page.locator("aside").waitFor();
    assert.equal(await page.evaluate(() => window.retainedShowcaseHeading === document.querySelector("h1")), true);
  }
  await page.screenshot({ path: resolve(directory, "showcase.png"), fullPage: true });
  await page.evaluate(() => window.disposeShowcase());
  assert.equal(await page.locator("#app").textContent(), "");
  assert.deepEqual(errors, []);
  console.log("Showcase Chromium: custom genre, headings, callout updates, retained DOM and disposal PASS");
} finally {
  try { await browser?.close(); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
