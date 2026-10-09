import assert from "node:assert/strict";
import { copyFile, mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import { build } from "esbuild";
import { chromium } from "playwright";
import { stageProgram, serveDemo } from "../tools/demo.mjs";
import { root } from "./runtime.mjs";

const directory = resolve(root, "_out/retention");
await stageProgram("+VersoCastTests.Retention:vir", directory);
await copyFile(resolve(root, "web/index.html"), resolve(directory, "index.html"));
await build({ absWorkingDir: root, entryPoints: ["web/retention.mjs"],
  outfile: resolve(directory, "app.js"), bundle: true, format: "esm", target: "es2022" });
const { server, url } = await serveDemo(directory);
let browser;
try {
  browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  page.on("console", message => { if (message.type() === "error") errors.push(message.text()); });
  await page.goto(url);
  const counter = label => page.locator(`[data-counter="${label}"]`);
  await counter("A").waitFor();
  await counter("A").getByRole("button").click();
  await counter("B").getByRole("button").click();
  await counter("B").getByRole("button").click();
  const counts = async () => [await counter("A").locator("output").textContent(),
    await counter("B").locator("output").textContent()];
  assert.deepEqual(await counts(), ["1", "2"]);
  await page.evaluate(() => {
    window.retainedA = document.querySelector('[data-counter="A"]');
    window.retainedB = document.querySelector('[data-counter="B"]');
  });
  const advance = async phase => {
    await page.locator("[data-next]").click();
    await page.locator(`[data-phase="${phase}"]`).waitFor();
  };
  for (const phase of [1, 2, 3]) {
    await advance(phase);
    assert.deepEqual(await counts(), ["1", "2"], `document edit ${phase} preserves extension state`);
    assert.equal(await page.evaluate(() => window.retainedA === document.querySelector('[data-counter="A"]')), true);
    assert.equal(await page.evaluate(() => window.retainedB === document.querySelector('[data-counter="B"]')), true);
    if (phase === 1) await page.evaluate(() => { window.retainedPlain = [...document.querySelectorAll("p")]
      .find(node => node.textContent === "Inserted ordinary block"); });
    else assert.equal(await page.evaluate(() => window.retainedPlain === [...document.querySelectorAll("p")]
      .find(node => node.textContent === "Inserted ordinary block")), true);
  }
  assert.equal(await counter("A").locator("p").textContent(), "A edited body");
  await advance(4);
  assert.equal(await counter("B").count(), 0);
  assert.equal(await counter("A").locator("output").textContent(), "1");
  assert.equal(await page.evaluate(() => window.retainedB.isConnected), false);
  await advance(5);
  assert.deepEqual(await counts(), ["1", "0"], "reinserted B starts a new component lifetime");
  assert.equal(await page.evaluate(() => window.retainedB === document.querySelector('[data-counter="B"]')), false);
  await advance(6);
  assert.equal(await counter("A").count(), 2);
  assert.deepEqual(await counter("A").locator("output").allTextContents(), ["1", "0"]);
  await counter("A").nth(1).getByRole("button").click();
  assert.deepEqual(await counter("A").locator("output").allTextContents(), ["1", "1"],
    "duplicate semantic identities have independent state");
  assert.deepEqual(errors, [], "no duplicate-key or runtime warnings");
  await mkdir(directory, { recursive: true });
  await page.screenshot({ path: resolve(directory, "identities.png"), fullPage: true });
  await page.evaluate(() => window.castRetention.dispose());
  assert.equal(await page.locator("#app").textContent(), "");
  console.log("Chromium identity edits: insertion, reorder, body edit, removal/reinsertion, duplicate IDs and disposal PASS");
} finally {
  try { await browser?.close(); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
