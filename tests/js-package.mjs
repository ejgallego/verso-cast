import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { copyFile, mkdir, mkdtemp, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const temporary = await mkdtemp(resolve(tmpdir(), "verso-cast-js-package-"));
try {
  const result = JSON.parse(execFileSync("npm", ["pack", "--json", "--ignore-scripts",
    "--pack-destination", temporary, "--cache", resolve(temporary, "npm-cache")], {
    cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"],
  }));
  // npm versions return either an array or an object keyed by package name.
  const packages = Object.values(result);
  assert.equal(packages.length, 1);
  const [packed] = packages;
  assert.deepEqual(packed.files.map(file => file.path).sort(),
    ["LICENSE", "ORIGIN.md", "README.md", "js/katex.mjs", "package.json"]);
  assert.equal(packed.filename, basename(packed.filename));
  const installed = resolve(temporary, "node_modules/verso-cast");
  await mkdir(installed, { recursive: true });
  execFileSync("tar", ["-xzf", resolve(temporary, packed.filename),
    "--strip-components=1", "-C", installed]);
  // Reuse locked test dependencies; the package itself is a real extracted
  // tarball, outside this repository's package scope and self-reference.
  for (const name of ["react", "react-dom", "katex"])
    await symlink(resolve(root, "node_modules", name), resolve(temporary, "node_modules", name), "dir");
  await copyFile(resolve(root, "tests/js-package/consumer.mjs"), resolve(temporary, "consumer.mjs"));
  execFileSync(process.execPath, [resolve(temporary, "consumer.mjs")], { stdio: "inherit" });
  console.log("JS package: explicit contents and external KaTeX/React SSR consumer PASS");
} finally {
  // Only this invocation's pack output and consumer directory.
  await rm(temporary, { recursive: true, force: true });
}
