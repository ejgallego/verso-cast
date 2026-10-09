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
  assert.match(html, /<table[^>]*data-verso-kind="table"/);
  assert.match(html, /<thead><tr/);
  assert.match(html, /<tbody><tr/);
  assert.match(html, /scope="col"/);
  for (const text of ["Internal.name : Nat", "private field : Nat", "internal documentation",
    "field documentation", "Inherited from", "Parent", "stdin", "input &lt;text&gt;", "File: Example.lean"])
    assert.ok(html.includes(text), text);
  assert.equal((html.match(/\[block extension: Verso.Genre.Manual.Block.table\]/g) ?? []).length, 1,
    "zero-column table keeps its children in visible fallback");
  for (const [count, columns, expected] of [[4n, 2n, 4n], [4n, 4n, 4n], [4n, 0n, 0n], [4n, 3n, 0n], [0n, 2n, 0n]])
    assert.equal(runtime.call("VersoCastTests.Manual.tableWork", count, columns), expected,
      "valid cells render once; invalid shapes do not render any cells");
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
