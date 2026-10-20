# Desktop follow-up visual reference

This fixture defines the focused human inspection target for the MacBook follow-up. Automated tests validate geometry, configured font resources, and unscaled Control transforms; they cannot prove anti-aliasing quality.

Capture a 1920×1080 six-player table at normal MacBook display scaling with the first preflop blinds visible. Inspect the following crop at 100%: one upper seat, the lowest bot seat (including `Big blind 10`), a seat border, one card face, and the event-log/action-panel pair. Keep the capture beside the test evidence and compare edges at native scale.

Human acceptance: font strokes are smooth, border lines have even weight, card and avatar edges are not blurred or pixelated, and no element appears post-render scaled. Record device, macOS, display scaling, Godot version, date, and pass/fail in the priority-task evidence.
