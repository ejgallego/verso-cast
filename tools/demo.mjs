import { execFileSync } from "node:child_process";
import { createServer } from "node:http";
import { copyFile, mkdir, readFile } from "node:fs/promises";
import { dirname, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { build } from "esbuild";

const root = fileURLToPath(new URL("..", import.meta.url));
const lake = args => execFileSync("lake", args, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] });

// One asset-staging path for the small widget and the live comparison.
export async function stageProgram(target, output) {
  const descriptor = JSON.parse(lake(["--json", "query", target]));
  const packageSet = JSON.parse(await readFile(descriptor, "utf8"));
  await mkdir(output, { recursive: true });
  await copyFile(descriptor, resolve(output, "document.irpkg-set.json"));
  for (const member of packageSet.packages) {
    const destination = resolve(output, member.path);
    if (!destination.startsWith(output + sep)) throw Error("package member escapes demo output");
    await mkdir(dirname(destination), { recursive: true });
    await copyFile(resolve(dirname(descriptor), member.path), destination);
  }
  lake(["exe", "cast-assets"]);
  await copyFile(resolve(root, ".vir/runtime.wasm"), resolve(output, "runtime.wasm"));
  return output;
}

export async function stageBrowserDemo(target, output, entryPoint) {
  output = await stageProgram(target, resolve(output));
  await copyFile(resolve(root, "examples/browser/index.html"), resolve(output, "index.html"));
  await build({
    absWorkingDir: root, entryPoints: [entryPoint],
    outfile: resolve(output, "app.js"), bundle: true, format: "esm", target: "es2022",
  });
  return output;
}

export function stageDemo() {
  return stageBrowserDemo("+VersoCastDemo:vir", resolve(root, "_out/demo"), "examples/browser/main.mjs");
}

export async function serveDemo(directory) {
  const types = { js: "text/javascript", json: "application/json", wasm: "application/wasm", html: "text/html",
    svg: "image/svg+xml", png: "image/png", css: "text/css",
    woff2: "font/woff2", woff: "font/woff", ttf: "font/ttf" };
  const server = createServer(async (request, response) => {
    try {
      const pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
      const path = resolve(directory, pathname === "/" ? "index.html" : "." + pathname);
      if (!path.startsWith(directory + sep)) throw Error("outside demo output");
      const bytes = await readFile(path);
      response.writeHead(200, { "Content-Type": types[path.split(".").at(-1)] ?? "application/octet-stream",
        "Cache-Control": "no-store" });
      response.end(bytes);
    } catch {
      response.writeHead(404); response.end("Not found");
    }
  });
  await new Promise((accept, reject) => { server.once("error", reject); server.listen(0, "127.0.0.1", accept); });
  return { server, url: `http://127.0.0.1:${server.address().port}/` };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const { server, url } = await serveDemo(await stageDemo());
  console.log(`Verso Cast: ${url}`);
  process.once("SIGINT", () => server.close());
  process.once("SIGTERM", () => server.close());
}
