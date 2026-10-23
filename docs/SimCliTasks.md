# Simulation CLI Tasks

This plan covers the non-interactive command-line adapter for deterministic,
bot-only tournament evaluation. It depends on the headless simulation harness
described in [`SimCoreTasks.md`](SimCoreTasks.md); it does not replace that core work or change the
interactive player CLI.

## Contract and composition

- [x] Define typed simulation manifest, report, shard, and command-option
  Resources/value objects for current schema version 2. Keep profile snapshots
  immutable and validate them independently of the playable roster.
- [x] Add a dedicated `scripts/simulation/simulation_cli_app.gd` process entry
  point. It must not use `cli_app.gd`, terminal prompts, `CliCommandLoop`, or
  a `HumanAgent`.
- [x] Add a simulation-only composition path that permits an all-bot match
  without relaxing the normal GUI and interactive CLI exactly-one-human
  invariant.
- [x] Implement deterministic tournament planning: zero-based indices,
  `seed_start + index`, round-robin matchup scheduling, cyclic seat rotation
  derived from each matchup's occurrence count, and non-overlapping
  `index/count` shards that filter the global plan.

## Commands and artifacts

- [x] Implement strict argument parsing and usage for `help`, `validate`,
  `run`, `inspect`, and `replay`, including the documented exit codes and
  rejection of unknown flags and manifest fields.
- [x] Implement `validate` and `run --dry-run` so they emit the canonical
  normalized manifest and planned indexes without starting a tournament.
- [x] Implement `run` with progress/diagnostics on stderr, JSON or text output
  selection, explicit overwrite protection, atomic report creation, and the
  documented separation between compact stdout summaries and the complete
  artifact written to `--output`.
- [x] Define and persist the versioned batch report: manifest snapshot and
  checksum, code revision when available, shard descriptor, effective seeds,
  evaluation-plan and regime IDs, matchup occurrence and rotation, final seat
  maps, defined non-monetary per-tournament outcomes, aggregate metrics, and
  diagnostics. Its identity and configuration structure must mirror the
  manifest exactly.
- [x] Implement bounded trace modes (`none`, `errors`, and deterministic
  `sampled`) so ordinary reports and traces never contain unrevealed opponent
  hole cards, including after tournament completion, and normal batch output
  remains bounded.
- [x] Implement `inspect` as a read-only report summary and `replay` from the
  stored tournament record. Replay must compare its winner, termination
  reason, hand count, and metric digest with the source record.

## Verification and adoption

- [x] Unit-test command and manifest validation: missing/unknown fields,
  profile and matchup consistency, parameter bounds, invalid shards, and
  output-path safeguards.
- [x] Integration-test a small all-bot batch for determinism, cyclic seat
  rotation, non-overlapping shard coverage, report atomicity, and identical
  replays.
- [x] Regression-test that normal GUI and interactive CLI startup still reject
  zero-human configurations and continue to read human terminal input only in
  the interactive adapter.
- [x] Run a reviewed smoke batch with multiple bot profiles and preserve its
  manifest/report pair as a reproducible example before using results for
  profile selection.
- [x] Finish by updating `README.md` with a detailed user guide for validating
  manifests, running and sharding simulations, inspecting reports, replaying
  a tournament, retaining artifacts, and performing the external bot-profile
  evolution and reviewed promotion workflow end to end. This is the only
  README user-guide task and begins only after both the simulation CLI and the
  external profile-evolution tool exist.
