# CLI Tasks

This backlog contains unfinished tasks that exercise or compare the CLI.
Task status is preserved from the source backlog.

## Milestone dependency — Strategic default roster and optional legacy heuristics

Complete the core configuration and roster-selection gates in
[`CoreTasks.md`](CoreTasks.md) before beginning these tasks.

- [ ] Remove parsing, help text, startup reporting, and tests for
  `--allow-experimental-models`. Add the exact post-separator CLI flag
  `--use-legacy-models`, map it only to the shared `use_legacy_models` startup
  override, and reject no other normal startup inputs because of this change.
- [ ] Update CLI startup and match diagnostics to state whether legacy
  heuristic models are included and to print the selected profile IDs/model
  families. Do not label either configuration as experimental or expose model
  parameters/RNG state.
- [ ] Add parser, prompt, factory, and integration tests showing that the
  default CLI game selects only `StrategyDecisionModel` profiles; the flag
  selects the exact shared legacy/strategic seat split for 2–9 participants;
  fixed seeds reproduce selection; and one human remains required.

## Cross-interface release verification

- [ ] Verify GUI and CLI produce equivalent core outcomes for the same seed
  and scripted actions.
- [ ] Verify both GUI and CLI expose the optional startup overrides and
  produce identical validated core configuration from equivalent omissions and
  selections.
