import test from "node:test";
import assert from "node:assert/strict";
import { patchPage } from "../../tools/setup-reference-manual.mjs";
import { build } from "esbuild";

test("widget registration precedes #doc, and its import stays in the header", () => {
  const page = "/- license -/\nimport Manual.Meta\nopen Verso Genre\n\n#doc (Manual) \"Intro\" =>\nHello\n";
  const result = patchPage(page);
  assert.match(result, /import CastManualPreview\nimport Manual.Meta/);
  assert.match(result, /show_panel_widgets[^\n]*\n\n#doc \(Manual\) "Intro" =>\nHello\n$/);
  assert.throws(() => patchPage(result), /already has/);
});

test("helper modules and documents of other genres stay untouched", () => {
  for (const source of ["import Manual.Meta\ndef helper := 1\n", "import Verso\n#doc (BlogPost) \"Post\" =>\ntext\n"])
    assert.equal(patchPage(source), source);
  assert.throws(() => patchPage('#doc (Manual) "Missing header" =>\ntext\n'), /import header/);
});

test("native editor wrapper imports only the public Infoview entry point", async () => {
  await build({ entryPoints: ["tests/reference-manual/widget.mjs"],
    bundle: true, format: "esm", write: false,
    // Link the real Infoview exports; only the registered VIR shell is supplied
    // by its hash at runtime. An unsupported deep import/export fails here.
    plugins: [{ name: "registered-shell", setup(builder) {
      builder.onResolve({ filter: /^__VIR_SHELL__$/ }, () => ({ path: "shell", namespace: "fixture" }));
      builder.onLoad({ filter: /.*/, namespace: "fixture" }, () => ({ contents: "export default function Shell() {}" }));
    } }] });
});
