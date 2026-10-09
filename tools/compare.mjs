import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { serveDemo } from "./demo.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
// Generate and check the matched views before serving them with the same server.
execFileSync(process.execPath, ["tests/offline-comparison.mjs"], { cwd: root, stdio: "inherit" });
const { server, url } = await serveDemo(resolve(root, "_out/comparison"));
console.log(`Cast / Verso / live React comparison: ${url}`);
process.once("SIGINT", () => server.close());
process.once("SIGTERM", () => server.close());
