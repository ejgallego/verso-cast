import assert from "node:assert/strict";
import { Children, isValidElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";

function roots(node, result = []) {
  if (!isValidElement(node)) return result;
  if (node.props["data-verso-block"]) result.push(node);
  Children.forEach(node.props.children, child => roots(child, result));
  return result;
}

export function checkSlidesContract(runtime) {
  const render = (kind, field = "title") => runtime.call("CastSlides.Contract.render", kind, field);
  const visits = (kind, field = "title") => runtime.call("CastSlides.Contract.visits", kind, field);
  const rejected = ["style", "onClick", "onclick", "key", "ref", "children",
    "dangerouslySetInnerHTML", "__proto__", "data-verso-block", "data-verso-focus",
    "data-", "data-invalid space", "aria-unknown", "tabindex"];
  for (const kind of ["attr", "wrap", "styled"]) {
    for (const field of rejected) {
      const html = renderToStaticMarkup(render(kind, field));
      assert.match(html, new RegExp(`Slides.${kind}`), `${kind}/${field}: visible fallback`);
      assert.match(html, /&lt;payload&gt;/, "unsupported attributes keep escaped children");
      assert.doesNotMatch(html, /retained/, "decline atomically, not a partial attribute application");
      assert.equal(visits(kind, field), kind === "styled" ? 0n : 1n, "fallback consumes children once");
    }
    const valid = renderToStaticMarkup(render(kind));
    assert.match(valid, /title="value"/);
    assert.match(valid, /class="[^"]*retained/);
    assert.doesNotMatch(valid, /extension:/);
  }
  const nested = roots(render("nested"));
  assert.equal(visits("nested"), 2n);
  assert.equal(nested.length, 3, "heading plus two visible code roots; no discarded wrappers");
  for (const node of nested.slice(1)) {
    assert.equal(node.props.title, "outer title", "outer attributes apply last");
    assert.equal(node.props["data-probe"], "ok");
    assert.equal(node.props["data-verso-focus"], "cursor");
    assert.ok(node.key && node.key !== "value");
  }
  assert.match(nested[2].props.className, /inner outer$/);
  assert.doesNotMatch(nested[1].props.className, /inner/);
  for (const kind of ["zero-columns", "incomplete-row", "row-headers", "cell-gap"]) {
    assert.match(renderToStaticMarkup(render(kind)), /Slides.table/);
    assert.equal(visits(kind), 1n, "declined tables do not consume a cell before fallback");
  }
  assert.match(renderToStaticMarkup(render("table")), /<tbody>/);
  assert.equal(visits("table"), 1n, "valid table consumes each cell once");
  for (const mapped of [false, true]) {
    const imageTree = runtime.call("CastSlides.Contract.renderImages", mapped);
    const images = [];
    const collect = node => {
      if (!isValidElement(node)) return;
      if (node.type === "img") images.push(node);
      Children.forEach(node.props.children, collect);
    };
    collect(imageTree);
    assert.equal(images.length, mapped ? 2 : 1);
    assert.equal(images[0].props.src, "https://example.invalid/remote.svg");
    assert.equal(images[0].props.alt, "Remote <image>");
    assert.equal(images[0].props.style.width, "10px");
    assert.equal(images[0].props.style.height, "12px");
    if (mapped) {
      assert.equal(images[1].props.src, "published/known.svg");
      assert.equal(images[1].props.style.width, "80px");
      assert.equal(images[1].props.style.height, undefined, "dimensions do not leak between images");
      assert.notEqual(images[0].props.style, images[1].props.style);
    }
    const html = renderToStaticMarkup(imageTree);
    assert.match(html, /Slides.image/);
    assert.match(html, /Unresolved children/);
    assert.match(html, /Empty URL children/);
    assert.match(html, /Remote &lt;image&gt;/);
  }
  console.log(`Slides adapter contract: ${rejected.length * 3} attribute declines, nested props/focus, tables and single consumption PASS`);
}
