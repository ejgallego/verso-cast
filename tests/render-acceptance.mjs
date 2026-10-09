import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { checkRenderer } from "./renderer-assertions.mjs";

// Ask Lake for its artifacts; do not infer paths from an OLean location.
const root = fileURLToPath(new URL("..", import.meta.url));
const query = target => resolve(root, JSON.parse(execFileSync("lake", ["--json", "query", target], {
  cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"],
})));
const sdkManifest = query("@lean_vir:virSdk");
const sdkRoot = fileURLToPath(new URL(".", pathToFileURL(sdkManifest)));
const sdkImport = path => import(pathToFileURL(resolve(sdkRoot, path)).href);
const { createVirRuntime } = await sdkImport("js/vir-runtime-node.js");
const { createBrowserHostBindings } = await sdkImport("js/vir-host-bindings.js");
const { createBrowserReactHostBindings } = await sdkImport("js/vir-react-host-bindings.js");
const runtime = await createVirRuntime({
  wasmBytes: await readFile(resolve(sdkRoot, "wasm/vir-upstream.wasm")),
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
  console.log(JSON.stringify(result));
} finally {
  runtime.dispose();
}
assert.throws(() => runtime.call("VersoCastTests.render", 0n));
