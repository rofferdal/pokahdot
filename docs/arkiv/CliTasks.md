# CLI Tasks

This backlog contains unfinished tasks that exercise or compare the CLI.
Task status is preserved from the source backlog.

## Milestone dependency — Strategic default roster and optional legacy heuristics

Complete the core configuration and roster-selection gates in
[`CoreTasks.md`](CoreTasks.md) before beginning these tasks.

- [x] Replace obsolete roster-flag parsing, help text, startup reporting, and
  tests. Add the exact post-separator CLI flag
  `--use-legacy-models`, map it only to the shared `use_legacy_models` startup
  override, and reject no other normal startup inputs because of this change.
- [x] Update CLI startup and match diagnostics to state whether legacy
  heuristic models are included and to print the selected profile IDs/model
  families. Do not label either configuration as experimental or expose model
  parameters/RNG state.
- [x] Add parser, prompt, factory, and integration tests showing that the
  default CLI game selects only `StrategyDecisionModel` profiles; the flag
  selects the exact shared legacy/strategic seat split for 2–9 participants;
  fixed seeds reproduce selection; and one human remains required.

## CLI bot-profile startup presentation

- [x] **Show each assigned bot profile name at tournament start:** in the
  existing `Seat agents:` startup report, include every bot seat's selected
  `BotProfile.display_name` while preserving the human-seat row and the
  existing roster version, profile-ID, and model-family diagnostics. Render
  the names from the same seat-to-profile assignment used to construct the
  match; do not reselect profiles for display, replace the CLI's in-hand
  `Player N` labels, expose model parameters/RNG state, or reveal hidden cards.
  Add deterministic integration coverage for default strategic and optional
  mixed legacy/strategic rosters, asserting that every bot seat appears once
  with the display name of its assigned profile and the human seat never
  receives a bot profile name. `CliMatchCreationResult` now carries the match
  and startup diagnostics from one profile-selection pass. Deterministic
  default and mixed-roster integration coverage verifies exact seat rows,
  created-agent profile/model identity, stable mapping, and the preserved
  diagnostics; the focused 11-test CLI integration suite passes.

## Cross-interface release verification

- [x] Verify GUI and CLI produce equivalent core outcomes for the same seed
  and scripted actions. Seed `9123` and four explicit check-or-call actions
  now run through the CLI parser and GUI action control, with core cards,
  seats, pots, actions, events, and match state compared after every action.
- [x] Verify both GUI and CLI expose the optional startup overrides and
  produce identical validated core configuration from equivalent omissions and
  selections. Automated cases cover all-default omission, full explicit
  selection with legacy models, and each numeric field selected independently
  while the other three are omitted.
