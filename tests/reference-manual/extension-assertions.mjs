import assert from "node:assert/strict";
import { Children, isValidElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";

// Reuse actual compiler payloads; this tests the compiled adapter, not a JS renderer.
export function checkManualExtensions(runtime, documents) {
  function find(value, name) {
    if (!value || typeof value !== "object") return undefined;
    if (value.other?.container?.name === name) return value.other;
    for (const child of Object.values(value)) {
      const result = find(child, name);
      if (result) return result;
    }
  }
  const source = name => {
    const found = find(documents, name);
    assert.ok(found, `checked pages contain ${name}`);
    return structuredClone(found);
  };
  const render = content => runtime.call("CastManualPreview.renderDocument", JSON.stringify({
    ...documents[0], title: [], titleString: "", metadata: null, subParts: [], content,
  }));
  const inline = extension => render([{ para: [{ other: extension }] }]);
  const block = extension => render([{ other: extension }]);
  function text(node) {
    if (typeof node === "string") return node;
    if (!isValidElement(node)) return "";
    let result = "";
    Children.forEach(node.props.children, child => { result += text(child); });
    return result;
  }
  const attribute = source("Manual.attr");
  const attributeText = attribute.content[0].code;
  assert.equal(typeof attributeText, "string");
  for (const name of ["Manual.attr", "Manual.attrs"]) {
    const extension = structuredClone(attribute);
    extension.container.name = name;
    const node = inline(extension);
    assert.equal(text(node), attributeText, "highlighted source replaces, not duplicates, fallback children");
    const html = renderToStaticMarkup(node);
    assert.match(html, /data-verso-token="true"/);
    assert.doesNotMatch(html, /extension:/);
  }
  const syntax = source("Manual.syntaxKind");
  syntax.container.data[1][0] = "authored <kind>";
  const syntaxNode = inline(syntax);
  assert.equal(text(syntaxNode), "authored <kind>", "use the authored label, not the resolved-name child");
  assert.match(renderToStaticMarkup(syntaxNode), /authored &lt;kind&gt;/);

  for (const name of ["Verso.Genre.Manual.index", "Verso.Genre.Manual.see"]) {
    const annotation = source(name);
    assert.equal(text(inline(annotation)), "", "checked index metadata is not visible prose");
    annotation.content = [{ emph: [{ text: "Annotation child <escaped>" }] }];
    assert.equal(text(inline(annotation)), "Annotation child <escaped>",
      "valid annotations preserve explicitly supplied children");
    assert.match(renderToStaticMarkup(inline(annotation)), /<em[^>]*>Annotation child &lt;escaped&gt;<\/em>/);
    annotation.container.data = true;
    assert.equal(text(inline(annotation)), `[inline extension: ${name}]Annotation child <escaped>`,
      "malformed metadata keeps its marker and children once");
  }

  const todo = source("Manual.TODO");
  todo.content = [{ emph: [{ text: "Pending <work> & detail" }] }];
  const todoNode = inline(todo);
  assert.equal(text(todoNode), "TODO: Pending <work> & detail");
  assert.match(renderToStaticMarkup(todoNode), /<em[^>]*>Pending &lt;work&gt; &amp; detail<\/em>/);
  // Manual's inline/block property encodings differ. Keep a real block container.
  const todoBlock = {
    container: { ...source("Manual.example").container, name: "Manual.TODO", data: null },
    content: [{ para: todo.content }],
  };
  const blockNode = block(todoBlock);
  assert.equal(text(blockNode), "TODO: Pending <work> & detail");
  assert.match(renderToStaticMarkup(blockNode), /<aside[^>]*data-verso-kind="todo"/);

  const attributes = structuredClone(attribute);
  attributes.container.name = "Manual.attrs";
  for (const extension of [attribute, attributes, syntax, todo]) {
    const invalid = structuredClone(extension);
    invalid.container.data = true;
    const node = inline(invalid);
    const marker = `[inline extension: ${invalid.container.name}]`;
    const fallback = extension === todo ? "Pending <work> & detail" : extension.content[0].code;
    assert.equal(text(node), marker + fallback, "malformed data keeps its source children exactly once");
  }
  const invalidBlock = structuredClone(todoBlock);
  invalidBlock.container.data = true;
  const invalidNode = block(invalidBlock);
  assert.equal(text(invalidNode), "[block extension: Manual.TODO]Pending <work> & detail");
  const html = renderToStaticMarkup(invalidNode);
  assert.match(html, /\[block extension: Manual.TODO\]/);
  assert.match(html, /Pending &lt;work&gt; &amp; detail/);
  console.log("Manual consumer roles: highlighting, authored labels, rich TODO notes, escaping and malformed fallback PASS");
}
