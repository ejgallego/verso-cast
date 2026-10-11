import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { build } from "esbuild";
import { chromium } from "playwright";
import { renderToStaticMarkup } from "react-dom/server";
import { stageProgram, serveDemo } from "../../tools/demo.mjs";
import { openTestRuntime } from "../runtime.mjs";
import { pages } from "./pages.mjs";
import { checkManualExtensions } from "./extension-assertions.mjs";

const root = fileURLToPath(new URL("../..", import.meta.url));
const manual = resolve(root, ".local/reference-manual");
const handledExtensions = ["Verso.Genre.Manual.Block.table", "Verso.Genre.Manual.Block.paragraph",
  "Verso.Genre.Manual.Block.internalSignature", "Verso.Genre.Manual.Block.fieldSignature",
  "Verso.Genre.Manual.InlineLean.Block.exampleFile", "Verso.Genre.Manual.InlineLean.Block.exampleLeanFile",
  "Manual.example", "Manual.syntax", "Manual.grammar", "Manual.keyword", "Manual.figure",
  "Manual.attr", "Manual.attrs", "Manual.syntaxKind", "Manual.TODO"];
const run = args => execFileSync("lake", args, { cwd: manual, stdio: "inherit" });
run(["build", "CastManualPreview", ...pages.map(page => `+${page.module}:olean`)]);
run(["env", "lean", "--run", "cast-preview/ExportPages.lean"]);
const output = resolve(root, "_out/reference-manual");
await stageProgram("+CastManualPreview:vir", output, { cwd: manual });
await copyFile(resolve(manual, ".cast-preview/widget.irpkg"), resolve(output, "widget.irpkg"));
for (const { name } of pages)
  await copyFile(resolve(manual, `.cast-preview/${name}.json`), resolve(output, `${name}.json`));
// Original images referenced by the selected Monadic Syntax page. Keep their
// published paths; do not fetch web assets or replace them with mock images.
await mkdir(resolve(output, "static/screenshots"), { recursive: true });
for (const name of ["do-return-hl-1.png", "do-return-hl-2.png"])
  await copyFile(resolve(manual, "static/screenshots", name), resolve(output, "static/screenshots", name));
const { runtime } = await openTestRuntime("+CastManualPreview:vir", { cwd: manual });
const staticPages = [], inventory = [], documents = [];
try {
  for (const { name, module } of pages) {
    const input = await readFile(resolve(output, `${name}.json`), "utf8");
    const html = renderToStaticMarkup(runtime.call("CastManualPreview.renderDocument", input));
    staticPages.push(html);
    await writeFile(resolve(output, `${name}.ssr.html`), html);
    const extensions = {};
    const visit = value => {
      if (!value || typeof value !== "object") return;
      const name = value.other?.container?.name;
      if (name) extensions[name] = (extensions[name] ?? 0) + 1;
      Object.values(value).forEach(child => Array.isArray(child) ? child.forEach(visit) : visit(child));
    };
    const document = JSON.parse(input);
    documents.push(document);
    visit(document);
    inventory.push({ module, extensions });
  }
  checkManualExtensions(runtime, documents);
} finally { runtime.dispose(); }
const html = (await readFile(resolve(root, "examples/browser/index.html"), "utf8"))
  .replace('<div id="app">', '<label>Sample page <select id="sample"></select></label><div id="app">')
  .replace('<script type="module"', '<details><summary>React SSR comparison</summary><div id="ssr"></div></details><script type="module"');
