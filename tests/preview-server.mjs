import assert from "node:assert/strict";
import { spawn, execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import { resolve } from "node:path";
import { once } from "node:events";
import { createMessageConnection, StreamMessageReader, StreamMessageWriter } from "vscode-jsonrpc/node.js";

const root = fileURLToPath(new URL("..", import.meta.url));
execFileSync("lake", ["build", "+VersoCastTests.PreviewServer:olean"], { cwd: root, stdio: "inherit" });
const uri = pathToFileURL(resolve(root, "tests/VersoCastTests/PreviewServer.lean")).href;
const original = await readFile(fileURLToPath(uri), "utf8");
const child = spawn("lake", ["serve", "--", "-DstderrAsMessages=false"], {
  cwd: root, stdio: ["pipe", "pipe", "pipe"],
});
let stderr = "";
child.stderr.on("data", chunk => { stderr = (stderr + chunk).slice(-8000); });
const connection = createMessageConnection(new StreamMessageReader(child.stdout), new StreamMessageWriter(child.stdin));
connection.onNotification(() => {});
connection.listen();
const deadline = setTimeout(() => { console.error(stderr); child.kill("SIGKILL"); }, 120000);
const wait = version => connection.sendRequest("textDocument/waitForDiagnostics", { uri, version });
const position = { line: original.split("\n").length - 1, character: 0 };
const rpc = (sessionId, method, params) => connection.sendRequest("$/lean/rpc/call", {
  textDocument: { uri }, position, sessionId, method, params,
});
const change = async (version, text) => {
  await connection.sendNotification("textDocument/didChange", {
    textDocument: { uri, version }, contentChanges: [{ text }],
  });
  await wait(version);
};
try {
  await connection.sendRequest("initialize", { processId: process.pid, rootUri: pathToFileURL(root).href,
    capabilities: { lean: { rpcWireFormat: "v1" } } });
  await connection.sendNotification("initialized", {});
  await connection.sendNotification("textDocument/didOpen", {
    textDocument: { uri, languageId: "lean", version: 1, text: original },
  });
  await wait(1);
  const { sessionId } = await connection.sendRequest("$/lean/rpc/connect", { uri });
  const document = params => rpc(sessionId, "VersoCast.Manual.Preview.Server.document", params);
  const first = await document({ expectedVersion: 1 });
  assert.equal(first.uri, uri);
  assert.equal(first.version, 1);
  assert.equal(typeof first.documentJson, "string");
  assert.ok(Object.hasOwn(first.snapshotRef, "__rpcref"), "native RPC reference, not a stringified handle");
  const anchored = await connection.sendRequest("$/lean/rpc/call", {
    textDocument: { uri }, position: { line: 0, character: 0 }, sessionId,
    method: "VersoCast.Manual.Preview.Server.document", params: { expectedVersion: 1 },
  });
  assert.equal(anchored.documentJson, first.documentJson, "imported RPC works at a stable header anchor");
  const query = { snapshotRef: first.snapshotRef };
  assert.equal(await rpc(sessionId, "PreviewServerProbe.title", query), "Preview original");
  await assert.rejects(document({ expectedVersion: 2 }), error => error.code === -32801);
  await change(2, original.replace("Preview original", "Preview edited"));
  await assert.rejects(rpc(sessionId, "PreviewServerProbe.title", query), error => error.code === -32801);
  const second = await document({ expectedVersion: 2 });
  assert.equal(await rpc(sessionId, "PreviewServerProbe.title", { snapshotRef: second.snapshotRef }), "Preview edited");
  await change(3, original.replace("#doc (Manual)", "#check cast_missing_declaration\n\n#doc (Manual)"));
  const erroneous = await document({ expectedVersion: 3 });
  assert.equal(erroneous.hasErrors, true, "a recovered page remains available to preview");
  assert.equal(await rpc(sessionId, "PreviewServerProbe.title", { snapshotRef: erroneous.snapshotRef }), "Preview original");
  await assert.rejects(rpc(sessionId, "PreviewServerProbe.admit", { snapshotRef: erroneous.snapshotRef }), /errors/);
  await change(4, original);
  const recovered = await document({ expectedVersion: 4 });
  assert.equal(await rpc(sessionId, "PreviewServerProbe.title", { snapshotRef: recovered.snapshotRef }), "Preview original");
  const other = await connection.sendRequest("$/lean/rpc/connect", { uri });
  await assert.rejects(rpc(other.sessionId, "PreviewServerProbe.title", { snapshotRef: recovered.snapshotRef }),
    error => error.code === -32602 && /RPC reference/i.test(error.message));
  // A genuine same-version worker replacement, not a substituted scheduler task.
  await connection.sendNotification("textDocument/didClose", { textDocument: { uri } });
  await connection.sendNotification("textDocument/didOpen", {
    textDocument: { uri, languageId: "lean", version: 4, text: original },
  });
  await wait(4);
  await assert.rejects(rpc(sessionId, "PreviewServerProbe.title", { snapshotRef: recovered.snapshotRef }),
    error => error.code === -32900, "old RPC session must retire after a same-version restart");
  const replacement = await connection.sendRequest("$/lean/rpc/connect", { uri });
  assert.notEqual(replacement.sessionId, sessionId);
  const fresh = await rpc(replacement.sessionId, "VersoCast.Manual.Preview.Server.document", { expectedVersion: 4 });
  assert.equal(await rpc(replacement.sessionId, "PreviewServerProbe.admit", { snapshotRef: fresh.snapshotRef }), "Preview original");
  console.log("Native LSP/RPC: version guards, real same-version worker restart, preview/error admission and recovery PASS");
} finally {
  clearTimeout(deadline);
  const exited = child.exitCode === null && child.signalCode === null ? once(child, "exit") : Promise.resolve();
  const kill = setTimeout(() => child.kill("SIGKILL"), 3000);
  try {
    await connection.sendRequest("shutdown").catch(() => {});
    await connection.sendNotification("exit").catch(() => {});
    child.stdin.end();
  } finally {
    connection.dispose();
    try { await exited; } finally { clearTimeout(kill); }
  }
}
