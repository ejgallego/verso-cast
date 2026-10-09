import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { copyFile, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { build } from "esbuild";
import { chromium } from "playwright";
import { stageProgram, serveDemo } from "../../tools/demo.mjs";

const root = fileURLToPath(new URL("../..", import.meta.url));
const manual = resolve(root, ".local/reference-manual");
const run = args => execFileSync("lake", args, { cwd: manual, stdio: "inherit" });
run(["build", "CastManualPreview", "+Manual.Intro:olean", "+Manual.BasicTypes.Empty:olean"]);
run(["env", "lean", "--run", "cast-preview/ExportPages.lean"]);
const output = resolve(root, "_out/reference-manual");
await stageProgram("+CastManualPreview:vir", output, { cwd: manual });
for (const name of ["intro", "empty"])
  await copyFile(resolve(manual, `.cast-preview/${name}.json`), resolve(output, `${name}.json`));
await copyFile(resolve(root, "examples/browser/index.html"), resolve(output, "index.html"));
await build({ absWorkingDir: root, entryPoints: ["tests/reference-manual/browser.mjs"],
  outfile: resolve(output, "app.js"), bundle: true, format: "esm", target: "es2022" });
// Sanity check that these really are different elaborated documents.
assert.notEqual(await readFile(resolve(output, "intro.json"), "utf8"),
  await readFile(resolve(output, "empty.json"), "utf8"));
const { server, url } = await serveDemo(output);
let browser;
try {
  browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  await page.goto(url);
  const heading = name => page.getByRole("heading", { name, exact: true });
  try { await heading("Introduction").waitFor({ timeout: 10000 }); }
  catch (error) {
    console.error("Initial preview errors:", errors);
    console.error("Initial preview DOM:", await page.locator("#app").textContent());
    throw error;
  }
  await page.getByText("Typographical Conventions", { exact: true }).first().waitFor();
  for (const name of ["Verso.Genre.Manual.InlineLean.Block.lean",
    "Verso.Genre.Manual.InlineLean.Block.leanOutput", "Manual.proofState", "Manual.example"])
    assert.equal((await page.locator("#app").textContent()).includes(`[block extension: ${name}]`), false, name);
  assert.ok(await page.locator('pre[data-verso-kind="lean"]').count());
  assert.ok(await page.locator('pre[data-verso-kind="proof-state"]').count());
  const example = page.locator('details[data-verso-kind="example"]').first();
  assert.equal(await example.evaluate(node => node.open), false);
  await example.locator("summary").click();
  assert.equal(await example.evaluate(node => node.open), true);
  await example.getByText("This is an example of an example.", { exact: true }).waitFor();
  await page.evaluate(() => { window.firstHeading = document.querySelector("article h1"); });
  const calls = await page.evaluate(() => window.manualPreview.calls);
  await page.evaluate(() => window.manualPreview.render());
  await page.waitForTimeout(100);
  assert.equal(await page.evaluate(() => window.manualPreview.calls), calls);
  await page.evaluate(() => window.manualPreview.edit("file:///Unrelated.lean"));
  await page.waitForTimeout(100);
  assert.equal(await page.evaluate(() => window.manualPreview.calls), calls);
  await page.evaluate(() => window.manualPreview.edit());
  await page.waitForFunction(expected => window.manualPreview.calls > expected, calls);
  await heading("Introduction").waitFor();
  assert.equal(await page.evaluate(() => window.firstHeading === document.querySelector("article h1")), true);
  assert.equal(await example.evaluate(node => node.open), true, "example disclosure survives a refresh");
  await page.evaluate(() => window.manualPreview.malformed(true));
  await page.getByRole("status").filter({ hasText: "Invalid manual preview:" }).waitFor();
  await heading("Introduction").waitFor();
  await page.evaluate(() => { window.manualPreview.malformed(false); window.manualPreview.hold(true); window.manualPreview.edit(); });
  await page.waitForTimeout(100);
  await page.evaluate(() => { window.manualPreview.hold(false); window.manualPreview.select(1); });
  await heading("The Empty Type").waitFor();
  await page.evaluate(() => window.manualPreview.release());
  await page.waitForTimeout(100);
  await heading("The Empty Type").waitFor();
  await page.screenshot({ path: resolve(output, "empty.png"), fullPage: true });
  await page.evaluate(() => window.manualPreview.select(0));
  await heading("Introduction").waitFor();
  await page.screenshot({ path: resolve(output, "intro.png"), fullPage: true });
  await page.evaluate(() => window.manualPreview.dispose());
  assert.equal(await page.locator("#app").textContent(), "");
  assert.equal(await page.evaluate(() => window.manualPreview.subscriptions), 0);
  assert.deepEqual(errors, []);
  console.log("Real Manual pages / Chromium: decode, render, switching, refresh, stale/error recovery and disposal PASS");
} finally {
  try { await browser?.close(); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
