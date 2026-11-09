import React from "react";
import { EditorContext, EnvPosContext, useClientNotificationEffect, useServerNotificationEffect,
  useEvent, useRpcSession } from "@leanprover/infoview";
import VirShell from "__VIR_SHELL__";
import { PreviewPanel } from "./panel.mjs";

// The registered module composes the public VIR shell with a native owner.
// No copied shell, Wasm-dependent cleanup, or global "latest snapshot" callback.
export function ReferencePage({ uri, ...bridge }) {
  const position = React.useMemo(() => ({ uri, line: 0, character: 0 }), [uri]);
  return React.createElement(EnvPosContext.Provider, { value: position },
    React.createElement(PageAtUri, { key: uri, uri, ...bridge }));
}

function PageAtUri({ uri, decode, view }) {
  const session = useRpcSession();
  const editor = React.useContext(EditorContext);
  const owner = React.useRef(null);
  const [processing, setProcessing] = React.useState(false);
  const [version, setVersion] = React.useState(undefined);
  const [restart, setRestart] = React.useState(0);
  const [stopped, setStopped] = React.useState(false);
  const [selection, setSelection] = React.useState(null);
  const invalidate = () => {
    owner.current?.abort();
    setSelection(null);
  };
  useClientNotificationEffect("textDocument/didChange", event => {
    if (event.textDocument.uri !== uri) return;
    invalidate();
    setVersion(event.textDocument.version);
    setProcessing(true);
  }, [uri]);
  useServerNotificationEffect("$/lean/fileProgress", event => {
    if (event.textDocument.uri !== uri) return;
    const busy = event.processing.length > 0;
    if (busy) invalidate();
    setProcessing(busy);
  }, [uri]);
  useEvent(editor.events.serverStopped, () => { invalidate(); setStopped(true); }, [uri]);
  useEvent(editor.events.serverRestarted, () => {
    invalidate(); setStopped(false); setProcessing(false); setVersion(undefined);
    setRestart(value => value + 1);
  }, [uri]);
  React.useLayoutEffect(() => {
    if (processing || stopped) return;
    const controller = new AbortController();
    owner.current = controller;
    setSelection(Object.freeze({ session, uri, expectedVersion: version, signal: controller.signal }));
    return () => { controller.abort(); owner.current = null; };
  }, [session, uri, version, processing, stopped, restart]);
  return React.createElement(PreviewPanel, { selection, decode, view });
}

export default function Widget(props) {
  return React.createElement(VirShell, { ...props, pageHost: ReferencePage });
}
