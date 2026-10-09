import assert from "node:assert/strict";
import { renderToStaticMarkup } from "react-dom/server";
import { openTestRuntime } from "./runtime.mjs";

const { runtime } = await openTestRuntime("+VersoCastTests.Manual:vir");
try {
  const html = renderToStaticMarkup(runtime.call("VersoCastTests.Manual.render"));
  assert.match(html, /def x := &quot;&lt;script&gt;&quot;/);
  assert.match(html, /&lt;img src=x&gt;/);
  assert.doesNotMatch(html, /<script>|<img|MUST_NOT_RENDER_TWICE/);
  for (const severity of ["error", "warning", "info"])
    assert.ok(html.includes(`data-verso-message-severity="${severity}"`));
  assert.match(html, /<details[^>]*data-verso-message-severity="warning"/);
  assert.match(html, /data-verso-focus="cursor"/);
  assert.ok(html.includes("malformed source stays visible"));
  assert.ok(html.includes("[block extension: Verso.Genre.Manual.InlineLean.Block.lean]"));
  assert.ok(html.includes("[block extension: Unknown.manual]"));
  assert.ok(html.includes("unknown children survive"));
  console.log("Manual SSR: code/output, severity, summary, escaping, single render, markers and fallback PASS");
} finally { runtime.dispose(); }
