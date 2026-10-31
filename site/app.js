"use strict";

// Fetch a URL as text, bypassing the browser cache so the page always
// shows the current version and the pod that served this request.
async function fetchText(url) {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(url + " returned " + response.status);
  }
  return response.text();
}

// textContent (never innerHTML) so fetched values can't inject markup.
function setText(id, value) {
  document.getElementById(id).textContent = value;
}

async function main() {
  try {
    const config = JSON.parse(await fetchText("config/env.json"));
    setText("environment", config.environment || "unknown");
    setText("banner", config.banner || "");
  } catch (err) {
    setText("banner", "Configuration not found");
  }

  try {
    const info = JSON.parse(await fetchText("version.json"));
    setText("version", info.version || "unknown");
  } catch (err) {
    // version.json only exists in the built image (P2.2)
  }

  try {
    const pod = (await fetchText("/whoami")).trim();
    if (pod) {
      setText("pod", pod);
    }
  } catch (err) {
    // /whoami only exists when nginx serves the site
  }
}

main();
