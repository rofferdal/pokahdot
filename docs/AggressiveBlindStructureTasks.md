# Optional aggressive blind progression

Status: implementation complete; ABS-01–07 verified. Changes await user review. Created 2026-11-02.
Owner: this backlog, indexed by [docs/README](README.md).

## Requested behavior

Add an optional **75% increase per blind level** (multiply by **1.75**).
The default remains **25%** (multiply by **1.25**). The percentage is an
increase over the current big blind, not a percentage of the initial blind.

- GUI: an unchecked startup checkbox labeled **Aggressive blind levels**.
  Show only that label and checkbox; omit percentage suffixes and blind-rate
  guidance from the start page.
- CLI: `--aggressive-blinds` after Godot's `--` separator enables +75%.
  Omitting it uses +25% with the normal defaults.
- Interactive CLI setup: `aggressive-blinds on` and `aggressive-blinds off`
  select the mode before starting. Show the selected increase in the setup
  summary; the command changes the setting without starting a tournament.
- Freeze the selection when constructing the tournament. It is not an
  in-play command. GUI validation, resizing and opening the Rules page must
  preserve the selection. Fresh application startup defaults to unchecked;
  no new persistent settings system is required.

### GUI scope boundary

GUI changes are limited to the **start page**: its checkbox, label,
startup layout, adapter and configuration wiring. The game screen layout is
out of scope. Do not change table geometry, seats, cards, board, pot/blind
placement, action controls, menus, overlays, fonts or responsive layout rules
for the running game. Do not add an in-game mode badge or toggle.

The existing game-screen blind display continues to render the current blind
values supplied by the core; only those values advance faster when selected.
Shared Rules content may explain the new option within the existing Rules
presentation, without changing its layout or navigation.

The existing hand-count interval remains: levels starting with at least five
active players last twice that captured player count; otherwise they last ten
completed hands. Change blinds only after settlement/elimination and before
the next hand. The active-player snapshot remains fixed throughout a level.

Retain upward rounding to the next even big blind, the small blind at half
that value, and the big-blind cap of 1,000,000. The configured starting blinds
are used as supplied for level 1. Thereafter both modes use the same rounding
and cap rules; counters continue at the cap.

| Level | Standard (+25%) | Aggressive (+75%) |
| ---: | ---: | ---: |
| 1 | 5 / 10 | 5 / 10 |
| 2 | 7 / 14 | 9 / 18 |
| 3 | 9 / 18 | 16 / 32 |
| 4 | 12 / 24 | 28 / 56 |
| 5 | 15 / 30 | 49 / 98 |

The realized percentage can exceed the selected rate because of even-integer
rounding. No other tournament rules or bot parameters change.

## Implementation

Carry one boolean, `aggressive_blinds`, through `TournamentConfig`,
`StartupOverrides`, `ConfigResolver` and `ResolvedTournamentConfig`.
The default is `false`; an explicit false override must disable a true
configured value rather than being treated as an omitted override.

`TournamentMatch` passes the resolved selection into `BlindLevelProgression`.
Extend its constructor compatibly with an optional final argument, defaulting
to standard progression. Preserve that selection in `copy()`. Only the core
calculates growth: use integer ratios **5/4** or **7/4**, with overflow guards
adjusted for the selected numerator before multiplication, then even rounding
and saturation. GUI and CLI only select and display the option.

The existing simulation regime already has a `blind_progression` identifier.
Keep `normative_hand_based_v1` meaning exactly the old +25% schedule. Add a
separate `aggressive_hand_based_v1` identifier for +75%, and map it explicitly
into resolved match configuration. This preserves historical manifests and
lets reports/checkpoints distinguish the two rules without adding an ambiguous
boolean to serialized reports. Existing generators continue to emit the
standard identifier by default. Unknown identifiers must fail validation.

## Tasks and acceptance criteria

