# GUI defect record

Copy this template for every visual, layout, input-reachability, or hosted GUI
defect. Use a stable ID such as `GUI-2026-001`. Do not overwrite before
evidence after a fix.

Follow the loop in
[`../GUI_VISUAL_TESTING.md`](../GUI_VISUAL_TESTING.md): reproduce the exact
fixture where practical, retain its invariant failures and before evidence,
add a failing regression, change only the owning layout/presentation layer,
run the affected matrix and complete suite, capture corrected development
evidence, then produce clean acceptance evidence with
`make gui-visual-capture` when preparing a candidate.

## Classification

- Defect ID: `GUI-YYYY-NNN`
- Title: `<short observed failure>`
- Status: `open` / `fixed` / `accepted` / `deferred`
- Severity: `blocker` / `unreadable` / `obstructive` / `cosmetic`
- Owning layer: `<GUI presentation / export / deployment>`
- Layout owner or component: `<single responsible owner>`
- Reporter: `<name>`
- Reported at (UTC): `<YYYY-MM-DD HH:MM>`

Severity meanings:

- `blocker`: the flow cannot start, continue, or complete safely;
- `unreadable`: required information cannot be read at the supported size;
- `obstructive`: overlap, clipping, or reachability materially interferes with
  the flow; and
- `cosmetic`: presentation is inconsistent but required information and input
  remain usable.

## Candidate and environment

- Source commit (full SHA): `<sha>`
- Stable URL, if hosted: `<URL or n/a>`
- Deployment workflow/run: `<URL or n/a>`
- Canonical capture ID or hosted evidence ID: `<ID>`
- Manifest SHA-256: `<checksum or n/a>`
- Manifest schema and visual-suite version: `<values or n/a>`
- Capture scope: `<full_m3 / selection / hosted / n/a>`
- Source tree state: `clean` / `dirty` / `n/a`
- Dirty fingerprint: `<value or n/a>`
- Development capture: `true` / `false` / `n/a`
- Acceptance eligible: `true` / `false` / `n/a`
- Environment ID: `<canonical-local / desktop-chrome / ...>`
- Device and OS/version: `<value or n/a>`
- Browser and version: `<value or n/a>`
- Renderer: `<Compatibility renderer details>`
- Logical or CSS viewport: `<width>x<height>`
- Usable viewport and safe-area insets: `<rect/insets or n/a>`
- Device-pixel ratio: `<value or n/a>`
- Orientation: `portrait` / `landscape`
- Browser chrome: `expanded` / `collapsed` / `n/a`
- Player count: `<0 / 2 / 4 / 6 / 9 / other documented case>`
- State ID: `<canonical state ID>`
- Fixture ID and fixed seed: `<values or n/a>`

## Reproduction

### Preconditions

`<starting configuration, saved UI state, and relevant accessibility/display settings>`

### Steps

1. `<step>`
2. `<step>`
3. `<step>`

### Expected result

`<observable expected presentation or interaction>`

### Actual result

`<observable failure, including affected stable seat IDs or named regions>`

### Diagnostics

- Reproduction rate: `<for example, 5/5>`
- Reproduction command: `<exact command>`
- Invariant gate result: `<make gui-visual-invariant-gate result or n/a>`
- Manifest `invariants.passed`: `true` / `false` / `n/a`
- Layout settled: `true` / `false` / `n/a`
- Exact invariant failures: `<manifest messages or n/a>`
- Browser/Godot console output: `<exact errors or none>`
- Additional diagnostics: `<logs or n/a>`

## Evidence

- Before screenshot/video: `<durable link>`
- Before manifest path/link and SHA-256: `<value>`
- Before PNG SHA-256: `<value or n/a>`
- Related capture or matrix IDs: `<IDs>`
- Related defects: `<IDs or none>`

## Remediation

- Root cause: `<cause once known>`
- Chosen layout owner: `<the one owner changed>`
- Fix summary: `<presentation or deployment change>`
- Fix commit (full SHA): `<sha>`
- Regression test path and test name: `<path::test or n/a with reason>`
- Affected matrix slices to rerun: `<viewport/player/state IDs and hosted environments>`
- Affected-matrix command and result: `<exact command and result>`
- Complete-suite result: `<command, result, and durable log link if available>`

## Verification

- Corrected manifest/capture IDs: `<IDs>`
- Corrected manifest SHA-256 and acceptance eligibility: `<checksum, true/false>`
- Corrected invariant status and failures: `<passed/failed and exact failures>`
- After screenshot/video: `<durable link>`
- Affected matrix rerun result: `<pass/fail and evidence>`
- `make gui-visual-invariant-gate`: `<pass/fail and evidence>`
- `make check`: `<pass/fail and evidence>`
- Clean `make gui-visual-capture`, when preparing a candidate: `<pass/fail/n/a>`
- Affected hosted environments rerun: `<pass/fail/n/a and evidence>`
- Verified by: `<name>`
- Verified at (UTC): `<YYYY-MM-DD HH:MM>`

## Acceptance or deferral

Complete this section only when the defect is not fixed before release. An
unavailable test environment is a support decision, not a defect acceptance.

- Decision owner: `<name/role>`
- Decision: `accepted` / `support deferred` / `release blocked`
- Rationale and user impact: `<text>`
- Scope: `<platform, viewport, state, and release>`
- Mitigation: `<text or none>`
- Expiry or mandatory review point: `<date/milestone>`
- Decision record: `<durable link>`

Use `release blocked` only when the product owner chooses not to publish because
of the defect. Any accepted blocker, unreadable, or obstructive defect must be
called out explicitly in the release decision rather than hidden by a generic
pass result.
