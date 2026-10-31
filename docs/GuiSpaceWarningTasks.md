# Configurable space warning

Status: Complete (2026-10-31). Requested: 2026-10-31.

- [x] **SPACE-00 — Add the application preference and best-effort layout.**
  Status: Implemented and focused-tested. Add `useTooLittleRoomWarning=false` in a presentation
  Resource. Prefer fitting layouts; when warnings are off, keep a measured
  composition mounted at its minimum usable size rather than replacing it
  with guidance or blocking play. Restore strict behavior when enabled.
  Preserve real viewport geometry, game state, input drafts and text floors.
- [x] **SPACE-01 — Verify both modes and reconcile guidance.**
  Status: Complete. All 901 unit/integration tests, 17 characterization tests,
  four invariant gates, 14 exported input and 25 geometry cases pass. Fresh
  exported checks pass for two strict layouts and three constrained phone
  cases. Six configuration tests include frame-by-frame warning checks; the
  guidance scene starts hidden until explicitly rendered. Lint, formatting,
  workflow validation and documentation checks pass. Cover portrait/landscape, rotation, safe-area changes,
  runtime toggling, real actions and menu access. Keep strict layout fixtures
  explicit so existing boundary/overflow checks remain useful. Run the full
  suite and exported browser regressions; document the config location and
  the default allowance for edge overflow. Save session evidence under
  `localtmp/space-warning/` and keep device acceptance distinct. Documented in
  [`devdocs/reference/gui-composition.md`](../devdocs/reference/gui-composition.md#space-warning-preference).
  Physical-device acceptance remains separate from browser automation.
