import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { checkRenderer } from "./renderer-assertions.mjs";
import { createVirRuntime } from "lean-vir/vir-runtime-node";
import { createBrowserHostBindings } from "lean-vir/host-bindings";
import { createBrowserReactHostBindings } from "lean-vir/react-host-bindings";

// Ask Lake for its artifacts; do not infer paths from an OLean location.
const root = fileURLToPath(new URL("..", import.meta.url));
const query = target => resolve(root, JSON.parse(execFileSync("lake", ["--json", "query", target], {
  cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"],
})));
execFileSync("lake", ["exe", "cast-assets"], { cwd: root, stdio: "inherit" });
const identity = JSON.parse(await readFile(resolve(root, ".vir/runtime.json"), "utf8"));
const wasmBytes = await readFile(resolve(root, ".vir/runtime.wasm"));
assert.equal(createHash("sha256").update(wasmBytes).digest("hex"), identity.sha256);
const runtime = await createVirRuntime({
  wasmBytes,
  irPackageSet: pathToFileURL(query("+VersoCastTests:vir")).href,
  fetchBytes: url => readFile(fileURLToPath(url)),
  // VIR owns this fresh provider and its cleanup, not a copied host adapter.
  defaultHostBindings: () => createBrowserHostBindings({
    reactHostBindings: createBrowserReactHostBindings,
  }),
});
try {
  const render = scenario => runtime.call("VersoCastTests.render", BigInt(scenario));
  const result = checkRenderer(render);
  assert.throws(() => runtime.call("VersoCastTests.missing"));
  assert.throws(() => runtime.call("VersoCastTests.render", "not a Nat"));
  assert.ok(render(0)); // Reusable after ordinary boundary rejection.
  console.log(JSON.stringify({ ...result, runtime: identity.contentId }));
} finally {
  runtime.dispose();
}
assert.throws(() => runtime.call("VersoCastTests.render", 0n));
