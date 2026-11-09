import React from "react";
import { renderPage, usePage } from "../../js/preview.mjs";

// Demo chrome, not part of the headless acquisition API.
const headerStyle = { display: "flex", alignItems: "center", gap: "1em", position: "sticky",
  top: 0, zIndex: 1, background: "var(--vscode-editor-background, white)", padding: ".5em 0" };
const statusStyle = { margin: 0, minWidth: 0, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" };

export function PanelView({ bridge, state }) {
  const [debug, setDebug] = React.useState(false);
  const message = state.status.kind === "loading" ? "Loading page…" :
    state.status.kind === "error" ? state.status.message :
    state.status.kind === "idle" ? "Waiting for a page…" : "";
  return React.createElement("section", { "data-cast-preview-current": state.matchesSelection },
    React.createElement("header", { "data-cast-preview-shell": true, style: headerStyle },
      React.createElement("label", { style: { whiteSpace: "nowrap" } },
        React.createElement("input", { type: "checkbox", checked: debug,
          onChange: event => setDebug(event.target.checked) }), " Debug"),
      React.createElement("p", { role: "status", title: message, style: statusStyle }, message)),
    debug && React.createElement("aside", { "data-cast-debug": true },
      "Whole checked page · raw document · no website traversal"),
    renderPage(bridge, state, { debug }));
}

export function PreviewPanel({ selection, decode, view }) {
  const state = usePage(selection, decode);
  return React.createElement(PanelView, { bridge: { view }, state });
}
