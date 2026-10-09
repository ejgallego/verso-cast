import assert from "node:assert/strict";
import { mkdir } from "node:fs/promises";
import { chromium } from "playwright";
import { stageDemo, serveDemo } from "../tools/demo.mjs";

const { server, url } = await serveDemo(await stageDemo());
let browser;
try {
  browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  await page.goto(url);
  const checkbox = page.getByRole("checkbox", { name: "Show an extra block" });
  await checkbox.check();
  await page.getByText("This extra block is controlled by React state.").waitFor();
  await page.evaluate(() => { window.retainedParagraph = document.querySelector("article p"); });
  for (let revision = 1; revision <= 20; revision++) {
    await page.evaluate(revision => window.castDemo.updateProps(revision), revision);
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    assert.equal(await checkbox.isChecked(), true);
    assert.equal(await page.evaluate(() => window.retainedParagraph === document.querySelector("article p")), true);
  }
  await mkdir("_out", { recursive: true });
  await page.screenshot({ path: "_out/widget.png", fullPage: true });
  await checkbox.uncheck();
  await page.getByText("This extra block is controlled by React state.").waitFor({ state: "detached" });
  await page.evaluate(() => window.castDemo.dispose());
  assert.equal(await page.locator("#app").textContent(), "");
  assert.equal(await page.evaluate(() => {
    try { window.castDemo.invokeAfterDisposal(); return false; } catch { return true; }
  }), true);
  assert.equal(await page.evaluate(() => {
    try { window.castDemo.invokeRetainedAfterDisposal(); return false; }
    catch (error) { return /disposed/.test(error.message); }
  }), true);
  assert.deepEqual(errors, []);
  console.log("Chromium widget: retained state/DOM across 20 updates; callbacks, unmount and disposal PASS");
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
