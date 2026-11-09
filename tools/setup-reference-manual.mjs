import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { copyFile, mkdir, readFile, writeFile, access, readdir, unlink } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { build } from "esbuild";
import { pages as samplePages } from "../tests/reference-manual/pages.mjs";

export const manualRevision = "400f1682df64bc00e485215bfa4398d24c0f220c";
const root = fileURLToPath(new URL("..", import.meta.url));
const destination = resolve(root, ".local/reference-manual");
const fixtures = resolve(root, "tests/reference-manual");
const sources = ["CastManualPreview.lean",
  "CastManualPreview/Extensions.lean", "ExportPages.lean"];
const hash = source => createHash("sha256").update(source).digest("hex");
const run = (cwd, command, args, capture = false) => execFileSync(command, args, {
  cwd, encoding: "utf8", stdio: capture ? ["ignore", "pipe", "inherit"] : "inherit",
});
async function exists(path) { try { await access(path); return true; } catch { return false; } }

// #doc consumes the rest of a Verso page: imports and widget registration must
// precede it. Non-page helper modules are deliberately untouched.
export function patchPage(source) {
  const doc = /^#doc\s+\(Manual\)/m;
  if (!doc.test(source)) return source;
  if (source.includes("import CastManualPreview")) throw Error("page already has Cast preview support");
  if (!/^import\s/m.test(source)) throw Error("manual page has no import header");
  return source.replace(/^import\s/m, "import CastManualPreview\nimport ").replace(doc,
    "show_panel_widgets [local CastManualPreview.widget with CastManualPreview.preparedWidgetProps]\n\n#doc (Manual)");
}

async function pages(directory) {
  const result = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) result.push(...await pages(path));
    else if (entry.name.endsWith(".lean")) result.push(path);
  }
  return result;
}

// Preflight the complete managed update before changing configuration, pages or
// helpers. This is edit protection, not a crash-atomic filesystem transaction.
export async function refreshPreview(directory, state, helpers) {
  const writes = [];
  const configPath = resolve(directory, "lakefile.lean");
  const previousConfig = await readFile(configPath, "utf8");
  if (hash(previousConfig) !== state.lakefile)
    throw Error("Existing setup was changed; refusing to overwrite its configuration");
  let config = previousConfig;
  if (!config.includes("input_file castPreviewWidget")) {
    config = config.replace("lean_lib CastManualPreview where",
      'input_file castPreviewWidget where\n  path := "cast-preview/Widget.mjs"\n\nlean_lib CastManualPreview where')
      .replace('srcDir := "cast-preview"', 'srcDir := "cast-preview"\n  needs := #[castPreviewWidget]');
  }
  if (config !== previousConfig) writes.push([configPath, config]);
  for (const path of await pages(resolve(directory, "Manual"))) {
    const content = await readFile(path, "utf8");
    const updated = content.replace(
      "show_panel_widgets [local Lean.Vir.Infoview.widget with CastManualPreview.preparedWidgetProps]",
      "show_panel_widgets [local CastManualPreview.widget with CastManualPreview.preparedWidgetProps]");
    if (updated !== content) writes.push([path, updated]);
  }
  const next = { ...state, lakefile: hash(config), sources: { ...state.sources } };
  const retired = "CastManualPreview/Server.lean";
  const retiredPath = resolve(directory, "cast-preview", retired);
  const removeRetired = !!state.sources[retired] && await exists(retiredPath);
  if (removeRetired && hash(await readFile(retiredPath)) !== state.sources[retired])
    throw Error(`Local edits in retired helper ${retiredPath}; refusing to remove it`);
  delete next.sources[retired];
  for (const [source, content] of helpers) {
    const target = resolve(directory, "cast-preview", source);
    const previousHash = await exists(target) ? hash(await readFile(target)) : null;
    const contentHash = hash(content);
    if (previousHash !== null && previousHash !== state.sources[source] && previousHash !== contentHash)
      throw Error(`Local helper edits in ${target}; refusing to overwrite`);
    if (previousHash !== contentHash) writes.push([target, content]);
    next.sources[source] = contentHash;
  }
  for (const [target, content] of writes) {
    await mkdir(dirname(target), { recursive: true });
    await writeFile(target, content);
  }
  if (removeRetired) await unlink(retiredPath);
  await writeFile(resolve(directory, ".cast-preview.json"), JSON.stringify(next, null, 2) + "\n");
  return next;
}

