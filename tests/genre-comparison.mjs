import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { copyFile, mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { chromium } from "playwright";
import { build } from "esbuild";
import { openTestRuntime, query, root } from "./runtime.mjs";
import { stageProgram, serveDemo } from "../tools/demo.mjs";
import { checkSlidesContract } from "./slides/contract.mjs";

const cases = {
  blog: { cwd: root, target: "+VersoCastTests.Blog:vir", standard: "cast-blog-html",
    entry: "VersoCastTests.Blog.View", title: "Post", note: "Typed Page/Post extensions; no website theme, scripting or reference traversal." },
  slides: { cwd: resolve(root, "tests/slides"), target: "+CastSlides:vir", standard: "standard-slides",
    entry: "CastSlides.View", title: "Slides", note: "Inspectable whole-deck preview, not a Reveal.js presenter. Notes/fragments remain visible; navigation highlights source headings." },
};
const selected = process.argv.slice(2);
if (selected.some(name => !cases[name])) throw Error("Expected blog or slides");
for (const name of selected.length ? selected : Object.keys(cases)) {
  const spec = cases[name];
  execFileSync("lake", ["build", spec.standard], { cwd: spec.cwd, stdio: "inherit" });
  const standard = execFileSync(query(spec.standard, { cwd: spec.cwd }), [], { cwd: spec.cwd, encoding: "utf8" });
  const { runtime } = await openTestRuntime(spec.target, { cwd: spec.cwd });
  let browser, server;
  try {
    const View = runtime.call(spec.entry, ...(name === "blog" ? ["ssr-"] : []));
    const cast = renderToStaticMarkup(createElement(View));
    if (name === "blog") {
      const page = renderToStaticMarkup(runtime.call("VersoCastTests.Blog.renderPage"));
      assert.match(page, /class="[^"]*page-panel/);
      assert.match(page, /class="page-badge"/);
      assert.match(page, /Blog.component:Missing/);
      assert.match(page, /Fallback children/);
    }
    if (name === "slides") {
      const { runtime: contract } = await openTestRuntime("+CastSlides.Contract:vir", { cwd: spec.cwd });
      try { checkSlidesContract(contract); } finally { contract.dispose(); }
    }
    const directory = resolve(root, "_out/genres", name);
    await stageProgram(spec.target, directory, { cwd: spec.cwd });
    if (name === "slides") {
      await mkdir(resolve(directory, "images"), { recursive: true });
      await copyFile(resolve(spec.cwd, "CastSlides/badge.svg"), resolve(directory, "images/badge.svg"));
    }
    await build({ absWorkingDir: root, entryPoints: ["tests/browser/genre-comparison.mjs"],
      outfile: resolve(directory, "comparison.js"), bundle: true, format: "esm", target: "es2022" });
    await writeFile(resolve(directory, "cast.html"), cast);
    await writeFile(resolve(directory, "verso.html"), standard);
    await writeFile(resolve(directory, "index.html"), `<!doctype html><html lang="en">
      <meta charset="utf-8"><title>${spec.title} comparison</title>
      <style>body{margin:24px;font:16px/1.5 system-ui;color:#24292f}
      main{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:24px}main>div{min-width:0}
      pre{white-space:pre-wrap}nav{display:flex;gap:12px;margin:12px 0}.post-callout{border-left:3px solid #0969da;padding:8px}
      .post-badge{font-weight:600}.str,.num{color:#0a7a48}.bool,.null{color:#8250df}
      .hover-container{display:none}.r-hstack{display:flex;align-items:center;gap:24px}
      [data-slide-vertical="true"]{border-left:3px solid #0969da;padding-left:12px}
      @media(max-width:1100px){main{grid-template-columns:1fr}}</style>
      <body data-entry="${spec.entry}" data-fixture="${name}"><h1>${spec.title}: live React / React SSR / Verso HTML</h1>
      <p>${spec.note} Layout and wrappers may differ; math is source-preserving.</p>
      <main><div><h2>Live Cast</h2><button id="redraw">Redraw</button><div id="live"></div></div>
      <div><h2>Cast SSR</h2><div id="cast">${cast}</div></div>
      <div><h2>Verso Output.Html.asString</h2><div id="verso">${standard}</div></div></main>
      <script type="module" src="comparison.js"></script></body></html>`);
    browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1800, height: 1100 } });
    const errors = [];
    page.on("pageerror", error => errors.push(error.message));
    page.on("console", message => { if (message.type() === "error") errors.push(message.text()); });
    ({ server } = await serveDemo(directory));
    await page.goto(`http://127.0.0.1:${server.address().port}/`);
    await page.locator("#live article").waitFor();
    const observations = await page.evaluate(() => {
      const normalize = text => text.replace(/\s+/g, " ").trim();
      const summarize = id => {
        const root = document.getElementById(id);
        const collect = (selector, project = node => normalize(node.textContent)) => [...root.querySelectorAll(selector)].map(project);
        return {
          headings: collect("h1,h2,h3,h4,h5,h6", node => [node.tagName, normalize(node.textContent)]),
          byline: collect("[data-post-byline]"),
          links: collect("a", node => [node.getAttribute("href"), normalize(node.textContent)]),
          images: collect("img", node => [node.getAttribute("src"), node.getAttribute("alt"), node.style.width, node.style.height]),
          code: [...root.querySelectorAll("pre,code.hl.lean.block")]
            .filter(node => !node.parentElement.closest("pre"))
            .map(node => {
              const copy = node.cloneNode(true);
              // Stored hover messages are not visible code; Cast's initial
              // token presentation deliberately does not implement hovers.
              copy.querySelectorAll(".hover-container,.hover-info,.tactic-state").forEach(node => node.remove());
              return copy.textContent.trim();
            }),
          emphasis: collect("em"), notes: collect("aside.notes"),
          fragments: collect(".fragment", node => [normalize(node.textContent), node.getAttribute("data-fragment-index")]),
          nested: collect(".nested-one.nested-two"),
          tables: collect("table", table => [...table.querySelectorAll("tr")].map(row => [...row.children].map(cell => [cell.tagName, normalize(cell.textContent)]))),
        };
      };
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
      return { live: summarize("live"), cast: summarize("cast"), verso: summarize("verso"),
        liveShape: shape(document.querySelector("#live article")), castShape: shape(document.querySelector("#cast article")) };
    });
    assert.deepEqual(observations.liveShape, observations.castShape, "live/SSR needs no HTML parser repair");
    assert.deepEqual(observations.live, observations.cast, "live/SSR semantic observations");
    assert.deepEqual(observations.live, observations.verso, "illustrative fixture essentials survive both backends");
    assert.doesNotMatch(await page.locator("#live").textContent(), /\[(inline|block) extension:/);
    const ids = await page.locator("[id]").evaluateAll(nodes => nodes.map(node => node.id));
    assert.equal(new Set(ids).size, ids.length, "comparison instances have distinct DOM ids");
    if (name === "blog") {
      assert.deepEqual(observations.live.byline, ["2026-10-10 · Cast fixture author"]);
      assert.deepEqual(observations.live.links, [["https://lean-lang.org", "links"]]);
      assert.ok(await page.locator("#live span.str").count());
      assert.equal(await page.locator("#live .post-badge").textContent(), "typed extensions");
      assert.ok(observations.live.code.includes("hello <escaped>"));
    } else {
      assert.deepEqual(observations.live.fragments, [["First fragment.", "2"], ["Second fragment.", "2"], ["inline emphasis", null]]);
      assert.deepEqual(observations.live.nested, ["Nested decoration."]);
      assert.equal(await page.locator('#live [data-slide-vertical="true"]').count(), 1);
      assert.equal(await page.locator('#live [data-background-color="#e9f5ef"]').count(), 1);
      assert.equal(await page.locator("#live .slide-badge").textContent(), "class role");
      assert.equal(await page.locator("#live .r-hstack").evaluate(node => getComputedStyle(node).display), "flex",
        "authored layout classes are not overridden by a default inline grid");
      assert.ok(observations.live.code.includes('const message = "<escaped>";'));
      assert.ok(await page.locator("#live [data-verso-token]").count(), "real Lean tokens use shared highlighting");
      assert.equal((await page.locator("#live .command-output").textContent()).trim(), "5",
        "real elaborated command output remains visible");
      assert.deepEqual(observations.live.images, [["images/badge.svg", "Cast badge", "80px", "32px"]]);
      await page.waitForFunction(() => {
        const image = document.querySelector("#live .slide-image");
        return image?.complete && image.naturalWidth === 80;
      });
      await page.evaluate(() => { window.retainedHeading = document.querySelector("#live h2"); });
      await page.getByRole("button", { name: "Next", exact: true }).first().click();
      await page.locator('#live output[data-slide-selected="1"]').waitFor();
      assert.equal(await page.locator('#live [data-verso-focus="cursor"]').textContent(), "Introduction");
      await page.locator("#redraw").click();
      assert.equal(await page.locator("#live output").textContent(), "Slide 1");
      assert.equal(await page.evaluate(() => window.retainedHeading === document.querySelector("#live h2")), true);
      await page.getByRole("button", { name: "Previous", exact: true }).first().click();
      await page.locator('#live output[data-slide-selected="0"]').waitFor();
    }
    assert.deepEqual(errors, [], "React/runtime/nesting errors");
    await writeFile(resolve(directory, "observations.json"), JSON.stringify(observations, null, 2) + "\n");
    await page.screenshot({ path: resolve(directory, "comparison.png"), fullPage: true });
    await page.evaluate(() => window.genreComparison.dispose());
    assert.equal(await page.locator("#live").textContent(), "");
    console.log(`${spec.title}: live/SSR structure, Verso essentials, interaction and disposal PASS`);
  } finally {
    try { await browser?.close(); }
    finally { try { if (server) await new Promise(resolve => server.close(resolve)); } finally { runtime.dispose(); } }
  }
}
