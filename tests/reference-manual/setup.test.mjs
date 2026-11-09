import test from "node:test";
import assert from "node:assert/strict";
import { patchPage, refreshPreview } from "../../tools/setup-reference-manual.mjs";
import { build } from "esbuild";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readFile, rm, writeFile, access } from "node:fs/promises";
import { resolve } from "node:path";
import { tmpdir } from "node:os";

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

test("managed updates preflight edits before any writes, then recover and remain idempotent", async () => {
  const directory = await mkdtemp(resolve(tmpdir(), "cast-setup-preflight-"));
  const hash = content => createHash("sha256").update(content).digest("hex");
  const config = 'lean_lib CastManualPreview where\n  srcDir := "cast-preview"\n';
  const page = "show_panel_widgets [local Lean.Vir.Infoview.widget with CastManualPreview.preparedWidgetProps]\n-- my page edit\n";
  const files = {
    "lakefile.lean": config,
    "Manual/Page.lean": page,
    "cast-preview/CastManualPreview.lean": "old host",
    "cast-preview/CastManualPreview/Extensions.lean": "my helper edit",
    "cast-preview/CastManualPreview/Server.lean": "old server",
  };
  const state = { revision: "fixture", pages: 1, lakefile: hash(config), sources: {
    "CastManualPreview.lean": hash("old host"),
    "CastManualPreview/Extensions.lean": hash("old extension"),
    "CastManualPreview/Server.lean": hash("old server"),
  } };
  files[".cast-preview.json"] = JSON.stringify(state, null, 2) + "\n";
  const helpers = new Map([["CastManualPreview.lean", "new host"],
    ["CastManualPreview/Extensions.lean", "new extension"], ["Widget.mjs", "new bundle"]]);
  try {
    await mkdir(resolve(directory, "Manual"), { recursive: true });
    await mkdir(resolve(directory, "cast-preview/CastManualPreview"), { recursive: true });
    for (const [path, content] of Object.entries(files)) await writeFile(resolve(directory, path), content);
    await assert.rejects(refreshPreview(directory, state, helpers), /Local helper edits/);
    for (const [path, content] of Object.entries(files))
      assert.equal(await readFile(resolve(directory, path), "utf8"), content, `${path}: unchanged after refusal`);
    await assert.rejects(access(resolve(directory, "cast-preview/Widget.mjs")), { code: "ENOENT" });
    assert.equal(state.lakefile, hash(config), "input ownership state is not mutated");
    await writeFile(resolve(directory, "cast-preview/CastManualPreview/Extensions.lean"), "old extension");
    const next = await refreshPreview(directory, state, helpers);
    assert.match(await readFile(resolve(directory, "lakefile.lean"), "utf8"), /needs := #\[castPreviewWidget\]/);
    assert.match(await readFile(resolve(directory, "Manual/Page.lean"), "utf8"), /local CastManualPreview.widget[^]*my page edit/);
    assert.equal(next.lakefile, hash(await readFile(resolve(directory, "lakefile.lean"))));
    assert.equal(next.sources["CastManualPreview/Server.lean"], undefined);
    await assert.rejects(access(resolve(directory, "cast-preview/CastManualPreview/Server.lean")), { code: "ENOENT" });
    assert.deepEqual(await refreshPreview(directory, next, helpers), next, "second update is idempotent");
    await writeFile(resolve(directory, "lakefile.lean"), "my config edit");
    await assert.rejects(refreshPreview(directory, next, helpers), /refusing to overwrite its configuration/);
  } finally { await rm(directory, { recursive: true, force: true }); }
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
