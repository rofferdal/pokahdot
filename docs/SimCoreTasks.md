# Simulation and Profile-Evolution Core Tasks

This backlog implements the simulation and profile-evolution framework described in
`Simulation_And_Evolutionary_Bot_Strategy.md`. It owns domain-safe simulation
composition, deterministic evaluation, metrics, profile evolution, and
promotion evidence. Command parsing, terminal output, and artifact I/O stay in
the simulation CLI adapter; their tasks are in `SimCliTasks.md`.

The implementation must preserve the existing poker rules, agent information
boundary, and normal product requirement of exactly one human player. A
simulation may use zero humans only through its dedicated composition path.

## Milestone 1 — Simulation foundation

- [x] Define a simulation-only tournament construction contract that permits
  all-bot seats while preserving the normal GUI and interactive CLI
  exactly-one-human validation contract.
- [x] Build a headless simulation composition root outside `scripts/core/` and
  the product GUI/CLI startup paths. It must create bot agents from immutable
  profile snapshots and advance a tournament without rendering or stdin.
- [x] Reuse `rng_stream_factory.gd` to create deterministic, named RNG streams
  for tournament construction, seat/profile assignment, bot decisions, and
  any trace sampling. Record enough seed identity to reproduce each stream.
- [x] Define typed, core-independent simulation input and outcome values:
  tournament index, effective seed, matchup, final seat mapping, completion
  result, and failure diagnostics. Keep serialization and command-line
  concerns out of the game core.
- [x] Add unit and integration tests proving that an all-bot tournament
  completes with legal actions and that normal product construction still
  rejects zero-human configurations.

## Milestone 2 — Deterministic batch evaluation and observability

- [x] Implement a deterministic batch runner that evaluates supplied fixed
  profile snapshots over explicit tournament indexes without changing the
  poker engine or the profiles during a tournament.
- [x] Implement round-robin matchup scheduling and cyclic seat rotation so a
  profile is evaluated across every applicable seat. Derive rotation from the
  zero-based occurrence count of the selected matchup, not the global
  tournament index. Test interleaved matchups, full balanced rotations,
  deterministic seeds, and shards that filter rather than replan indexes.
- [x] Implement structural-regime support for the approved tournament settings
  (heads-up, 6-max, full-ring, stack depths, and starting blind values).
  Simulation v1 may vary only player count, starting stack, starting small
  blind, and starting big blind; every regime uses the normative fixed
  hand-based blind progression. Validate every regime using ordinary
  tournament configuration rules.
- [x] Capture event-derived per-hand and per-tournament metrics: winner/end
  reason, tournament win rate, average finishing position, top-third rate,
  chip differential, hands survived and survival ratio, documented
  blind-normalized chip change per 100 observed hands, VPIP, PFR, aggression
  factor, invalid-action fallbacks, and sample counts/denominators.
- [x] Add bounded strategy-decision and hand-outcome tracing built on
  `strategy_decision_trace.gd`. It must be optional, deterministic when
  sampled, and ordinary reports and every trace mode must never contain
  unrevealed opponent hole cards, including after tournament completion.
- [x] Define aggregate calculations and uncertainty reporting for profile,
  matchup, seat, and regime groups. Do not rank candidates from a sample too
  small to report its uncertainty. Normalize every fitness component to
  `[0, 1]` using the documented formula before combining mixed regimes.
- [x] Test metric definitions with hand-crafted event sequences and test that
  two identical seeded batches produce identical outcomes, mappings, metrics,
  and sampled traces.

## Milestone 3 — Coordinate the simulation CLI introduction

- [x] Complete the typed simulation manifest, report, shard, and option
  contracts jointly with the first task in `SimCliTasks.md`. The CLI manifest
  remains the versioned adapter input; the batch runner consumes validated
  typed values rather than JSON or command-line strings. Include explicit
  regimes and evaluation plans (one named regime remains valid), and make the
  report's identity/configuration structure mirror the manifest exactly.
