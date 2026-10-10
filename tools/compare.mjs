import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { serveDemo } from "./demo.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const fixture = process.argv[2] ?? "core";
if (!["core", "blog", "slides"].includes(fixture)) throw Error("Expected core, blog or slides");
// Generate and check the matched views before serving them with the same server.
execFileSync(process.execPath, fixture === "core" ? ["tests/offline-comparison.mjs"] :
  ["tests/genre-comparison.mjs", fixture], { cwd: root, stdio: "inherit" });
const { server, url } = await serveDemo(resolve(root, fixture === "core" ? "_out/comparison" : `_out/genres/${fixture}`));
console.log(`Cast / Verso / live React ${fixture} comparison: ${url}`);
process.once("SIGINT", () => server.close());
process.once("SIGTERM", () => server.close());
