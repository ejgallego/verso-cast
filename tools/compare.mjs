import { prepareComparison } from "./comparison.mjs";
import { serveDemo } from "./demo.mjs";

const fixture = process.argv[2] ?? "core";
const { directory } = await prepareComparison(fixture);
const { server, url } = await serveDemo(directory);
console.log(`Cast / Verso / live React ${fixture} comparison: ${url}`);
process.once("SIGINT", () => server.close());
process.once("SIGTERM", () => server.close());
