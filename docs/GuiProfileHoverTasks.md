# GUI Bot Profile Hover Tasks

Status: complete; GPH-01–GPH-05 verified and native previews user-accepted on 2026-11-01.

Owner: GUI presentation and tournament composition adapters.

Implement tasks in order and update each checkbox only after its verification
evidence exists. This is an independent workstream linked from the
[current task index](README.md). It does not reorder the GUI replacement backlog
or accept its pending visual work.

## Required behavior

Hovering a pointer over a **bot seat's display-name label** shows a small box
whose text is exactly `Bot profile: <name of the bot profile>`, replacing the
placeholder with that bot's `BotProfile.display_name`. For example, a seat
named `Amina` using a profile named `Tight Passive` shows
`Bot profile: Tight Passive`. Keep the seat's assigned display name unchanged.

- Only the name region triggers this information; hovering the avatar, cards,
  stack, status band or remaining seat surface does not.
- Human seats show no bot profile tooltip. Use the authoritative human flag,
  not a name string, recipient seat or avatar, to distinguish humans.
- Hover eligibility follows real pointer input, not viewport size or device
  flags. Touch-emulated mouse events must not trigger unsolicited tooltips.
- Missing, blank or invalid profile metadata produces no tooltip. Never infer
  a profile from a display name, avatar, internal ID or decision model.
- Show only the public profile display name. Never pass profile parameters,
  agent/model objects, private cards, decision traces or RNG state to a tooltip.
- Preserve tournament actions, seat-detail taps, display names and focus order.
  Touch-only input gains no unsolicited popup or new gesture. A new touch
  equivalent is outside this feature's required scope.
- Keep folded/eliminated seats associated with their original tournament bot
  while their names remain displayed. Refreshes, rotation, resize and layout
  changes must not reassign profiles or leave stale popups behind.

## Planning baseline and proposed seam

The following facts describe the pre-implementation baseline. GPH-01–GPH-04
below record the implemented metadata path, renderer and verification evidence:

- [`BotProfile`](../scripts/core/agents/bot_profile.gd) is a Resource with
  `profile_id`, `model_id`, `display_name` and private strategy parameters.
  [`BotAgent`](../scripts/core/agents/bot_agent.gd) retains profile/model IDs,
  not the profile display name; its testing/simulation diagnostics are outside
  GUI rendering.
- [`GuiMatchFactory`](../scripts/gui/gui_match_factory.gd) selects profiles
  through `PlayableBotRoster` and knows the selected profile for each bot seat
  when constructing agents. This is the suitable existing composition seam
  for copying public display-name strings without inspecting live bot behavior.
- [`GuiMatchCreationResult`](../scripts/gui/gui_match_creation_result.gd),
  [`GuiStartupConfigAdapter`](../scripts/gui/gui_startup_config_adapter.gd) and
  [`StartupConfigController`](../scripts/gui/startup_config_controller.gd)
  currently carry separate name/avatar assignments to
  [`GuiReplacementTableController`](../scripts/gui/gui_replacement_table_controller.gd).
- [`TableViewModel`](../scripts/gui/view_models/table_view_model.gd) and
  [`SeatViewModel`](../scripts/gui/view_models/seat_view_model.gd) create detached
  presentation values from recipient-safe state and assignment snapshots.
  They currently have no profile-name tooltip field.
- [`GuiSeatPanel`](../scripts/gui/components/gui_seat_panel.gd) and
  [`GuiSeatToken`](../scripts/gui/components/gui_seat_token.gd) render names
  through their authored fields. The token itself receives input while its
  children ignore it, so name-only hover hit testing needs explicit design.

The proposed design was to copy a typed `seat -> public profile display name` mapping
at GUI tournament creation, retain defensive snapshots along the existing
adapter path, and build an optional tooltip string in the pure seat model.
This adds no GUI dependency or presentation mapping to core `GameView`,
`Player`, configuration or events. GPH-01 confirmed this seam and GPH-02–GPH-04
implemented and verified it; current ownership is documented in the architecture.

