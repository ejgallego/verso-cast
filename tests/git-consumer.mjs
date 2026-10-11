import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const revision = execFileSync("git", ["rev-parse", "HEAD"], { cwd: root, encoding: "utf8" }).trim();
const committed = path => execFileSync("git", ["show", `${revision}:${path}`], {
  cwd: root, encoding: "utf8",
});
const sourceUrl = pathToFileURL(root).href;
const temporary = await mkdtemp(resolve(tmpdir(), "verso-cast-git-consumer-"));
const lake = (cwd, ...args) => execFileSync("lake", args, {
  cwd, stdio: "inherit", env: { ...process.env, LAKE_ARTIFACT_CACHE: "false" },
});

async function prepare(name, fixture, files, oldDependency, newDependency) {
  const directory = resolve(temporary, name);
  await mkdir(directory);
  const config = committed(`${fixture}/lakefile.lean`);
  assert.equal(config.split(oldDependency).length, 2, "fixture has exactly one dependency to replace");
  await writeFile(resolve(directory, "lakefile.lean"), config.replace(oldDependency, newDependency));
  await writeFile(resolve(directory, "lean-toolchain"), committed("lean-toolchain"));
  for (const file of files) {
    const target = resolve(directory, file);
    await mkdir(dirname(target), { recursive: true });
    await writeFile(target, committed(`${fixture}/${file}`));
  }
  return directory;
}

async function checkLock(directory, dependency, manifest = "lake-manifest.json") {
  const lock = JSON.parse(await readFile(resolve(directory, "lake-manifest.json"), "utf8"));
  const direct = lock.packages.find(pkg => pkg.name === dependency);
  assert.equal(direct?.type, "git");
  assert.equal(direct.url, sourceUrl);
  assert.equal(direct.rev, revision);
  const pins = JSON.parse(committed(manifest)).packages.filter(pkg => pkg.type === "git");
  for (const pin of pins) {
    const actual = lock.packages.find(pkg => pkg.name === pin.name);
    assert.equal(actual?.type, "git", `${pin.name}: no local dependency override`);
    assert.equal(actual.rev, pin.rev, `${pin.name}: preserved pin`);
  }
  return lock;
}

try {
  console.log(`Clean Git consumers: committed Cast ${revision} (not working-tree edits)`);
  const gitSource = `from git ${JSON.stringify(sourceUrl)} @ ${JSON.stringify(revision)}`;
  const core = await prepare("core", "tests/downstream", ["Consumer.lean", "Main.lean"],
    'require «verso-cast» from "../.."', `require «verso-cast» ${gitSource}`);
  lake(core, "build");
  lake(core, "exe", "consumer");
  const coreLock = await checkLock(core, "«verso-cast»");
  assert.ok(!coreLock.packages.some(pkg => pkg.name === "«verso-slides»"), "core does not depend on Slides");
  console.log("Core Git consumer: public API and native identity helpers PASS");

  const slides = await prepare("slides", "tests/slides", ["CastSlides/PublicApi.lean"],
    'require «verso-cast-slides» from "../../packages/slides"',
    `require «verso-cast-slides» ${gitSource} / "packages/slides"`);
  lake(slides, "build", "CastSlides.PublicApi");
  const slidesLock = await checkLock(slides, "«verso-cast-slides»", "packages/slides/lake-manifest.json");
  const adapter = slidesLock.packages.find(pkg => pkg.name === "«verso-cast-slides»");
  assert.equal(adapter.subDir, "packages/slides");
  const cast = slidesLock.packages.find(pkg => pkg.name === "«verso-cast»");
  assert.equal(cast?.type, "path", "Slides uses its same-checkout core");
  const castDirectory = resolve(slides, cast.dir);
  assert.ok(castDirectory.startsWith(slides + sep), "core stays inside the fresh consumer checkout");
  assert.equal(execFileSync("git", ["rev-parse", "HEAD"], { cwd: castDirectory, encoding: "utf8" }).trim(), revision);
  assert.equal(await readFile(resolve(castDirectory, "lean-toolchain"), "utf8"), committed("lean-toolchain"));
  console.log("Slides Git-subdirectory consumer: public API and same-checkout core PASS");
} finally {
  // Only the directory created by this invocation, including failed builds.
  await rm(temporary, { recursive: true, force: true });
}
