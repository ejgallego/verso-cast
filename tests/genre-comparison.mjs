import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { renderToStaticMarkup } from "react-dom/server";
import { chromium } from "playwright";
import { openTestRuntime } from "./runtime.mjs";
import { prepareComparison } from "../tools/comparison.mjs";
import { serveDemo } from "../tools/demo.mjs";
import { checkSlidesContract } from "./slides/contract.mjs";

const selected = process.argv.slice(2);
if (selected.some(name => !["blog", "slides"].includes(name))) throw Error("Expected blog or slides");
for (const name of selected.length ? selected : ["blog", "slides"]) {
  const { directory, ...spec } = await prepareComparison(name);
  let browser, server;
  try {
    if (name === "blog") {
      const html = await readFile(resolve(directory, "cast.html"), "utf8");
      assert.match(html, /<details[^>]*data-verso-message-severity="warning"/,
        "summarized Blog output uses a disclosure");
      assert.match(html, /<summary[^>]*>warning<\/summary>/);
      assert.match(html, /Warning &lt;script&gt; &amp; detail/);
      assert.doesNotMatch(html, /<script>|MESSAGE_CHILD_MUST_NOT_RENDER_TWICE/);
      assert.match(html, /<h2[^>]*data-verso-kind="docstring-heading"[^>]*>A <strong>docstring heading<\/strong><\/h2>/,
        "Post docstring title becomes a rich heading");
      assert.match(html, /<h6[^>]*>Deep docstring heading<\/h6>/);
      assert.equal((html.match(/Docstring body &lt;escaped&gt;/g) ?? []).length, 1);
      const { runtime } = await openTestRuntime(spec.target, { cwd: spec.cwd });
      try {
        const page = renderToStaticMarkup(runtime.call("VersoCastTests.Blog.renderPage"));
        assert.match(page, /class="[^"]*page-panel/);
        assert.match(page, /class="page-badge"/);
        assert.match(page, /Blog.component:Missing/);
        assert.match(page, /Fallback children/);
        assert.match(page, /<h1[^>]*data-verso-kind="docstring-heading"[^>]*data-verso-change="changed"[^>]*data-verso-focus="cursor"[^>]*>Page <em>docstring<\/em><\/h1>/,
          "Page heading retains source, focus and change attributes");
        for (const text of ["Page section body", "Missing title survives", "Malformed body survives", "Unsupported level survives"])
          assert.equal((page.match(new RegExp(text, "g")) ?? []).length, 1, text);
        assert.equal((page.match(/\[block extension: Blog.docstringSection\]/g) ?? []).length, 3,
          "missing, empty and out-of-range titles retain visible fallback");
        assert.doesNotMatch(page, /<h7/);
        for (const [mode, expected] of [[0n, 2n], [1n, 2n], [2n, 1n], [3n, 0n]])
          assert.equal(runtime.call("VersoCastTests.Blog.sectionWork", mode), expected,
            "each selected or fallback child renders once");
      } finally { runtime.dispose(); }
    }
    if (name === "slides") {
      const { runtime: contract } = await openTestRuntime("+CastSlides.Contract:vir", { cwd: spec.cwd });
      try { checkSlidesContract(contract); } finally { contract.dispose(); }
    }
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
      const output = page.locator('#live details[data-verso-message-severity="warning"]');
      assert.equal(await output.evaluate(node => node.open), false);
      assert.equal(await page.locator('#live details[data-verso-message-severity="info"]').count(), 0,
        "unsummarized output stays expanded");
      await output.locator("summary").click();
      assert.equal(await output.evaluate(node => node.open), true);
      await output.evaluate(node => { window.retainedBlogOutput = node; });
      await page.evaluate(() => {
        window.retainedBlogHeading = document.querySelector('#live [data-verso-kind="docstring-heading"]');
      });
      const commits = await page.evaluate(() => window.genreComparison.commits);
      await page.locator("#redraw").click();
      await page.waitForFunction(previous => window.genreComparison.commits > previous, commits);
      assert.equal(await output.evaluate(node => node === window.retainedBlogOutput && node.open), true,
        "redraw preserves the disclosure DOM node and its open state");
      assert.equal(await page.evaluate(() => window.retainedBlogHeading ===
        document.querySelector('#live [data-verso-kind="docstring-heading"]')), true,
        "redraw retains the docstring heading DOM node");
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
    finally { if (server) await new Promise(resolve => server.close(resolve)); }
  }
}
