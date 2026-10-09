import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { copyFile, mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { chromium } from "playwright";
import { createElement, Children } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { build } from "esbuild";
import { openTestRuntime, query, root } from "./runtime.mjs";
import { stageProgram, serveDemo } from "../tools/demo.mjs";

execFileSync("lake", ["build", "cast-standard-html"], { cwd: root, stdio: "inherit" });
const standard = execFileSync(query("cast-standard-html"), [], { encoding: "utf8" });
const versoHasBlockFootnoteInParagraph = (standard.match(/<p\b[^>]*>[\s\S]*?<\/p>/g) || [])
  .some(paragraph => paragraph.includes("<details"));
const { runtime } = await openTestRuntime("+VersoCastTests.Offline:vir");
let browser;
let server;
try {
  const View = runtime.call("VersoCastTests.Offline.View", "ssr-");
  const cast = renderToStaticMarkup(createElement(View));
  const frozenStyle = Object.freeze({ color: "rgb(1, 2, 3)" });
  const probe = () => Children.toArray(runtime.call("VersoCastTests.Offline.propsProbe", frozenStyle).props.children);
  const first = probe();
  const second = probe();
  assert.notEqual(first[0].props, second[0].props, "renderer allocates fresh props");
  for (const nodes of [first, second]) {
    for (const node of nodes) {
      assert.equal(node.props.style, frozenStyle, "native style identity preserved");
      assert.equal(node.props.className, "caller-class", "explicit attributes override defaults");
    }
    assert.equal(nodes[0].props.id, "caller-id");
    assert.equal(nodes[0].props["data-verso-changed-block-count"], "0", "diagnostic fields reserved");
    assert.ok(nodes[1].key.endsWith("math-key"), "renderer math key reserved");
    assert.equal(nodes[1].props["data-verso-math-mode"], "inline");
  }
  assert.deepEqual(frozenStyle, { color: "rgb(1, 2, 3)" });
  for (const count of [0n, 1n, 16n, 128n]) {
    assert.equal(runtime.call("VersoCastTests.Offline.extensionWork", count), 2n * count,
      "one dispatch per visible extension; hidden descendants skipped");
  }
  assert.ok(!cast.includes('id="vir-verso-document"'), "no shared fixed document id");
  assert.ok(cast.includes('data-cast-initial="ready"'), "React SSR evaluates the extension component's initial hook state");
  assert.ok(cast.includes('data-cast-inline-visits="1"'), "hidden inline children are not eagerly rendered");
  assert.ok(cast.includes('data-cast-block-visits="2"'), "hidden block children are not eagerly rendered");
  for (const html of [cast, standard]) {
    assert.ok(html.includes("&lt;script&gt;unsafe()&lt;/script&gt;"), "escaped inline code");
    assert.ok(html.includes("&lt;escaped&gt;"), "escaped block code");
    assert.ok(!html.includes("HIDDEN"), "extension can omit its children");
  }
  const directory = resolve(root, "_out/comparison");
  await mkdir(directory, { recursive: true });
  await writeFile(resolve(directory, "cast.html"), cast);
  await writeFile(resolve(directory, "verso.html"), standard);
  await stageProgram("+VersoCastTests.Offline:vir", directory);
  await copyFile(resolve(root, "web/fixture.svg"), resolve(directory, "fixture.svg"));
  await build({
    absWorkingDir: root, entryPoints: ["web/comparison.mjs"],
    outfile: resolve(directory, "comparison.js"), bundle: true, format: "esm", target: "es2022",
  });
  const comparison = `<!doctype html><html lang="en"><meta charset="utf-8">
    <title>Cast / Verso / live React comparison</title>
    <style>
      body { margin: 24px; font: 16px/1.5 system-ui; color: #24292f; }
      main { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 24px; }
      main > div { min-width: 0; }
      pre { white-space: pre-wrap; } img { vertical-align: middle; }
      mark { cursor: pointer; }
      #live-status { font-size: 13px; } button { margin-bottom: 12px; }
      @media (max-width: 1100px) { main { grid-template-columns: 1fr; } }
    </style>
    <h1>Same Verso document: live React, React SSR, Verso HTML</h1>
    <p>Illustrative comparison: layout, wrappers, CSS and fallback wording may differ.
    Math is source-preserving; no typesetter is loaded. The live view uses the same Lean component as SSR.</p>
    <p>Validity note: ${versoHasBlockFootnoteInParagraph ? "Verso's current footnote HTML is repaired by the browser." : "No block footnote in Verso paragraph source."}
    Cast uses inline markup; its SSR and live document structures are checked for agreement.</p>
    <main><div><h2>Cast → live React</h2><p id="live-status">Loading live view…</p>
      <button id="live-update">Redraw live view</button><div id="live"></div></div>
    <div><h2>Cast → React SSR</h2><div id="cast">${cast}</div></div>
    <div><h2>Verso → Output.Html.asString</h2><div id="verso">${standard}</div></div></main>
    <script type="module" src="comparison.js"></script>
    </html>`;
  const output = resolve(directory, "index.html");
  await writeFile(output, comparison);
  browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1800, height: 1100 } });
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  page.on("console", message => { if (message.type() === "error") errors.push(message.text()); });
  const served = await serveDemo(directory);
  server = served.server;
  await page.goto(served.url);
  await page.locator("#live article").waitFor();
  const summaries = await page.evaluate(() => {
    function summary(id) {
      const root = document.getElementById(id);
      const text = element => element.textContent.replace(/\s+/g, "");
      const collect = (selector, project = text) => [...root.querySelectorAll(selector)].map(project);
      // Whitelist semantic observations; deliberately not a DOM/layout snapshot.
      return {
        // Document-instance namespaces differ; logical anchors are the same.
        headings: collect("h1,h2,h3,h4,h5,h6", e => [e.tagName, text(e), e.id.replace(/^(live|ssr|verso)-/, "")]),
        emphasis: collect("em"), strong: collect("strong"),
        links: collect("a", e => [e.getAttribute("href"), text(e)]),
        images: collect("img", e => [e.getAttribute("src"), e.getAttribute("alt")]),
        codeBlocks: collect("pre", e => e.textContent.trim()),
        lists: collect("ul,ol", e => [e.tagName, e.getAttribute("start"), text(e)]),
        descriptions: collect("dt,dd", e => [e.tagName, text(e)]),
        quotations: collect("blockquote"), footnotes: collect(".vir-verso-footnote,details.footnote"),
        highlights: collect("mark"), notices: collect("aside"),
        sections: collect("[data-fixture-section]", e => e.getAttribute("data-fixture-section")),
        math: collect("code[data-verso-math-mode],code.math", e => [
          e.getAttribute("data-verso-math-mode") || (e.classList.contains("inline") ? "inline" : "display"),
          text(e)]),
        content: text(root).replace(/\[(?:inlineextension:unknown|blockextension:unknown|unsupportedinline|unsupportedblock)\]/g, ""),
        unsupportedChildren: ["Unsupportedinlinechild", "Unsupportedblockchild"].map(t => text(root).includes(t)),
      };
    }
    return { live: summary("live"), cast: summary("cast"), verso: summary("verso") };
  });
  // Cast SSR and live React must agree before any interaction. Compare parsed
  // element/text structure, ignoring comments and empty text nodes, not CSS.
  const structures = await page.evaluate(() => {
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
    return {
      live: shape(document.querySelector("#live > div")),
      ssr: shape(document.querySelector("#cast > div")),
      footnoteInsideLiveParagraph: !!document.querySelector("#live p .vir-verso-footnote"),
      footnoteInsideSsrParagraph: !!document.querySelector("#cast p .vir-verso-footnote"),
      versoDetailsInsideParagraph: !!document.querySelector("#verso p details"),
    };
  });
  assert.deepEqual(structures.live, structures.ssr, "Cast SSR must not need HTML parser repair");
  assert.equal(structures.footnoteInsideLiveParagraph, true);
  assert.equal(structures.footnoteInsideSsrParagraph, true);
  const ids = await page.locator("[id]").evaluateAll(nodes => nodes.map(node => node.id));
  assert.equal(new Set(ids).size, ids.length, "comparison instances have unique DOM ids");
  // Observe the reference bug without requiring future Verso versions to retain it.
  structures.versoParserRepair = versoHasBlockFootnoteInParagraph && !structures.versoDetailsInsideParagraph;
  // Each backend must preserve the fixture's essentials. Their differences
  // are reported, not used as a universal backend-equivalence contract.
  for (const [backend, summary] of Object.entries(summaries)) {
    assert.deepEqual(summary.sections, ["root", "child"], `${backend}: metadata`);
    assert.deepEqual(summary.headings, [["H1", "1.Offlinecomparison", "section-root"],
      ["H2", "1.1.Childsection", "section-child"]]);
    assert.deepEqual(summary.links, [["https://lean-lang.org/", "Lean"]]);
    assert.deepEqual(summary.images, [["fixture.svg", "Fixture image"]]);
    assert.deepEqual(summary.lists, [["UL", null, "Unordereditem"], ["OL", "3", "Ordereditem"]]);
    assert.deepEqual(summary.math, [["inline", "x<y"], ["display", "x^2"]]);
    assert.deepEqual(summary.emphasis, ["emphasis", "nestedemphasis"]);
    assert.deepEqual(summary.strong, ["strong"]);
    assert.deepEqual(summary.codeBlocks, ["#check Nat\n-- <escaped>"]);
    assert.deepEqual(summary.descriptions, [["DT", "Term"], ["DD", "Definition"]]);
    assert.deepEqual(summary.quotations, ["Quotation"]);
    assert.deepEqual(summary.footnotes, ["[note]Footnotebody"]);
    assert.deepEqual(summary.highlights, ["Highlightednestedemphasis"]);
    assert.deepEqual(summary.notices, ["NoticechildNestednotice", "Nestednotice"]);
    assert.deepEqual(summary.unsupportedChildren, [true, true]);
    assert.ok(summary.content.includes("Concatenatedparagraph"));
    assert.ok(summary.content.includes("Childcontent"));
  }
  const differingObservations = Object.keys(summaries.cast).filter(key =>
    JSON.stringify(summaries.cast[key]) !== JSON.stringify(summaries.verso[key]));
  await writeFile(resolve(directory, "observations.json"),
    JSON.stringify({ ...summaries, differingObservations, validity: structures }, null, 2) + "\n");
  await page.locator("#live mark").click();
  await page.locator('#live mark[data-cast-initial="clicked"]').waitFor();
  await page.evaluate(() => { window.retainedMark = document.querySelector("#live mark"); });
  for (let update = 0; update < 20; update++) {
    await page.evaluate(() => window.castComparison.update());
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    assert.equal(await page.locator("#live mark").getAttribute("data-cast-initial"), "clicked");
    assert.equal(await page.evaluate(() => window.retainedMark === document.querySelector("#live mark")), true);
  }
  assert.deepEqual(errors, [], "live React reports no nesting/runtime errors");
  console.log(`Offline fixture checks PASS; differing observations: ${differingObservations.join(", ") || "none"}`);
  console.log(`Illustrative comparison: ${pathToFileURL(output).href}`);
  await page.screenshot({ path: resolve(directory, "comparison.png"), fullPage: true });
  await page.evaluate(() => window.castComparison.dispose());
  assert.equal(await page.locator("#live").textContent(), "");
} finally {
  try { await browser?.close(); }
  finally {
    try { if (server) await new Promise(resolve => server.close(resolve)); }
    finally { runtime.dispose(); }
  }
}
