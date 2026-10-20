import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const lake = args => execFileSync("lake", args, {
  cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"],
});
const query = target => resolve(root, JSON.parse(lake(["--json", "query", target])));
lake(["build", "cast-codec-input", "+VersoCastTests.JsonSafe:vir"]);
const sdkManifest = query("@lean_vir:virSdk");
const sdk = dirname(sdkManifest);
const identity = JSON.parse(await readFile(sdkManifest, "utf8"));
assert.equal(identity.leanToolchain, "leanprover/lean4:v4.35.0");
assert.equal(identity.manifestVersion, 13);
assert.equal(identity.runtimeAbiVersion, 4);
assert.equal(identity.gitCommit, "987a76a5b8580c5d7f2d1132e7e35b50e01d1b94",
  "use the SDK qualified against the landed PR268 source tree");
for (const file of identity.files) {
  const bytes = await readFile(resolve(sdk, file.path));
  assert.equal(createHash("sha256").update(bytes).digest("hex"), file.sha256, file.path);
}
const { createVirRuntime } = await import(pathToFileURL(resolve(sdk, "js/vir-runtime-node.js")));
const packageSet = query("+VersoCastTests.JsonSafe:vir");
// A compiled native writer produces the String; the ordinary RPC envelope does
// not adapt the typed payload. This is not an editor/LSP connection acceptance.
const encoded = lake(["exe", "cast-codec-input"]).trimEnd();
const envelope = JSON.stringify({ jsonrpc: "2.0", id: 1, result: encoded });
assert.equal(JSON.parse(envelope).result, encoded);
const document = JSON.parse(JSON.parse(envelope).result);
const expected = ["Typed document λ", "Short", "Context", "作者|Zoë", "note\nquote\"",
  "2026-10-20", "canonical", "xref", "chapter", "900719925474099312345",
  "false", "true", "letter:🦀", "false", "true", "99",
  "-12345678901234567890123456789000", "37", "3", "dotted", "last", "blank",
  "Child", "nat:900719925474099312345", "machine", "0"];

for (const profile of ["vir-upstream.wasm", "vir-upstream.dev.wasm"]) {
  const runtime = await createVirRuntime({
    wasmBytes: await readFile(resolve(sdk, "wasm", profile)),
    irPackageSet: pathToFileURL(packageSet).href,
    fetchBytes: url => readFile(fileURLToPath(url)),
  });
  const entry = "VersoCastTests.JsonSafe.observe";
  const observe = input => runtime.callWith({ argumentRepresentation: "json-safe-v1" }, entry, input);
  try {
    assert.deepEqual(observe(document), expected, "independent typed field observations");
    assert.deepEqual(runtime.call(entry, runtime.call("VersoCastTests.JsonSafe.fixture")), expected,
      "the native profile retains its existing representation");
    const duplicate = structuredClone(document);
    const properties = duplicate.content[1].fields.container.properties;
    properties.push({ ...structuredClone(properties.find(p => p.snd === "last")), snd: "replacement" });
    const replaced = [...expected]; replaced[20] = "replacement";
    assert.deepEqual(observe(duplicate), replaced, "library insertion owns duplicate handling");
    const badKey = structuredClone(document);
    badKey.content[1].fields.container.properties.push({ fst: { kind: "anonymous" }, snd: "invalid" });
    assert.throws(() => observe(badKey), /all-string Name chain/);
    const badPriority = structuredClone(document);
    badPriority.metadata.value.searchPriority.val = "100";
    assert.throws(() => observe(badPriority));
    const badInteger = structuredClone(document);
    badInteger.metadata.value.id.value.id = "0900719925474099312345";
    assert.throws(() => observe(badInteger));
    assert.throws(() => JSON.parse("not JSON"));
    assert.deepEqual(observe(document), expected, "recovery after each rejected input");
    console.log(`${profile}: native writer → RPC String → parse → callWith → typed Part observations PASS`);
  } finally { runtime.dispose(); }
  assert.throws(() => observe(document), /disposed/i);
}
console.log(`Matched SDK ${identity.gitCommit}: ${identity.files.length} payload hashes verified`);
