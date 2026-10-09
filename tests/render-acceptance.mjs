import assert from "node:assert/strict";
import { checkRenderer, checkChangeHighlighting } from "./renderer-assertions.mjs";
import { openTestRuntime } from "./runtime.mjs";

const { runtime, identity } = await openTestRuntime();
try {
  const render = scenario => runtime.call("VersoCastTests.render", BigInt(scenario));
  const result = checkRenderer(render);
  const changes = checkChangeHighlighting(scenario => runtime.call("VersoCastTests.renderChanges", BigInt(scenario)));
  assert.throws(() => runtime.call("VersoCastTests.missing"));
  assert.throws(() => runtime.call("VersoCastTests.render", "not a Nat"));
  assert.ok(render(0)); // Reusable after ordinary boundary rejection.
  console.log(JSON.stringify({ ...result, ...changes, runtime: identity.contentId }));
} finally {
  runtime.dispose();
}
assert.throws(() => runtime.call("VersoCastTests.render", 0n));