- [x] **ABS-01 — Update the rules contract and establish baseline tests.**
  Update [ProjectDescription §4.1](ProjectDescription.md#41-table-stacks-and-blind-progression)
  and the current implementation architecture when implementation begins.
  Describe both modes, defaults, rounding, interval and cap. Run the existing
  configuration and blind-progression tests before refactoring.
  Acceptance: approved user requirements are reflected in the normative spec;
  unchanged baseline tests pass. Later tasks verify the implemented
  controls and their integration.

- [x] **ABS-02 — Add resolved configuration and core progression.**
  Update `scripts/core/config/` types, defaults and resolution; propagate the
  flag through every construction/copy path into `TournamentMatch` and
  `BlindLevelProgression`. Keep omitted arguments/resources compatible.
  Add tests for default false, true/false overrides, snapshot isolation,
  mode-preserving copies, both sequences above, odd starting blinds,
  arithmetic boundaries, cap saturation and continued level counters.
  Acceptance: +25% remains the exact previous behavior; +75% uses the same
  hand-completion boundaries and active-player snapshot rules. Explicitly
  test elimination on a level boundary and that a completed hand keeps its
  original blinds. Fixed-seed standard-mode regression remains unchanged.

- [x] **ABS-03 — Add the GUI startup checkbox.**
  Wire `scenes/main.tscn`, `StartupConfigController`, `GuiStartupConfigAdapter`
  and the startup layout/snapshot path into the same core override. Follow
  existing startup reset behavior, defaulting to off; preserve user selection
  through validation failures and Rules navigation. Display exactly
  "Aggressive blind levels", without percentage guidance. Include keyboard/touch
  activation.
  Acceptance: checked and unchecked starts create the correct resolved mode;
  the checkbox is readable and reachable on supported phone, tablet and
  desktop layouts without obscuring Start or other controls. Existing
  participant limits and startup inputs remain usable. No GUI-side growth math.
  Changes to shared scene/controller files must touch only their startup
  responsibilities. Game-screen layout code and scene geometry remain intact.

- [x] **ABS-04 — Add the CLI flag and setup commands.**
  Extend `CliStartupArguments`, its help, `StartupConfigPrompt` and startup
  diagnostics. Add `--aggressive-blinds` plus the setup commands above.
  A flag seeds setup with true; `aggressive-blinds off` can explicitly override
  it. Preserve the choice through configure/retry and existing short-stack
  setup paths. Invalid command arguments produce actionable feedback without
  changing the current selection. Reject the setting as an in-play command.
  Acceptance: absent option gives +25%; flag/on gives +75%; off restores +25%.
  Duplicate flags and malformed commands are tested. GUI and CLI resolve
  identical configurations from equivalent inputs.

- [x] **ABS-05 — Preserve simulation and evidence compatibility.**
  Extend `SimulationRegime`, `SimulationManifest`, `SimulationMatchFactory`
  and relevant report/Python validators to recognize the two identifiers.
  Use the manifest's existing field/checksum in reports, replay and checkpoint
  identities; changing the mode must reject resume against old checkpoints.
  Keep `SimulationManifestGenerator` and prepared experiments standard by
  default. An explicitly aggressive regime must produce +75% play and retain
  that identity through serialization and revalidation.
  Acceptance: old standard fixtures still parse and reproduce standard
  progression; both modes round-trip, unknown modes fail, and incompatible
  manifests cannot be silently pooled as one comparison. No bot competition
  or profile-promotion campaign is required for this feature.

- [x] **ABS-06 — Update shared rules, help and current documentation.**
  Update `TournamentRulesDocument` text and CLI help to explain both choices.
  Reuse the existing GUI Rules presentation without layout changes.
  Update README startup examples, current architecture, core-domain
  reference, simulation contract and relevant developer guides. Show:
  `godot --headless --path . --script res://scripts/cli/cli_app.gd -- --aggressive-blinds`.
  Preserve historical records and their +25% evidence.
  Acceptance: current instructions consistently state default +25%, optional
  +75%, identical level timing, even rounding and cap. All local links pass
  checks from tracked files alone.

- [x] **ABS-07 — Final integration and release verification.**
  Test both modes end-to-end across core construction, GUI startup and CLI
  startup with the same seed and inputs. Verify level transitions, chip
  conservation and default-mode compatibility. Run changed-code suites,
  applicable start-page layout checks, lint/format and documentation checks under
  `AGENTS.md`; GUI and CLI tests apply because both adapters change here.
  Export and verify a Web release, then exercise the checkbox through an
  exported startup check. Retain the development-content exclusion rules.
  Acceptance: both controls work, default play remains +25%, all required
  checks pass, and task statuses are backed by results. Review the diff to
  verify that GUI edits are confined to startup responsibilities and that
  game-screen geometry/layout rules are unchanged. Preserve existing game-screen
  layout baselines; do not rebaseline them to accommodate this option. Optional manual
  phone/desktop play supplements automated verification.

## Execution order and human action

Implement ABS-01 then ABS-02. GUI, CLI and simulation integration depend on the
core contract; complete each with its focused tests before final reconciliation
and end-to-end checks. Reuse the existing config, startup, blind-progression,
shared-rules and simulation systems.

No additional policy decision or routine approval is needed to implement this
plan once the user asks to start. Manual device testing is optional. Committing,
pushing, publishing a Web site and running bot-selection campaigns are separate
from this implementation plan.

## Execution evidence

### ABS-01 — verified 2026-11-02

The existing configuration, blind-progression and tournament integration
baseline passes 28 tests (229 assertions), recorded in local-only
`localtmp/aggressive_blinds/baseline.log`. The normative rules now specify the
approved optional +75% structure, with +25% default and unchanged timing/cap.
Implementation tasks remain unchecked until their behavior is verified.

### ABS-02 — verified 2026-11-02

The shared configuration now carries a default-false `aggressive_blinds`
setting, including explicit false overrides and an immutable runtime snapshot.
The core uses checked 5/4 or 7/4 growth and preserves the mode when copying
progression. All 35 focused configuration/progression/tournament tests pass
(560 assertions), covering real hand-boundary transitions and elimination at
the level boundary. Adapter integration follows in the next tasks.

### ABS-03 — verified 2026-11-02

The start-page checkbox defaults off and resolves the shared configuration.
Its selection survives validation, Rules navigation and resizing. The compact
start page uses a local options grid; the game-screen layout is untouched.
All 38 focused native GUI tests pass (719 assertions). Four exported Chromium
canvas cases pass for pointer/touch input with standard/aggressive selection;
evidence is local-only under `localtmp/aggressive_blinds/web-startup-verified/`.

### ABS-04 — verified 2026-11-02

The CLI accepts `--aggressive-blinds` and the setup commands
`aggressive-blinds on|off`; off overrides an enabled flag. Setup edits preserve
the choice through configure retries, Rules and the short-stack preset. Mode
changes during play are rejected. Setup summaries and reproduction flags show
the selected mode. All 68 focused native tests pass (729 assertions), plus
16 real process tests. Evidence: local-only `localtmp/aggressive_blinds/cli-implementation.log`
and `cli-process-implementation.log`.

### ABS-05 — verified 2026-11-02

Simulation regimes now distinguish `normative_hand_based_v1` (+25%) from
`aggressive_hand_based_v1` (+75%). Both resolve into the same immutable core
setting; factory and batch copies retain it. Unknown modes fail validation,
and reports with different manifests cannot be silently pooled. Old default
fixtures and schema versions are unchanged. A real simulation verifies the
next-hand 14/18 big-blind transition; CLI run/inspect/replay and checkpoint
mode-mismatch tests pass. Verification: 49 Godot tests (1,844 assertions) and
35 Python tests. Evidence: local-only `localtmp/aggressive_blinds/simulation.log`
and `simulation-python.log`.

### ABS-06 — verified 2026-11-02

Shared Rules copy now explains default +25% and optional +75%, both example
sequences, fixed selection during play and unchanged hand intervals/cap. All
18 shared Rules/CLI reference tests pass (207 assertions). Current README,
architecture, simulation contract and developer startup/configuration guides
now match implemented controls and serialization. Documentation link tests
pass, including a tracked-files-only snapshot; the new backlog is registered
with intent-to-add, while its contents remain unstaged for user review.
Historical archives and published campaign evidence remain intact.

### ABS-07 — completed and verified 2026-11-02

The full `make check GODOT=/Applications/Godot.app/Contents/MacOS/Godot`
passes: **987 Godot tests, 374 Python tests, and 17 layout-characterization
tests**. The final exported startup suite passes four Chromium canvas cases
(pointer/touch × standard/aggressive). GUI and CLI composition were also driven
with seed 9123 through hand 11: matching core state reaches a big blind of 14
or 18 according to the selected mode. The standard defaults remain +25%.

A production Web release exported to local-only
`localtmp/aggressive_blinds/release/` passes `make verify-web-release-output`.
The new regression tests and evidence do not rely on previous session outputs.
The GUI scope audit confirms only startup GUI files and startup-form scene
nodes changed; every non-startup scene block is unchanged, as are the game
layout sources and layout baselines. No game-screen mode control was added.

Verification metadata, test logs, screenshots, parity results and release
payloads are local-only under `localtmp/aggressive_blinds/`. The summary is
`verification.json`; full checks are in `make_check.log`, with final browser
evidence under `web-startup-final/`. No commits, pushes or deployments were
performed. Implementation is ready for the user's review before committing.

### Start-page label refinement — verified 2026-11-02

The user requested only the checkbox and **Aggressive blind levels** label.
Removed the percentage suffix and the separate default-rate guidance label
from the scene, startup layout and snapshot bindings. Both pointer/touch Web
cases now assert the exact label. The selected behavior and CLI/Rules
explanations retain the same +25% default and +75% option.

All 38 focused native GUI tests pass (709 assertions), and all four exported
Chromium startup cases pass for both modes and pointer/touch input. Local-only
evidence: `localtmp/aggressive_blinds/simple-label.log` and `web-simple-label/`.
The full-suite results above describe the initial implementation; this copy-only
refinement was checked with the affected GUI and browser suites.