await writeFile(resolve(output, "index.html"), html);
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
  page.on("console", message => { if (message.type() === "error") errors.push(message.text()); });
  await page.goto(url);
  const heading = name => page.locator("#app").getByRole("heading", { name, exact: true });
  try { await heading("Introduction").waitFor({ timeout: 10000 }); }
  catch (error) {
    console.error("Initial preview errors:", errors);
    console.error("Initial preview DOM:", await page.locator("#app").textContent());
    throw error;
  }
  await page.getByText("Typographical Conventions", { exact: true }).first().waitFor();
  const debug = page.getByRole("checkbox", { name: "Debug", exact: true });
  assert.equal(await debug.isChecked(), false);
  assert.equal(await page.locator('article [data-verso-render-id]').count(), 0);
  assert.equal(await page.locator('[data-cast-debug]').count(), 0);
  assert.equal(await page.locator('article input[type="checkbox"]').count(), 0, "debug controls belong outside the document");
  for (const name of ["Verso.Genre.Manual.InlineLean.Block.lean",
    "Verso.Genre.Manual.InlineLean.Block.leanOutput", "Manual.proofState", "Manual.example",
    "Verso.Genre.Manual.InlineLean.Block.syntaxError", "Verso.Genre.Manual.Block.docstring",
    "Verso.Genre.Manual.Block.docstringSection", "Verso.Genre.Manual.Block.constructorSignature"])
    assert.equal((await page.locator("#app").textContent()).includes(`[block extension: ${name}]`), false, name);
  assert.ok(await page.locator('pre[data-verso-kind="lean"]').count());
  assert.ok(await page.locator('pre[data-verso-kind="proof-state"]').count());
  for (const name of ["Manual.keywordOf", "Verso.Genre.Manual.InlineLean.Inline.lean",
    "Verso.Genre.Manual.tacticInline", "Verso.Genre.Manual.leanFromMarkdown",
    "Verso.Genre.Manual.deftech", "Verso.Genre.Manual.tech"])
    assert.equal((await page.locator("#app").textContent()).includes(`[inline extension: ${name}]`), false, name);
  const token = page.locator('[data-verso-token="true"]').first();
  assert.ok(await token.count());
  const tokenColor = await token.evaluate(node => getComputedStyle(node).color);
  await page.evaluate(() => document.documentElement.style.setProperty("--vscode-symbolIcon-keywordForeground", "rgb(150, 80, 180)"));
  assert.equal(await token.evaluate(node => getComputedStyle(node).color), "rgb(150, 80, 180)");
  await page.evaluate(() => document.documentElement.style.removeProperty("--vscode-symbolIcon-keywordForeground"));
  assert.equal(await token.evaluate(node => getComputedStyle(node).color), tokenColor);
  const example = page.locator('details[data-verso-kind="example"]').first();
  assert.equal(await example.evaluate(node => node.open), false);
  await example.locator("summary").click();
  assert.equal(await example.evaluate(node => node.open), true);
  await example.getByText("This is an example of an example.", { exact: true }).waitFor();
  await example.evaluate(node => { window.retainedExample = node; });
  await page.evaluate(() => window.manualPreview.editExample("Edited example body, with the disclosure still open."));
  await example.getByText("Edited example body, with the disclosure still open.", { exact: true }).waitFor();
  assert.equal(await example.evaluate(node => node === window.retainedExample && node.open), true,
    "an actual document-content edit must preserve disclosure state and DOM");
  const callsBeforeDebug = await page.evaluate(() => window.manualPreview.calls);
  await debug.check();
  await page.locator('[data-cast-debug]').waitFor();
  await page.waitForFunction(() => document.querySelector('article [data-verso-identity-origin]'));
  assert.equal(await example.evaluate(node => node === window.retainedExample && node.open), true);
  assert.equal(await page.evaluate(() => window.manualPreview.calls), callsBeforeDebug, "debug changes do not request the document again");
  await debug.uncheck();
  await page.locator('[data-cast-debug]').waitFor({ state: "detached" });
  assert.equal(await page.locator('article [data-verso-render-id]').count(), 0);
  await page.evaluate(() => { window.firstHeading = document.querySelector("article h1"); });
  const calls = await page.evaluate(() => window.manualPreview.calls);
  await page.evaluate(() => window.manualPreview.render());
  assert.equal(await page.evaluate(() => window.manualPreview.calls), calls);
  await page.evaluate(() => window.manualPreview.edit("file:///Unrelated.lean"));
  assert.equal(await page.evaluate(() => window.manualPreview.calls), calls);
  await page.evaluate(() => window.manualPreview.edit());
  await page.waitForFunction(expected => window.manualPreview.calls > expected, calls);
  await heading("Introduction").waitFor();
  assert.equal(await page.evaluate(() => window.firstHeading === document.querySelector("article h1")), true);
  assert.equal(await example.evaluate(node => node.open), true, "example disclosure survives a refresh");
  await page.evaluate(() => window.manualPreview.malformed(true));
  await page.getByRole("status").filter({ hasText: "Invalid manual preview:" }).waitFor();
  await heading("Introduction").waitFor();
  await page.evaluate(() => window.manualPreview.malformed(false));
  await page.evaluate(() => {
    window.manualPreview.hold(true);
    return window.manualPreview.edit();
  });
  assert.equal(await page.evaluate(() => window.manualPreview.pendingCount), 1,
    "the stale-reply test must actually hold a request");
  await page.getByRole("status").filter({ hasText: "Loading page…" }).waitFor();
  await page.evaluate(() => {
    window.manualPreview.hold(false);
    return window.manualPreview.select(1);
  });
  await heading("The Empty Type").waitFor();
  assert.equal(await page.evaluate(() => window.manualPreview.abortedCount), 1,
    "switching pages aborts the held request, whose reply deliberately ignores abort");
  assert.equal((await page.locator("#app").textContent()).includes("[inline extension: Verso.Genre.Manual.InlineLean.Inline.name]"), false);
  assert.equal(await page.evaluate(() => window.manualPreview.release()), 1,
    "the stale reply is delivered and its React work drained before checking the page");
  assert.equal(await page.evaluate(() => window.manualPreview.pendingCount), 0);
  await heading("The Empty Type").waitFor();
  await page.screenshot({ path: resolve(output, "empty.png"), fullPage: true });
  await page.evaluate(() => window.manualPreview.select(0));
  await heading("Introduction").waitFor();
  await page.screenshot({ path: resolve(output, "intro.png"), fullPage: true });
  // Reset the edited fixture before comparing the original checked pages.
  await page.reload();
  await heading("Introduction").waitFor();
  for (const [index, sample] of pages.entries()) {
    await page.evaluate(index => window.manualPreview.select(index), index);
    await heading(sample.title).waitFor();
    await page.evaluate(html => { document.getElementById("ssr").innerHTML = html; }, staticPages[index]);
    const comparison = await page.evaluate(() => {
      const shape = node => {
        if (node.nodeType === Node.TEXT_NODE) return node.textContent || null;
        if (node.nodeType !== Node.ELEMENT_NODE) return null;
        const children = [];
        for (const child of node.childNodes) {
          const value = shape(child);
          if (value === null) continue;
          if (typeof value === "string" && typeof children.at(-1) === "string") children[children.length - 1] += value;
          else children.push(value);
        }
        return [node.tagName, children];
      };
      const live = document.querySelector("#app article"), ssr = document.querySelector("#ssr article");
      return { live: shape(live), ssr: shape(ssr),
        fallbacks: [...live.querySelectorAll("code")].map(node => node.textContent)
          .filter(text => /^\[(inline|block) extension:/.test(text)) };
    });
    assert.deepEqual(comparison.live, comparison.ssr, `${sample.module}: live/SSR without parser repair`);
    inventory[index].fallbacks = comparison.fallbacks;
    for (const name of handledExtensions)
      assert.equal(comparison.fallbacks.some(text => text === `[block extension: ${name}]` ||
        text === `[inline extension: ${name}]`), false, `${sample.module}: handled ${name}`);
    if (sample.name === "products") {
      assert.equal(await page.locator("#app table thead th").count(), 5);
      assert.equal(await page.locator("#app table tbody tr").count(), 5);
      assert.equal(await page.locator('#app table th[scope="col"]').count(), 5);
    }
    if (sample.name === "int") assert.ok(await page.locator('#app code[data-verso-math-mode="inline"]').count(),
      "math source remains visible without pretending a typesetter was loaded");
    if (sample.name === "monads") await page.waitForFunction(() => {
      const images = [...document.querySelectorAll("#app img")];
      return images.length === 2 && images.every(image => image.complete && image.naturalWidth > 0);
    });
    if (sample.name === "structures") assert.ok(await page.locator('#app summary code').count(),
      "stored rich example titles render as code, not flattened text");
    console.log(`${sample.module}: ${comparison.fallbacks.length} visible fallbacks; live/SSR PASS`);
    await page.screenshot({ path: resolve(output, `${sample.name}.png`), fullPage: true });
  }
  await writeFile(resolve(output, "coverage.json"), JSON.stringify(inventory, null, 2) + "\n");
  await page.evaluate(() => window.manualPreview.dispose());
  assert.equal(await page.locator("#app").textContent(), "");
  assert.equal(await page.evaluate(() => window.manualPreview.subscriptions), 0);
  assert.deepEqual(errors, []);
  console.log("Real Manual pages / Chromium: decode, render, switching, refresh, stale/error recovery and disposal PASS");
} finally {
  try { await browser?.close(); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
