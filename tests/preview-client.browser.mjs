import React from "react";
import { createRoot } from "react-dom/client";
import { flushSync } from "react-dom";
import { usePage } from "../js/preview.mjs";

const check = (value, message) => { if (!value) throw Error(message); };
globalThis.IS_REACT_ACT_ENVIRONMENT = true;

window.checkPreview = async () => {
  const container = document.getElementById("app");
  let root, selected, state, calls, decoder, failure;
  const reply = (selection, documentJson = "good") => ({ uri: selection.uri, version: 1,
    snapshotRef: Object.freeze({ __rpcref: 1 }), hasErrors: false, documentJson });
  const makeSelection = () => {
    const controller = new AbortController();
    return { controller, uri: "file:///Page.lean", expectedVersion: 1, signal: controller.signal,
      session: { call(method, params, options) {
        check(method === "VersoCast.Manual.Preview.Server.document", "method");
        check(params.expectedVersion === 1, "version expectation");
        let resolve;
        const promise = new Promise(accept => { resolve = accept; });
        calls.push({ resolve, signal: options.abortSignal });
        if (failure) throw Error("synchronous setup failure");
        return promise;
      } } };
  };
  function Probe() {
    const result = usePage(selected, decoder);
    React.useLayoutEffect(() => { state = result; });
    return React.createElement("p", null, result.lastGood?.value ?? result.status.kind);
  }
  const render = () => root.render(React.createElement(React.StrictMode, null, React.createElement(Probe)));
  const settle = action => React.act(async () => { await action(); });
  const mount = async () => {
    calls = []; failure = false;
    decoder = (_session, value) => value.documentJson === "bad" ?
      { ok: false, error: "bad input" } : { ok: true, value: value.documentJson };
    selected = makeSelection();
    root = createRoot(container);
    await settle(render);
  };
  const replace = () => { selected.controller.abort(); selected = makeSelection(); render(); };
  await mount();
  check(calls.length === 2 && calls[0].signal.aborted, "StrictMode cancels its first setup");
  await settle(() => calls[0].resolve(reply(selected, "stale")));
  check(!state.lastGood, "ignored reply after StrictMode cleanup");
  await settle(() => calls[1].resolve(reply(selected)));
  check(state.matchesSelection && state.lastGood.value === "good", "accepted current reply");
  const count = calls.length;
  await settle(render);
  check(calls.length === count, "stable props do not refetch");
  const old = selected;
  await settle(replace);
  check(old.signal.aborted && !state.matchesSelection && state.lastGood.value === "good",
    "abort before replacement; retain last-good without freshness");
  await settle(() => calls.at(-1).resolve({ ...reply(selected), uri: "file:///Other.lean" }));
  check(state.status.kind === "error" && state.lastGood.value === "good", "wrong URI rejected");
  await settle(replace);
  await settle(() => calls.at(-1).resolve({ ...reply(selected), version: 2 }));
  check(state.status.kind === "error", "wrong version rejected");
  await settle(replace);
  await settle(() => calls.at(-1).resolve(reply(selected, "bad")));
  check(state.status.kind === "error" && /bad input/.test(state.status.message), "explicit decode failure");
  failure = true;
  await settle(replace);
  check(calls.at(-1).signal.aborted && state.status.kind === "error",
    "synchronous setup failure rolls back acquired cancellation");
  failure = false;
  // Foreign decoder reentry replaces the selection before returning its value.
  decoder = () => { flushSync(replace); return { ok: true, value: "must not publish" }; };
  await settle(replace);
  const superseded = calls.at(-1);
  await settle(() => superseded.resolve(reply(selected)));
  check(superseded.signal.aborted && state.lastGood.value === "good" && !state.matchesSelection,
    "decoder reentry cannot publish a superseded reply");
  const pending = calls.at(-1);
  await settle(() => root.unmount());
  check(pending.signal.aborted, "native cleanup aborts without invoking Lean");
  await settle(() => pending.resolve(reply(selected, "late")));
  check(!container.textContent, "late reply after unmount ignored");

  // A runtime failure is fatal, not a recoverable parse error. React owns
  // unmount and request cleanup even if no further Lean callback can run.
  let caught;
  class Boundary extends React.Component {
    state = { error: null };
    static getDerivedStateFromError(error) { return { error }; }
    componentDidCatch(error) { caught = error; }
    render() { return this.state.error ? "failed" : this.props.children; }
  }
  calls = []; selected = makeSelection();
  const fatal = Error("runtime unavailable");
  decoder = () => { throw fatal; };
  root = createRoot(container, { onCaughtError() {} });
  await settle(() => root.render(React.createElement(Boundary, null, React.createElement(Probe))));
  const fatalRequest = calls.at(-1);
  await settle(() => fatalRequest.resolve(reply(selected)));
  check(caught === fatal && fatalRequest.signal.aborted, "fatal error boundary retains error identity and cleans up");
  await settle(() => root.unmount());
  return "StrictMode, stale/reentrant replies, setup rollback, native cleanup and fatal recovery boundary PASS";
};
