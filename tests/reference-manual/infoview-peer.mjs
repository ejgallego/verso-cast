import React from "react";

// Controlled editor transport for the production native wrapper. This does not
// emulate the VIR shell or claim an actual VS Code/LSP acceptance.
const listeners = new Map();
export const peer = {
  session: null,
  notify(key, event) { for (const callback of listeners.get(key) ?? []) callback(event); },
  get subscriptions() { return [...listeners.values()].reduce((n, set) => n + set.size, 0); },
};
export const EditorContext = React.createContext({ events: {
  serverStopped: "stopped", serverRestarted: "restarted",
} });
export const EnvPosContext = React.createContext(undefined);
export function useRpcSession() {
  const position = React.useContext(EnvPosContext);
  if (position.line !== 0 || position.character !== 0) throw Error("expected stable header anchor");
  return peer.session;
}
function useNotification(key, callback, dependencies) {
  React.useEffect(() => {
    let callbacks = listeners.get(key);
    if (!callbacks) listeners.set(key, callbacks = new Set());
    callbacks.add(callback);
    return () => callbacks.delete(callback);
  }, dependencies);
}
export const useClientNotificationEffect = useNotification;
export const useServerNotificationEffect = useNotification;
export const useEvent = useNotification;