- [x] After Milestones 1 and 2 can execute one tournament, introduce the
  dedicated CLI entry point and `help`/`validate`/`run --dry-run` tasks from
  `SimCliTasks.md`. Verify the execution plan exposes the same indexes, seeds,
  matchups, and rotations the batch runner will use.
- [x] After metrics and trace payloads are stable, introduce the `run`, report
  persistence, and trace-mode tasks from `SimCliTasks.md`. Define one
  canonical report mapping from batch outcomes to artifact fields and test it
  end-to-end.
- [x] After reports are reproducible, introduce the `inspect` and `replay`
  tasks from `SimCliTasks.md`. Replay must call the same simulation composition
  path and compare the stored outcome digest rather than trusting text output.
- [x] Complete the CLI unit, integration, and normal-product regression tasks
  only after the corresponding core milestones pass. Keep one small
  manifest/report fixture for cross-layer tests and do not make the core test
  suite depend on filesystem command invocation.

## Milestone 4 — Validate the current parameter model

- [ ] Run controlled fixed-seed batches that isolate each current strategy
  parameter (`tight_vs_loose`, `passive_vs_aggressive`, `call_vs_bet`, and
  `bluff_rate`) and measure its effect on VPIP, bet/raise frequency,
  call-versus-raise splits, and eligible bluff frequency. Treat every
  parameter as an inclusive integer percentage from 0 through 100.
- [ ] Investigate the overlapping aggression controls. If measurement confirms
  that their combined rolls do not provide distinct observable behavior,
  simplify or redefine the parameter contract and update its validation,
  profiles, tests, and simulation manifest version deliberately.
- [ ] Keep hand-potential and sizing weights fixed until evidence shows the
  existing parameter genome cannot express useful variation. Add a new gene
  only with a bounded range, a behavioral metric, a reproducibility test, and
  migration handling for profile snapshots.

## Milestone 5 — External profile-evolution workflow

- [ ] Define a separate non-interactive external profile-evolution tool with
  commands for generation initialization, fitness evaluation, selection,
  crossover, bounded mutation, lineage inspection, and candidate export. It
  creates immutable artifacts and must not mutate an in-game profile Resource,
  edit model code, or write the playable roster.
- [ ] Implement deterministic candidate initialization, crossover, and bounded
  integer mutation (including recorded mutation seed, per-gene delta, and
  inclusive 0–100 bounds). Reject invalid candidates before scheduling
  simulations.
- [ ] Implement fitness evaluation from batch reports using outcome metrics,
  style checks, the documented normalized non-monetary formula,
  variance/uncertainty penalties, and a documented minimum sample threshold.
- [ ] Implement elitist selection that retains the selected 10–20% candidates
  as immutable historical benchmarks and produces a versioned next-generation
  manifest.
- [ ] Maintain a champion lineage registry containing profile snapshot, parent
  IDs, generation, configuration/regimes, code revision, report identities,
  metrics, and uncertainty. Add tests for lineage completeness and repeatable
  generation creation.
- [ ] Run independent mirrored and mixed-table confirmation batches against
  legacy bots and historical champions before a candidate is eligible for
  promotion.

## Milestone 6 — Evidence-based promotion and release

- [ ] Centralize the curated playable bot roster so GUI and interactive CLI
  composition use the same catalog. Validate model/profile resolution, stable
  unique IDs, roster-size limits, and deterministic sampling without
  replacement.
- [ ] Define a reviewed promotion gate requiring independent reports, valid
  action behavior, uncertainty bounds, behavioral diversity, and the exact
  candidate snapshot. A batch win alone must not update the playable roster.
- [ ] Publish approved candidates as new immutable versioned `BotProfile`
  Resources; never overwrite a published profile. Preserve a meaningful set of
  hand-authored/legacy personalities alongside promoted candidates.
- [ ] Record roster version and selected profile IDs in normal-match diagnostics
  and simulation reports so both production matches and evaluations remain
  reproducible.
- [ ] Run a multi-profile smoke batch and the complete headless test suite.
  Coordinate the final README user guide task in `SimCliTasks.md` only after
  the simulation, profile-evolution, report, and promotion workflows are executable.