async function setup() {
  // Share built dependency checkouts, but only after checking their immutable
  // revisions against both lock files. Never update or patch those checkouts.
  const castLock = JSON.parse(await readFile(resolve(root, "lake-manifest.json"), "utf8"));
  const dependencies = hash(JSON.stringify(castLock.packages.map(({ name, rev }) => ({ name, rev }))));
  for (const pkg of castLock.packages) {
    const actual = run(resolve(root, ".lake/packages", pkg.name), "git", ["rev-parse", "HEAD"], true).trim();
    if (actual !== pkg.rev) throw Error(`Cast dependency ${pkg.name} is not at its locked revision`);
    if (run(resolve(root, ".lake/packages", pkg.name), "git",
        ["status", "--porcelain", "--untracked-files=no"], true).trim())
      throw Error(`Cast dependency ${pkg.name} has source edits; refusing a mixed-source setup`);
  }
  // Build and read all helper inputs before mutating the reference copy.
  const helpers = new Map(await Promise.all(sources.map(async source =>
    [source, await readFile(resolve(fixtures, source))])));
  const bundle = await build({ absWorkingDir: root,
    entryPoints: ["tests/reference-manual/widget.mjs"], bundle: true, format: "esm",
    write: false, external: ["react", "@leanprover/infoview", "__VIR_SHELL__"] });
  helpers.set("Widget.mjs", bundle.outputFiles[0].contents);
  if (!await exists(destination)) {
    await mkdir(destination, { recursive: true });
    run(destination, "git", ["init", "--quiet"]);
    run(destination, "git", ["remote", "add", "origin", "https://github.com/leanprover/reference-manual.git"]);
    run(destination, "git", ["fetch", "--depth=1", "origin", manualRevision]);
    run(destination, "git", ["checkout", "--detach", "FETCH_HEAD"]);
  }
  if (run(destination, "git", ["rev-parse", "HEAD"], true).trim() !== manualRevision)
    throw Error("Existing reference copy has a different revision; it was left untouched");
  if (await readFile(resolve(destination, "lean-toolchain"), "utf8") !==
      await readFile(resolve(root, "lean-toolchain"), "utf8"))
    throw Error("Reference manual and Cast toolchains differ");

  const marker = resolve(destination, ".cast-preview.json");
  let state;
  if (await exists(marker)) {
    state = JSON.parse(await readFile(marker, "utf8"));
    if (state.dependencies && state.dependencies !== dependencies)
      throw Error("Cast dependency pins changed; the existing reference setup was left untouched");
    if (state.revision !== manualRevision)
      throw Error("Existing setup was changed; refusing to overwrite its configuration");
  } else {
    if (run(destination, "git", ["status", "--porcelain", "--untracked-files=no"], true).trim())
      throw Error("Existing reference copy has edits; refusing to patch it");
    const lock = JSON.parse(await readFile(resolve(destination, "lake-manifest.json"), "utf8"));
    for (const pkg of lock.packages) {
      const shared = castLock.packages.find(other => other.name === pkg.name);
      if (shared && shared.rev !== pkg.rev) throw Error(`Manual and Cast disagree on ${pkg.name}`);
    }
    run(destination, "git", ["apply", "--check", resolve(fixtures, "lakefile.patch")]);
    run(destination, "git", ["apply", resolve(fixtures, "lakefile.patch")]);
    const shared = castLock.packages.map(pkg => ({
      type: "path", scope: "", name: pkg.name, manifestFile: pkg.manifestFile,
      inherited: !["verso", "illuminate"].includes(pkg.name),
      dir: `../../.lake/packages/${pkg.name}`, configFile: pkg.configFile,
    }));
    lock.packages = [
      ...lock.packages.filter(pkg => !castLock.packages.some(other => other.name === pkg.name))
        .map(pkg => ({ ...pkg, inputRev: pkg.rev })),
      { type: "path", scope: "", name: "«verso-cast»", manifestFile: "lake-manifest.json",
        inherited: false, dir: "../..", configFile: "lakefile.lean" }, ...shared,
    ];
    await writeFile(resolve(destination, "lake-manifest.json"), JSON.stringify(lock, null, 2) + "\n");
    let count = 0;
    for (const path of await pages(resolve(destination, "Manual"))) {
      const original = await readFile(path, "utf8");
      const patched = patchPage(original);
      if (patched !== original) { await writeFile(path, patched); count++; }
    }
    state = { revision: manualRevision, pages: count,
      lakefile: hash(await readFile(resolve(destination, "lakefile.lean"))), sources: {} };
    await writeFile(resolve(destination, ".git/info/exclude"), "\n/.cast-preview.json\n/.cast-preview/\n/cast-preview/\n/.vir/\n/.beam/\n");
  }
  state.dependencies = dependencies;
  state = await refreshPreview(destination, state, helpers);
  run(root, "lake", ["exe", "cast-assets"]);
  await mkdir(resolve(destination, ".vir"), { recursive: true });
  for (const name of ["runtime.wasm", "runtime.json"])
    await copyFile(resolve(root, ".vir", name), resolve(destination, ".vir", name));
  console.log(`Prepared ${state.pages} Manual pages at ${manualRevision}.`);
  console.log(`Reference copy: ${destination}`);
  if (process.argv.includes("--build"))
    run(destination, "lake", ["build", "CastManualPreview", ...samplePages.map(page => `+${page.module}:olean`)]);
  console.log(`Open in VS Code: code --new-window ${destination} --goto ${destination}/Manual/Intro.lean:35`);
  console.log("Select a page in Manual/. Initial imports may build; edit notifications refresh the whole checked page.");
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const unknown = process.argv.slice(2).filter(arg => arg !== "--build");
  if (unknown.length) throw Error(`Unknown options: ${unknown.join(" ")}`);
  await setup();
}
