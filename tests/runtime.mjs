import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { createVirRuntime } from "lean-vir/vir-runtime-node";
import { createBrowserHostBindings } from "lean-vir/host-bindings";
import { createBrowserReactHostBindings } from "lean-vir/react-host-bindings";

export const root = fileURLToPath(new URL("..", import.meta.url));

// Public Lake queries, not paths inferred from OLean locations.
export function query(target) {
  return resolve(root, JSON.parse(execFileSync("lake", ["--json", "query", target], {
    cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"],
  })));
}

export async function openTestRuntime(target = "+VersoCastTests:vir") {
  execFileSync("lake", ["exe", "cast-assets"], { cwd: root, stdio: "inherit" });
  const identity = JSON.parse(await readFile(resolve(root, ".vir/runtime.json"), "utf8"));
  const wasmBytes = await readFile(resolve(root, ".vir/runtime.wasm"));
  assert.equal(createHash("sha256").update(wasmBytes).digest("hex"), identity.sha256);
  const runtime = await createVirRuntime({
    wasmBytes,
    irPackageSet: pathToFileURL(query(target)).href,
    fetchBytes: url => readFile(fileURLToPath(url)),
    // VIR owns this fresh provider and its cleanup, not a copied host adapter.
    defaultHostBindings: () => createBrowserHostBindings({
      reactHostBindings: createBrowserReactHostBindings,
    }),
  });
  return { runtime, identity };
}
