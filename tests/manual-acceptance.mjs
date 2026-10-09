import assert from "node:assert/strict";
import { renderToStaticMarkup } from "react-dom/server";
import { Children, isValidElement } from "react";
import { openTestRuntime } from "./runtime.mjs";

const { runtime } = await openTestRuntime("+VersoCastTests.Manual:vir");
try {
  const html = renderToStaticMarkup(runtime.call("VersoCastTests.Manual.render"));
  assert.match(html.replace(/<[^>]*>/g, ""), /def x := &quot;&lt;script&gt;&quot;/);
  assert.match(html, /data-verso-token="true"/);
  assert.match(html, /--vscode-symbolIcon-keywordForeground/);
  assert.match(html, /--vscode-editor-font-size/);
  assert.match(html, /&lt;inline&gt;/);
  assert.match(html, /aria-label="Fields"/);
  assert.match(html, /documentation children/);
  assert.match(html, /bad &lt;source&gt;/);
  assert.match(html, /expected term/);
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
  const keys = (node, found = []) => {
    if (isValidElement(node)) {
      found.push([node.type, node.key]);
      Children.forEach(node.props.children, child => keys(child, found));
    }
    return found;
  };
  const normal = runtime.call("VersoCastTests.Manual.renderDebug", false);
  const debug = runtime.call("VersoCastTests.Manual.renderDebug", true);
  const normalHtml = renderToStaticMarkup(normal);
  const debugHtml = renderToStaticMarkup(debug);
  assert.deepEqual(keys(normal), keys(debug), "debug must not change React identities");
  assert.doesNotMatch(normalHtml, /data-verso-(render-id|identity-origin|changed-block-count|focus-block)=|title=/);
  for (const marker of ["data-verso-block", "data-verso-part", "data-verso-list-item", "data-verso-focus", "data-verso-change"])
    assert.ok(normalHtml.includes(marker), `navigation marker ${marker} must survive debug-off`);
  assert.match(debugHtml, /data-verso-render-id=/);
  assert.match(debugHtml, /data-verso-identity-origin="positional"/);
  assert.match(debugHtml, /data-verso-changed-block-count="1"/);
  assert.match(debugHtml, /title="render path:/);
  console.log("Manual SSR: code/output, severity, summary, escaping, single render, markers and fallback PASS");
  console.log("Debug defaults: inspection opt-in, stable keys and navigation/change markers PASS");
} finally { runtime.dispose(); }
