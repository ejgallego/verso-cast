// Copyright (c) 2026 Lean FRO LLC. Released under Apache-2.0.
import { createElement, useEffect, useLayoutEffect, useRef, useState } from "react";

/** The host owns selection.signal: abort it before replacing a selection or
 * stopping its execution owners. Selection is immutable and cursor-independent.
 * This hook owns only the request; its cleanup works without a live Lean runtime.
 * decode(session, reply) returns {ok, value?, error?}; value is opaque Lean data.
 */
export function usePage(selection, decode) {
  const committed = useRef(null);
  const [state, setState] = useState({ selection: null, lastGood: null, status: { kind: "idle" } });
  useLayoutEffect(() => {
    committed.current = selection;
    return () => { committed.current = null; };
  }, [selection]);

  useEffect(() => {
    if (!selection || selection.signal.aborted) return;
    const controller = new AbortController();
    let live = true;
    const current = () => live && !controller.signal.aborted &&
      !selection.signal.aborted && committed.current === selection;
    const publish = update => {
      if (current()) setState(previous => ({ ...update(previous), selection }));
    };
    const failed = message => publish(previous => ({ ...previous,
      status: { kind: "error", message } }));
    const cleanup = () => { live = false; controller.abort(); };
    try {
      const signal = AbortSignal.any([selection.signal, controller.signal]);
      publish(previous => ({ ...previous, status: { kind: "loading" } }));
      const params = selection.expectedVersion === undefined ? {} :
        { expectedVersion: selection.expectedVersion };
      const request = selection.session.call("VersoCast.Manual.Preview.Server.document", params, { abortSignal: signal });
      Promise.resolve(request).then(reply => {
        if (!current()) return;
        if (reply?.uri !== selection.uri || !Number.isSafeInteger(reply.version) || reply.version < 0 ||
            typeof reply.documentJson !== "string" || typeof reply.hasErrors !== "boolean" ||
            !reply.snapshotRef || typeof reply.snapshotRef !== "object" ||
            (selection.expectedVersion !== undefined && reply.version !== selection.expectedVersion)) {
          failed("Preview reply does not match the requested page/version");
          return;
        }
        const result = decode(selection.session, reply);
        // Decoding may call foreign code; invalidation/reentry must still win.
        if (!current()) return;
        if (!result.ok) { failed(`Invalid manual preview: ${result.error}`); return; }
        publish(() => ({ lastGood: { selection, reply, value: result.value }, status: { kind: "ready" } }));
      }, () => failed("Could not load this page. Showing the last successful preview, if any."))
        .catch(error => {
          // A thrown decoder/runtime error is not malformed document input.
          publish(previous => ({ ...previous, fatal: error }));
        });
    } catch (error) {
      const selected = current();
      cleanup(); // rollback even when session.call throws before returning a Promise
      if (selected) setState(previous => ({ ...previous, selection, status: { kind: "error",
        message: "Could not start the preview request" } }));
    }
    return cleanup;
  }, [selection, decode]);

  if (state.fatal) throw state.fatal;
  const matchesSelection = !!selection && state.lastGood?.selection === selection &&
    state.selection === selection && state.status.kind === "ready";
  const status = !selection ? { kind: "idle" } : state.selection !== selection ? { kind: "loading" } : state.status;
  return { lastGood: state.lastGood, status, matchesSelection };
}

/** Opaque Lean data is forwarded unchanged; native React owns its reachability. */
export function renderPage(bridge, state, { debug = false } = {}) {
  return state.lastGood ? createElement(bridge.view, {
    data: state.lastGood.value, matchesSelection: state.matchesSelection, debug,
  }) : null;
}
