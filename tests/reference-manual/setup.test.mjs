import test from "node:test";
import assert from "node:assert/strict";
import { patchPage } from "../../tools/setup-reference-manual.mjs";

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
