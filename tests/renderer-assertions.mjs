import assert from "node:assert/strict";
import { Children, isValidElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";

// Actual React elements, not a shadow VDOM or a replacement host implementation.
export function checkRenderer(render) {
  function paragraphs(node, found = new Map()) {
    if (!isValidElement(node)) return found;
    if (node.type === "p") found.set(renderToStaticMarkup(node), node.key);
    Children.forEach(node.props.children, child => paragraphs(child, found));
    return found;
  }
  const before = paragraphs(render(0));
  const inserted = paragraphs(render(1));
  const moved = paragraphs(render(2));
  for (const text of ["A", "B", "C"]) {
    const keyFor = nodes => [...nodes].find(([html]) => html.endsWith(`>${text}</p>`))?.[1];
    assert.ok(keyFor(before), `missing paragraph ${text}`);
    assert.equal(keyFor(inserted), keyFor(before), `insertion changed ${text}'s key`);
    assert.equal(keyFor(moved), keyFor(before), `reorder changed ${text}'s key`);
  }
  const html = renderToStaticMarkup(render(3));
  for (const fragment of ["<em", "<strong", "<code", "<a ", "<pre", "<ul", "<ol",
    "<dl", "<blockquote", "<aside", 'start="3"', "inline child", "unknown child",
    "notice child", "[inline extension: Test.inline]", "[block extension: Test.unknown]",
    'data-verso-math-mode="inline"', 'data-verso-math-mode="display"']) {
    assert.ok(html.includes(fragment), `missing ${fragment}`);
  }
  assert.ok(html.includes("&lt;script&gt;unsafe()&lt;/script&gt;"));
  assert.ok(!html.includes("<script>") && !html.includes("hidden child"));
  assert.ok(!html.includes("data-bp-") && !html.includes("bp_math"));
  function descendantKeys(node, found = []) {
    if (!isValidElement(node)) return found;
    if (["em", "strong", "code", "a", "li", "dt", "dd"].includes(node.type))
      found.push([node.type, node.key]);
    Children.forEach(node.props.children, child => descendantKeys(child, found));
    return found;
  }
  const originalKeys = descendantKeys(render(3));
  assert.ok(originalKeys.length >= 10, "missing nested key fixtures");
  assert.deepEqual(descendantKeys(render(5)), originalKeys,
    "moving a retained parent must not change inline/list descendant keys");
  const grouped = paragraphs(render(4));
  assert.equal(grouped.size, 4);
  for (const [html] of grouped) {
    assert.equal(html.includes('data-verso-focus="cursor"'), !html.endsWith(">unrelated</p>"),
      "fragment focus must reach all visible children, not unrelated siblings");
  }
  return { ordinaryMarkup: true, escapedCode: true, visibleFallbacks: true,
    extensionCallbacks: true, hiddenContentOmitted: true, stableReactKeys: true,
    concatenationFocus: true, siblingLocalDescendantKeys: true };
}

// The diff helper describes comparison snapshots, not visible DOM nodes.
// Keep its coarse-container policy explicit while checking real markup.
export function checkChangeHighlighting(render) {
  function markers(node, found = []) {
    if (!isValidElement(node)) return found;
    if (node.props["data-verso-change"] === "changed")
      found.push([node.type, node.props["data-verso-block"]]);
    Children.forEach(node.props.children, child => markers(child, found));
    return found;
  }
  const block = "part-root-block-0";
  for (const [kind, tag] of ["ul", "ol", "dl", "blockquote"].entries()) {
    assert.deepEqual(markers(render(2 * kind)), [], "unchanged document has no change markers");
    assert.deepEqual(markers(render(2 * kind + 1)), [[tag, block]],
      "nested edit highlights the whole list/quote, not individual descendants");
  }
  assert.deepEqual(markers(render(9)), [["div", block], ["p", `${block}-block-0`]],
    "extensions compare their parent and stored children");
  const hidden = render(11);
  assert.deepEqual(markers(hidden), [], "hidden content creates no visible marker");
  assert.equal(hidden.props["data-verso-changed-block-count"], "2",
    "diagnostic count is supplied changed paths, including hidden content");
  assert.deepEqual(markers(render(13)), [["p", `${block}-block-1`]],
    "fragments have no phantom change marker");
  assert.ok(markers(render(14)).length > 0, "initial paths work for a genre without equality instances");
  assert.deepEqual(markers(render(15)), [], "opaque semantic labels cannot alias a nested path");
  assert.deepEqual(markers(render(16)), [["div", block], ["div", `${block}-block-0`],
    ["p", `${block}-block-0-block-0`]], "nested edit does not mark the path-like sibling label");
  assert.deepEqual(markers(render(17)), [["div", "part-root-block-1"], ["p", "part-root-block-1-block-0"]],
    "sibling edit does not mark the nested branch");
  return { coarseContainerChanges: true, extensionChildChanges: true,
    hiddenChangePaths: true, initialPathsWithoutEquality: true, opaqueIdentityPaths: true };
}
