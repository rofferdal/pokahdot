# GUI Bot Profile Hover Tasks

Status: planned; implementation has not started.

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

## Source facts and proposed seam

These are current implementation facts, not completed hover functionality:

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
  [`PokerTableController`](../scripts/gui/poker_table_controller.gd).
- [`TableViewModel`](../scripts/gui/view_models/table_view_model.gd) and
  [`SeatViewModel`](../scripts/gui/view_models/seat_view_model.gd) create detached
  presentation values from recipient-safe state and assignment snapshots.
  They currently have no profile-name tooltip field.
- [`GuiTableSeatFactory`](../scripts/gui/gui_table_seat_factory.gd) creates
  `Name` labels in `create_seat_identity()` and `create_phone_opponent_token()`.
  Phone tokens also have a full-seat `DetailsButton` overlay, so attaching a
  tooltip to the underlying label alone cannot establish correct hit testing.

Proposed design: copy a typed `seat -> public profile display name` mapping
at GUI tournament creation, retain defensive snapshots along the existing
adapter path, and build an optional tooltip string in the pure seat model.
This adds no GUI dependency or presentation mapping to core `GameView`,
`Player`, configuration or events. Confirm and document the final seam during
GPH-01; this plan does not change the implemented architecture.

The contract must work through current adapters and carry into authored
`SeatPanel`, `HeroPanel` and `SeatToken` components as they replace runtime
builders. Do not wait for that replacement or add new legacy layout policy to
replacement components.

## Ordered implementation tasks

### GPH-01 — Confirm public metadata and interaction contract

Status: not started.

- [ ] Confirm `BotProfile.display_name` as the sole approved public name,
  including curated strategic and optional legacy roster profiles. Define
  validation for blank/invalid names and safe diagnostic logging without
  strategy data; unavailable metadata suppresses the tooltip.
- [ ] Record the mapping's ownership, copy/lifetime rules and adapter API in
  [ARCHITECTURE.md](ARCHITECTURE.md), clearly distinguishing public name strings
  from full profile Resources. Confirm reset/failure/new-tournament behavior.
- [ ] Inspect current hit testing and keyboard focus at each name rendering
  path. Decide whether existing focusable seat-detail targets can also expose
  the name information accessibly without changing tab order. Labels are not
  silently made focusable; if no suitable target exists, record keyboard
  expansion as a separate scoped decision before implementation.

### GPH-02 — Carry stable public names into pure presentation models

Status: not started. Depends on GPH-01.

- [ ] Capture profile display names at `GuiMatchFactory`'s existing per-seat
  profile selection loop, with no extra selection or RNG consumption. Carry
  defensive copies through creation result, startup adapter/controller and
  table binding; clear them on failed startup/reset and replace them for a new
  tournament. Preserve compatibility for recipient-safe fixture bindings with
  unavailable metadata.
- [ ] Extend `TableViewModel`/`SeatViewModel` with typed detached values for
  tooltip eligibility and exact text. Human and missing-profile cases produce
  empty tooltip text even if a mapping contains an erroneous human entry.
  Include metadata changes in presentation cache invalidation.
- [ ] Verify model and adapter behavior using existing seat/table-model,
  startup-adapter and name-assignment test suites. Cover changed source
  snapshots, human recipient variations, missing/blank names, multiple bots
  sharing a profile, distinct visual/profile names, eliminated seats and new
  tournaments. Compare seeded game, name and avatar results before/after to
  prove this passive feature consumes no RNG or changes gameplay.

### GPH-03 — Render a passive, themed name tooltip

Status: not started. Depends on GPH-02.

- [ ] Bind model tooltip text to the actual name hit region in current full
  seat and compact-token paths. Resolve the phone `DetailsButton` overlay
  deliberately so pointer hover works over the name while existing taps still
  open seat details. Keep the rest of the seat free of this tooltip.
  Test real-pointer hover on compact layouts and suppress touch-emulated hover.
- [ ] Choose the smallest Godot tooltip/custom-tooltip solution that satisfies
  containment and hit testing. Consult current official Godot `Control` and
  theme documentation before implementation. Consume the shared theme and
  its single built-in font, maintain at least 20 logical/CSS px tooltip text,
  readable contrast/padding and the full unambiguous profile name. Wrap long
  names within the usable safe area rather than shrinking text or truncating
  identity. Do not alter seat layout minima or card geometry to fit the popup.
- [ ] Keep the popup non-focusable and pointer-passive, with no buttons or game
  commands. Specify a consistent hover delay; close on leaving the name,
  switching names, modal opening, name removal, tournament rebind or layout
  rebuild. Reposition or close on resize/rotation without stale seat content.
  Verify containment using actual usable geometry, including edge seats.
- [ ] Provide the same model/rendering contract to authored replacement seat
  components as they become available, using shared tooltip styling and
  geometry inputs rather than platform checks or new viewport breakpoints.

### GPH-04 — Verify privacy, interaction and visual acceptance

Status: not started. Depends on GPH-03.

- [ ] Add focused GUI integration coverage for entering/leaving the name,
  non-name hover, humans, missing metadata, long profile names and switching
  bot seats. Exercise full seats and tokens, modal/rebind/rebuild cleanup,
  refresh, elimination, resize/rotation and composition switches. Confirm
  seat-detail taps, keyboard focus order and game actions still work.
- [ ] Assert presentation values retain only permitted strings/scalars, with
  no profile Resource, strategy parameters, decision trace, private cards or
  RNG references. Re-run recipient privacy and assignment-isolation coverage,
  the complete existing test suite and applicable GUI/policy checks; record
  commands/results here before checking implementation tasks complete.
- [ ] Capture representative desktop and pointer-capable compact-layout
  previews, including a safe-area edge and long-name case, under
  `localtmp/gui-elements/`. Record viewport, input mode and screenshot paths.
  Stop and show the new GUI box to the user for acceptance before continuing
  with further GUI design work. Record requested revisions and acceptance
  separately from automated verification; headless checks do not certify
  browser/device usability or visual acceptance.

### GPH-05 — Reconcile current documentation and completion evidence

Status: not started. Depends on GPH-04 and user visual acceptance.

- [ ] Reconcile implemented behavior in the root README, product specification,
  architecture, current task index and affected GUI testing/developer guides.
  Preserve archived records and unrelated GUI replacement statuses. Record
  remaining keyboard/touch decisions explicitly rather than claiming them as
  delivered behavior.
- [ ] Run `make docs-check` and `git diff --check`, retain verification logs
  under `localtmp/`, and update this backlog's statuses with test and acceptance
  evidence. Session-only captures remain ignored local artifacts.
