import { execFileSync } from "node:child_process";
import { copyFile, mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { build } from "esbuild";
import { openTestRuntime, query, root } from "../tests/runtime.mjs";
import { stageProgram } from "./demo.mjs";

const cases = {
  blog: { cwd: root, target: "+VersoCastTests.Blog:vir", standard: "cast-blog-html",
    entry: "VersoCastTests.Blog.View", title: "Post", note: "Typed Page/Post extensions; no website theme, scripting or reference traversal." },
  slides: { cwd: resolve(root, "tests/slides"), target: "+CastSlides:vir", standard: "standard-slides",
    entry: "CastSlides.View", title: "Slides", note: "Inspectable whole-deck preview, not a Reveal.js presenter. Notes/fragments remain visible; navigation highlights source headings." },
};

async function prepareCoreComparison() {
  execFileSync("lake", ["build", "cast-standard-html"], { cwd: root, stdio: "inherit" });
  const standard = execFileSync(query("cast-standard-html"), [], { encoding: "utf8" });
  const versoHasBlockFootnoteInParagraph = (standard.match(/<p\b[^>]*>[\s\S]*?<\/p>/g) || [])
    .some(paragraph => paragraph.includes("<details"));
  const { runtime } = await openTestRuntime("+VersoCastTests.Offline:vir");
  try {
    const View = runtime.call("VersoCastTests.Offline.View", "ssr-");
    const cast = renderToStaticMarkup(createElement(View));
    const directory = resolve(root, "_out/comparison");
    await mkdir(directory, { recursive: true });
    await writeFile(resolve(directory, "cast.html"), cast);
    await writeFile(resolve(directory, "verso.html"), standard);
    await stageProgram("+VersoCastTests.Offline:vir", directory);
    await copyFile(resolve(root, "tests/browser/fixture.svg"), resolve(directory, "fixture.svg"));
    await build({
      absWorkingDir: root, entryPoints: ["tests/browser/comparison.mjs"],
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
    await writeFile(resolve(directory, "index.html"), comparison);
    return { directory, cast, standard, versoHasBlockFootnoteInParagraph };
  } finally { runtime.dispose(); }
}

async function prepareGenreComparison(name) {
  const spec = cases[name];
  if (!spec) throw Error("Expected core, blog or slides");
  execFileSync("lake", ["build", spec.standard], { cwd: spec.cwd, stdio: "inherit" });
  const standard = execFileSync(query(spec.standard, { cwd: spec.cwd }), [], { cwd: spec.cwd, encoding: "utf8" });
  const { runtime } = await openTestRuntime(spec.target, { cwd: spec.cwd });
  try {
    const View = runtime.call(spec.entry, ...(name === "blog" ? ["ssr-"] : []));
    const cast = renderToStaticMarkup(createElement(View));
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
    return { ...spec, directory };
  } finally { runtime.dispose(); }
}

// Both the demo server and browser acceptance use these exact generated views.
// The SSR runtime is disposed here; the browser creates its own retained runtime.
export function prepareComparison(name = "core") {
  if (!["core", "blog", "slides"].includes(name)) throw Error("Expected core, blog or slides");
  return name === "core" ? prepareCoreComparison() : prepareGenreComparison(name);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { directory } = await prepareComparison(process.argv[2]);
  console.log(`Generated comparison: ${directory}`);
}
