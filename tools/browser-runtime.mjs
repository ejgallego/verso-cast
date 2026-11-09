import { createVirRuntime } from "lean-vir";
import { createBrowserHostBindings } from "lean-vir/host-bindings";
import { createBrowserReactHostBindings } from "lean-vir/react-host-bindings";

// Shared demo bootstrap, using dependency-owned host bindings and cleanup.
export function openReactRuntime(hostOptions = {}) {
  return createVirRuntime({
    wasmUrl: new URL("runtime.wasm", import.meta.url).href,
    irPackageSet: new URL("document.irpkg-set.json", import.meta.url).href,
    defaultHostBindings: () => createBrowserHostBindings({
      ...hostOptions,
      reactHostBindings: createBrowserReactHostBindings,
    }),
  });
}
