import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { copyFile, mkdir, readFile, writeFile, access, readdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const manualRevision = "349244b4dd2f284728c1dacb621cc74a32f9929b";
const root = fileURLToPath(new URL("..", import.meta.url));
const destination = resolve(root, ".local/reference-manual");
const fixtures = resolve(root, "tests/reference-manual");
const sources = ["CastManualPreview.lean", "CastManualPreview/Server.lean", "ExportPages.lean"];
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
    "show_panel_widgets [local Lean.Vir.Infoview.widget with CastManualPreview.preparedWidgetProps]\n\n#doc (Manual)");
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
    if (state.revision !== manualRevision || hash(await readFile(resolve(destination, "lakefile.lean"))) !== state.lakefile)
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
  // Refresh only our generated helper files; never clobber local helper edits.
  for (const source of sources) {
    const target = resolve(destination, "cast-preview", source);
    const content = await readFile(resolve(fixtures, source));
    if (await exists(target) && hash(await readFile(target)) !== state.sources[source] &&
        hash(await readFile(target)) !== hash(content))
      throw Error(`Local helper edits in ${target}; refusing to overwrite`);
    await mkdir(dirname(target), { recursive: true });
    await writeFile(target, content);
    state.sources[source] = hash(content);
  }
  await writeFile(marker, JSON.stringify(state, null, 2) + "\n");
  run(root, "lake", ["exe", "cast-assets"]);
  await mkdir(resolve(destination, ".vir"), { recursive: true });
  for (const name of ["runtime.wasm", "runtime.json"])
    await copyFile(resolve(root, ".vir", name), resolve(destination, ".vir", name));
  console.log(`Prepared ${state.pages} Manual pages at ${manualRevision}.`);
  console.log(`Reference copy: ${destination}`);
  if (process.argv.includes("--build"))
    run(destination, "lake", ["build", "CastManualPreview", "+Manual.Intro:olean", "+Manual.BasicTypes.Empty:olean"]);
  console.log(`Open in VS Code: code --new-window ${destination} --goto ${destination}/Manual/Intro.lean:35`);
  console.log("Select a page in Manual/. Initial imports may build; edit notifications refresh the whole checked page.");
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const unknown = process.argv.slice(2).filter(arg => arg !== "--build");
  if (unknown.length) throw Error(`Unknown options: ${unknown.join(" ")}`);
  await setup();
}
