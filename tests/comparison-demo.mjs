import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
// An empty browser-install location: the old test-before-serve path fails here.
const temporary = await mkdtemp(resolve(tmpdir(), "cast-comparison-no-browser-"));
try {
  for (const fixture of ["core", "blog", "slides"]) {
    const child = spawn(process.execPath, ["tools/compare.mjs", fixture], {
      cwd: root, env: { ...process.env, PLAYWRIGHT_BROWSERS_PATH: temporary },
      stdio: ["ignore", "pipe", "inherit"],
    });
    const exited = new Promise(resolve => child.once("close", (code, signal) => resolve({ code, signal })));
    let ready = false;
    try {
      const url = await new Promise((resolve, reject) => {
        let output = "";
        const timer = setTimeout(() => reject(Error(`${fixture}: server did not become ready`)), 60_000);
        child.once("error", error => { clearTimeout(timer); reject(error); });
        child.once("exit", (code, signal) => {
          clearTimeout(timer); reject(Error(`${fixture}: exited before ready (${code ?? signal})`));
        });
        child.stdout.on("data", bytes => {
          output += bytes;
          const match = output.match(/comparison: (http:\/\/127\.0\.0\.1:\d+\/)/);
          if (match) { clearTimeout(timer); resolve(match[1]); }
        });
      });
      ready = true;
      const response = await fetch(url);
      assert.equal(response.status, 200);
      const html = await response.text();
      for (const pane of ["live", "cast", "verso"]) assert.match(html, new RegExp(`id="${pane}"`));
      for (const path of ["comparison.js", "runtime.wasm", "document.irpkg-set.json"]) {
        const asset = await fetch(new URL(path, url));
        assert.equal(asset.status, 200, path);
        assert.ok((await asset.arrayBuffer()).byteLength > 0, path);
      }
      console.log(`${fixture}: comparison server without installed Playwright browsers PASS`);
    } finally {
      child.kill("SIGTERM");
      const result = await exited;
      if (ready) assert.equal(result.code, 0, `${fixture}: server closes cleanly`);
    }
  }
} finally { await rm(temporary, { recursive: true, force: true }); }