The contract must work through the current adapters and authored `SeatPanel`,
`HeroPanel` and `SeatToken` components without adding layout policy.

## Ordered implementation tasks

### GPH-01 — Confirm public metadata and interaction contract

Status: complete (2026-11-01).

- [x] Confirm `BotProfile.display_name` as the sole approved public name,
  including curated strategic and optional legacy roster profiles. Define
  validation for blank/invalid names and safe diagnostic logging without
  strategy data; unavailable metadata suppresses the tooltip.
- [x] Record the mapping's ownership, copy/lifetime rules and adapter API in
  [ARCHITECTURE.md](ARCHITECTURE.md), clearly distinguishing public name strings
  from full profile Resources. Confirm reset/failure/new-tournament behavior.
- [x] Inspect current hit testing and keyboard focus at each name rendering
  path. Decide whether existing focusable seat-detail targets can also expose
  the name information accessibly without changing tab order. Labels are not
  silently made focusable; if no suitable target exists, record keyboard
  expansion as a separate scoped decision before implementation.

Evidence: inspected `BotProfile`, both roster families, the factory/result,
startup adapter/controller, session, seat/table models, SeatPanel/HeroPanel and
all three SeatToken scenes. The approved ownership/API, exact validation,
reason-only diagnostics and keyboard/touch scope are recorded in
[the architecture contract](ARCHITECTURE.md#gui-adapter). Current compact scenes
have no `DetailsButton`: the focusable token root owns detail input and its
name Label ignores mouse input. This is a documentation/source inspection
checkpoint; no hover functionality or visual acceptance is claimed.

### GPH-02 — Carry stable public names into pure presentation models

Status: complete. Depends on GPH-01.

- [x] Capture profile display names at `GuiMatchFactory`'s existing per-seat
  profile selection loop, with no extra selection or RNG consumption. Carry
  defensive copies through creation result, startup adapter/controller and
  table binding; clear them on failed startup/reset and replace them for a new
  tournament. Preserve compatibility for recipient-safe fixture bindings with
  unavailable metadata.
- [x] Extend `TableViewModel`/`SeatViewModel` with typed detached values for
  tooltip eligibility and exact text. Human and missing-profile cases produce
  empty tooltip text even if a mapping contains an erroneous human entry.
  Include metadata changes in presentation cache invalidation.
- [x] Verify model and adapter behavior using existing seat/table-model,
  startup-adapter and name-assignment test suites. Cover changed source
  snapshots, human recipient variations, missing/blank names, multiple bots
  sharing a profile, distinct visual/profile names, eliminated seats and new
  tournaments. Compare seeded game, name and avatar results before/after to
  prove this passive feature consumes no RNG or changes gameplay.

Verification (2026-11-01): six focused GUT suites passed **57 tests / 1,454
assertions**: `test_gui_bot_profile_metadata.gd`, `test_gui_seat_view_model.gd`,
`test_gui_table_view_model.gd`, `test_gui_startup_config_adapter.gd`,
`test_gui_player_name_foundation.gd` and `test_gui_table_session.gd`. Command:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s
addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_gui_bot_profile_metadata.gd,res://tests/unit/test_gui_seat_view_model.gd,res://tests/unit/test_gui_table_view_model.gd,res://tests/unit/test_gui_startup_config_adapter.gd,res://tests/unit/test_gui_player_name_foundation.gd,res://tests/unit/test_gui_table_session.gd -gexit`.
Log: `localtmp/gph02-focused.log`. Changed metadata files pass `gdlint` and
`gdformat --check`. Tests cover copied metadata, exact/invalid Unicode names,
human recipient variations, repeated profiles, eliminated/folded seats,
reset/rebind and both creation/start failures; warning assertions verify fixed
seat/reason diagnostics without rejected identity text.

Seed comparison uses `localtmp/gph-baseline/seed_snapshot.gd`: before/after
artifacts match for all six 2/6/9-seat strategic/legacy cases (seed 5150,
starting stack 40), including 260 recipient-safe transitions through final
winners and unchanged visual names/avatars. Evidence:
`localtmp/gph-baseline/comparison.log`, `before.json` and `after.json` in the
same directory. This confirms metadata capture adds no selection/RNG use.

### GPH-03 — Render a passive, themed name tooltip

Status: complete. Depends on GPH-02.

- [x] Bind model tooltip text to the actual name hit region in current full
  seat and compact-token paths. Resolve the phone `DetailsButton` overlay
  deliberately so pointer hover works over the name while existing taps still
  open seat details. Keep the rest of the seat free of this tooltip.
  Test real-pointer hover on compact layouts and suppress touch-emulated hover.
- [x] Choose the smallest Godot tooltip/custom-tooltip solution that satisfies
  containment and hit testing. Consult current official Godot `Control` and
  theme documentation before implementation. Consume the shared theme and
  its single built-in font, maintain at least 20 logical/CSS px tooltip text,
  readable contrast/padding and the full unambiguous profile name. Wrap long
  names within the usable safe area rather than shrinking text or truncating
  identity. Do not alter seat layout minima or card geometry to fit the popup.
- [x] Keep the popup non-focusable and pointer-passive, with no buttons or game
  commands. Specify a consistent hover delay; close on leaving the name,
  switching names, modal opening, name removal, tournament rebind or layout
  rebuild. Reposition or close on resize/rotation without stale seat content.
  Verify containment using actual usable geometry, including edge seats.
- [x] Provide the same model/rendering contract to authored replacement seat
  components as they become available, using shared tooltip styling and
  geometry inputs rather than platform checks or new viewport breakpoints.

Evidence (2026-11-01): authored `BotProfileTooltip.tscn` and
`GuiBotProfileTooltip` use shared OverlayPanel/BodyText styling at 20 px,
name-only target rectangles, a 0.5-second real-pointer delay and passive input.
The current compact root owns details; no DetailsButton exists. Touch-emulated
input, touches, clicks, pressed keys, modals, refresh/rebind and geometry/layout
changes cancel the popup. No focus order, mouse filter, seat minimum or card
geometry changes were required. All authored SeatPanel/HeroPanel/SeatToken
paths share the table's target contract. Long text wraps inside actual usable
bounds; text that cannot physically fit in full at 20 px suppresses this
optional popup rather than truncating identity.

Official Control, Theme and InputEvent references and the final renderer
lifetime/geometry design are linked in
[ARCHITECTURE.md](ARCHITECTURE.md#gui-adapter). Focused hover integration:
`godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=
-gtest=res://tests/unit/test_gui_bot_profile_hover.gd -gexit` passed 6/6 tests,
68 assertions (`localtmp/gph-baseline/hover.log`). A long-name regression caught
zero-width Label minimum-height feedback; preassigning its wrap width fixes
containment. Native captures pass: `localtmp/gui-elements/gph-desktop.png`
(1600×1200, popup 270×60) and `gph-compact-edge-long.png` (390×844, usable
12/24/366/790, popup 366×122), with JSON metadata. `make docs-check`, focused
`gdlint`/`gdformat` and `git diff --check` pass. User visual acceptance remains
pending in GPH-04; these native previews do not certify browser/device support.

### GPH-04 — Verify privacy, interaction and visual acceptance

Status: complete (2026-11-01); automated checks pass and the user accepted both
native previews.

- [x] Add focused GUI integration coverage for entering/leaving the name,
  non-name hover, humans, missing metadata, long profile names and switching
  bot seats. Exercise full seats and tokens, modal/rebind/rebuild cleanup,
  refresh, elimination, resize/rotation and composition switches. Confirm
  seat-detail taps, keyboard focus order and game actions still work.
- [x] Assert presentation values retain only permitted strings/scalars, with
  no profile Resource, strategy parameters, decision trace, private cards or
  RNG references. Re-run recipient privacy and assignment-isolation coverage,
  the complete existing test suite and applicable GUI/policy checks; record
  commands/results here before checking implementation tasks complete.
- [x] Capture representative desktop and pointer-capable compact-layout
  previews, including a safe-area edge and long-name case, under
  `localtmp/gui-elements/`. Record viewport, input mode and screenshot paths.
  Stop and show the new GUI box to the user for acceptance before continuing
  with further GUI design work. Record requested revisions and acceptance
  separately from automated verification; headless checks do not certify
  browser/device usability or visual acceptance.

Focused interaction evidence: `test_gui_bot_profile_hover.gd` passes six tests
and 68 assertions. Existing table-model privacy coverage now recursively permits
only detached presentation model types and string/scalar leaves, including a
profile-populated model, human suppression and snapshot isolation; table-model
and metadata suites pass 12 tests / 3,517 assertions
(`localtmp/gph-privacy-review.log`). Full verification is recorded below when
its required checks finish.

Full verification command:
`make GODOT=/Applications/Godot.app/Contents/MacOS/Godot check gui-current-invariant-gate`
(`localtmp/gph-full-check.log`). `make check` passes: 914 Godot unit/integration
tests / 311,504 assertions, 17 layout-characterization tests, 237 Python tests,
GDScript lint/format, documentation links and GUI policy/coverage checks. The
four current invariant matrices all pass (M3, phone, iPad and desktop). The command
exits 0. The existing log scanner reports zero unexpected engine errors; expected
negative-test diagnostics remain asserted by GUT. The independent final
`make docs-check`, `gdlint`, `gdformat --check` and `git diff --check` also pass;
logs are under `localtmp/gph-final-*.log`.

Native Compatibility previews use non-emulated mouse-motion events. Desktop:
1600×1200, usable `(16, 20, 1568, 1160)`, popup `(133, 400.5, 270, 60)`,
`localtmp/gui-elements/gph-desktop.png`. Compact long name: 390×844, usable
`(12, 24, 366, 790)`, popup `(12, 188, 366, 122)`,
`localtmp/gui-elements/gph-compact-edge-long.png`. Both retain full plain text,
20 px built-in font and usable-area containment; companion JSON records geometry,
input mode and source hashes. Capture command:
`godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --script tests/visual/gui_bot_profile_hover_capture.gd`.
Capture log: `localtmp/gph-baseline/capture.log`. These native synthetic-fixture
previews do not certify exported-browser or physical-device behavior.

Visual acceptance: the user accepted both previews on 2026-11-01 with
“Accept previews; continue to GPH-05”. No visual revisions were requested.
Automated invariant checks remain separate from that acceptance.

### GPH-05 — Reconcile current documentation and completion evidence

Status: complete (2026-11-01).

- [x] Reconcile implemented behavior in the root README, product specification,
  architecture, current task index and affected GUI testing/developer guides.
  Preserve archived records and unrelated GUI replacement statuses. Record
  remaining keyboard/touch decisions explicitly rather than claiming them as
  delivered behavior.
- [x] Run `make docs-check` and `git diff --check`, retain verification logs
  under `localtmp/`, and update this backlog's statuses with test and acceptance
  evidence. Session-only captures remain ignored local artifacts.

Evidence: reconciled root `README.md`, `ProjectDescription.md`, `ARCHITECTURE.md`,
the current task index, `GUI_VISUAL_TESTING.md`, and developer composition/testing
guides against the implemented metadata and renderer behavior. Native acceptance
is recorded in GPH-04; browser/device verification and profile-specific keyboard
or touch access remain separate scope. Archived records and unrelated GUI
acceptance are preserved. `make docs-check` passes (27 tests, 29 Markdown files,
64 GUI policy scripts, coverage observer checks); `git diff --check` passes.
Logs: `localtmp/gph05-agent-docs-check.log`, `localtmp/gph05-agent-diff-check.log`,
and final root verification under `localtmp/gph-final-*.log`.
