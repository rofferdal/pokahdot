"""Render a local-only, manually copied browser evidence page."""

from __future__ import annotations

import html
import json


def render_diagnostics(state: str, metadata: dict | None) -> bytes:
    """Build a responsive page containing public build and browser diagnostics."""
    public_build = None
    if metadata:
        public_build = {key: metadata[key] for key in
                        ("build_id", "source_sha", "source_tree_state", "dirty_source_fingerprint")
                        if key in metadata}
    embedded = json.dumps(public_build, separators=(",", ":"))
    embedded = embedded.replace("&", "\\u0026").replace("<", "\\u003c").replace(">", "\\u003e")
    state_text = html.escape(state)
    page = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>LAN browser evidence</title>
  <style>
    :root {{ color-scheme: light dark; font: 20px/1.5 system-ui, sans-serif; }}
    body {{ max-width: 46rem; margin: 0 auto; padding: 1.25rem; }}
    h1 {{ font-size: 1.5rem; }}
    textarea {{ box-sizing: border-box; width: 100%; min-height: 22rem; font: 1rem/1.4 ui-monospace, monospace; }}
    a {{ display: inline-block; min-height: 48px; margin: 0.4rem 0 1rem; }}
  </style>
</head>
<body>
  <h1>LAN browser evidence</h1>
  <p>Build state: <span id="build-state">{state_text}</span></p>
  <a href="/">Open latest game</a>
  <p>This record stays in this page. Copy the JSON manually and attach it with your test notes.</p>
  <textarea id="evidence" aria-label="Browser evidence JSON" readonly></textarea>
  <script type="application/json" id="public-build">{embedded}</script>
  <script>
    (() => {{
      const audioContext = window.AudioContext || window.webkitAudioContext;
      const record = {{
        captured_at_utc: new Date().toISOString(),
        origin: location.origin,
        build_state: document.getElementById("build-state").textContent,
        build: JSON.parse(document.getElementById("public-build").textContent),
        browser: {{
          is_secure_context: typeof window.isSecureContext === "boolean" ? window.isSecureContext : null,
          inner_width: window.innerWidth,
          inner_height: window.innerHeight,
          device_pixel_ratio: window.devicePixelRatio,
          user_agent: navigator.userAgent,
          platform: navigator.platform,
          max_touch_points: navigator.maxTouchPoints,
          audio_context_available: typeof audioContext === "function",
          audio_worklet_available: typeof audioContext === "function" && "audioWorklet" in audioContext.prototype
        }}
      }};
      document.getElementById("evidence").value = JSON.stringify(record, null, 2);
    }})();
  </script>
</body>
</html>
"""
    return page.encode("utf-8")
