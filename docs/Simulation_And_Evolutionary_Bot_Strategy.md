# Automated Tournament Simulation and Bot-Profile Evolution Strategy

## 1. Authority and scope

[`ProjectDescription.md`](ProjectDescription.md) remains normative for poker
rules and product behavior. [`ARCHITECTURE.md`](ARCHITECTURE.md) defines the
implementation boundaries. This document specifies the non-interactive
simulation adapter and an external bot-profile evolution workflow.

Simulation v1 evaluates immutable `BotProfile` parameter vectors. It never
evolves, generates, or rewrites GDScript decision-model code. Use **profile
evolution**, **candidate profile**, and **profile genome** consistently for
this workflow.

The simulation path:

- is headless and non-interactive;
- creates an all-bot tournament only through `scripts/simulation/`;
- reuses the product poker core, action validation, recipient-safe views, and
  deterministic RNG services;
- may vary player count, starting stack, starting small blind, and starting
  big blind; and
- always uses the normative fixed hand-based blind progression. Alternate
  blind schedules are deferred.

## 2. Reproducible evaluation

### 2.1 Batch architecture and sharding

The simulation CLI runs one versioned manifest or one deterministic shard of
it. External worker pools may run shards in separate OS processes. An
unsharded tournament has a stable zero-based `tournament_index`; its effective
seed is `seed_start + tournament_index`.

Shard `i/n` contains exactly the global indexes for which
`tournament_index % n == i`, with `0 <= i < n`. This rule gives exhaustive,
non-overlapping shards that may complete in any order without changing seeds,
matchups, rotations, or outcomes.

### 2.2 Matchups and cyclic seat rotation

Each evaluation plan names an ordered list of matchup IDs. Tournament `t`
selects:

```text
matchup_plan_offset = t % evaluation_plan.matchup_ids.size()
matchup_id = evaluation_plan.matchup_ids[matchup_plan_offset]
matchup_occurrence = t / evaluation_plan.matchup_ids.size()  # integer division
rotation = matchup_occurrence % regime.player_count
```

Apply `rotation` cyclically to the selected matchup's profile list. Rotation
is derived from that matchup's zero-based occurrence count, not directly from
the global tournament index. Therefore every matchup receives every cyclic
seat rotation once per complete block of `player_count` occurrences even when
several matchups are interleaved. Sharding filters the already planned global
indexes and never replans local indexes.

### 2.3 Strategy parameter contract

`StrategyDecisionModel` schema 2 has four profile parameters:

- `tight_vs_loose`;
- `passive_vs_aggressive`;
- `call_vs_raise`; and
- `bluff_rate`.

Every value is an integer percentage in the inclusive range **0–100**.
Manifests, profile Resources, generation artifacts, mutation bounds, examples,
and reports use those integer values. Non-integer parameter values are invalid.
`bluff_rate` becomes a probability only at the decision point through
`bluff_rate / 100.0`.

## 3. Metrics and fitness

### 3.1 Outcome and style metrics

Pokahdot v1 has no money, buy-in, prize pool, payout, monetary return, or paid
places. Simulation must not report financial or prize-derived metrics.

For each profile, report these outcome metrics with sample counts:

- **Tournament win rate:** tournaments won divided by tournaments completed.
- **Average finishing position:** arithmetic mean of ordinal finishing
  positions, where 1 is the winner. Tied eliminations use the deterministic
  position order emitted by the core.
- **Top-third rate:** fraction finishing at or above
  `ceil(player_count / 3)`; for example, positions 1–2 at six players.
- **Chip differential:** `final_stack - starting_stack` per tournament, plus
  its aggregate mean. The sum across all seats in a normally completed
  tournament is zero.
- **Hands survived:** number of completed tournament hands for which the
  profile's seat was active at the start of the hand. Also report survival
  ratio: `hands_survived / tournament_hand_count`.
- **Blind-normalized chip metric (`bnc_per_100`):** for every hand in which the
  seat is active, calculate
  `(stack_after_hand - stack_before_hand) / big_blind_at_hand_start`. Sum those
  values and divide by `hands_observed`, then multiply by 100. Report both the
  numerator sum and `hands_observed`; never mix starting blinds with later
  blind levels.

Style metrics are non-financial and include VPIP (voluntarily put chips in the
pot), preflop raise rate, aggression factor, eligible bluff frequency,
call-versus-raise split, invalid-action fallbacks, and their denominators.
VPIP's conventional name is retained, but “put money in pot” is not used as a
Pokahdot product concept.

Aggregate profile, matchup, seat, and regime groups must include sample sizes
and confidence or bootstrap intervals. Do not rank a candidate below a
documented minimum sample threshold.

### 3.2 Compatible fitness normalization

Fitness combines only the defined non-monetary metrics. Convert each
per-tournament observation to `[0, 1]` before averaging:

```text
win_score = 1 for a win, otherwise 0
finish_score = (player_count - finishing_position) / (player_count - 1)
top_third_score = 1 when finishing_position <= ceil(player_count / 3), else 0
chip_score = (chip_differential + starting_stack) / (player_count * starting_stack)
survival_score = hands_survived / tournament_hand_count
blind_chip_score = (clamp(bnc_per_100, -100, 100) + 100) / 200
```

For normally completed equal-stack tournaments, `chip_score` is 0 for a
zero-stack finish and 1 for a winner holding all chips. The v1 composite is:

```text
fitness =
    0.30 * mean(win_score) +
    0.20 * mean(finish_score) +
    0.15 * mean(top_third_score) +
    0.15 * mean(chip_score) +
    0.10 * mean(survival_score) +
    0.10 * mean(blind_chip_score) -
    uncertainty_penalty
```

`uncertainty_penalty` is in `[0, 0.10]` and is defined by the evaluation plan
as the capped mean 95% confidence-interval half-width of the six normalized
components. A plan must record its estimator and minimum sample count. The
formula compares mixed player counts and stack/blind regimes without combining
raw values with incompatible scales.

## 4. Simulation CLI contract

### 4.1 Boundary and invocation

The simulation CLI is not the interactive player CLI and must not use
`scripts/cli/cli_app.gd`, `StartupConfigPrompt`, `CliCommandLoop`, or stdin.
Its target entry point is:

```text
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- <command> [options]
```

| Command | Required options | Purpose |
| --- | --- | --- |
| `help` | none | Print usage and supported schema versions. |
| `validate` | `--config <path>` | Validate and print the canonical manifest and complete plan without playing. |
| `run` | `--config <path> --output <path>` | Run one batch or shard and atomically write one report. |
| `inspect` | `--report <path>` | Print report identity, effective plan, and summary without playing. |
| `replay` | `--report <path> --tournament-index <index>` | Re-run exactly one stored tournament and compare its outcome digest. |

`run` also accepts `--shard <index>/<count>` (default `0/1`),
`--format json|text` (default `json`), `--trace none|errors|sampled` (default
`errors`), `--trace-sample <count>` for sampled traces, `--dry-run`, and
`--overwrite`. `replay` accepts `--format json|text` and optional
`--output <path>`. `validate` and `inspect` never write artifacts.

`--dry-run` performs parsing, validation, seed planning, regime and matchup
selection, rotation, and shard filtering without playing or writing a report.
Existing output is rejected unless `--overwrite` is explicit. Report writes
are atomic through a temporary sibling followed by rename.

### 4.2 Manifest schema

A manifest contains explicit regimes and evaluation plans. One regime per
manifest is also valid, but it is still represented in the `regimes` array.
Unknown fields, duplicate IDs, unsupported versions, invalid matchup sizes,
invalid plan references, fractional or out-of-range strategy parameters, and
invalid tournament settings are rejected.

```json
{
  "schema_version": 2,
  "batch_id": "gen_004_baseline",
  "seed_start": 410000,
  "profiles": [
    {
      "profile_id": "candidate_g4_03",
      "model_id": "strategy_parameterized",
      "parameters": {
        "tight_vs_loose": 42,
        "passive_vs_aggressive": 38,
        "call_vs_raise": 38,
        "bluff_rate": 11
      }
    },
    {
      "profile_id": "baseline_a",
      "model_id": "strategy_parameterized",
      "parameters": {
        "tight_vs_loose": 30,
        "passive_vs_aggressive": 19,
        "call_vs_raise": 19,
        "bluff_rate": 5
      }
    }
  ],
  "regimes": [
    {
      "regime_id": "heads_up_100bb",
      "player_count": 2,
      "starting_stack": 1000,
      "starting_small_blind": 5,
      "starting_big_blind": 10,
      "blind_progression": "normative_hand_based_v1"
    }
  ],
  "matchups": [
    {
      "matchup_id": "candidate_vs_baseline",
      "profile_ids": ["candidate_g4_03", "baseline_a"]
    }
  ],
  "evaluation_plans": [
    {
      "plan_id": "heads_up_confirmation",
      "regime_id": "heads_up_100bb",
      "matchup_ids": ["candidate_vs_baseline"],
      "tournament_count": 1000,
      "seat_rotation": "cyclic",
      "minimum_profile_samples": 200,
      "uncertainty_estimator": "bootstrap_95"
    }
  ]
}
```

Each profile is a complete immutable snapshot rather than a reference to a
mutable roster. Each matchup must contain exactly the referenced regime's
`player_count` profile IDs for every plan that uses it. All plans use cyclic
rotation. The single permitted blind progression identifier explicitly binds
every regime to the product schedule.

The global tournament plan concatenates evaluation plans in manifest order.
Within each plan, its local index selects matchups and rotations by section
2.2. The global index assigns the seed and shard. Reports record global index,
plan-local index, regime ID, matchup ID, matchup occurrence, rotation, final
seat map, and effective seed.

### 4.3 Report schema and privacy

The report schema mirrors the manifest's identity structure exactly: the
canonical `manifest` snapshot contains `profiles`, `regimes`, `matchups`, and
`evaluation_plans` unchanged, and every result references their corresponding
IDs. No report-only tournament configuration, unnamed regime, or alternate
matchup shape is permitted.

A version 1 report contains:

```text
report_schema_version
manifest                         # exact canonical manifest snapshot
manifest_checksum
code_revision
command_version
shard { index, count }
started_at, finished_at
tournaments[] {
  tournament_index, plan_id, plan_tournament_index,
  regime_id, matchup_id, matchup_occurrence, rotation,
  effective_seed, seat_map, termination_reason, winner_profile_id,
  tournament_hand_count, profile_results[], diagnostics[]
}
aggregates {
  by_profile[], by_matchup[], by_seat[], by_regime[], by_evaluation_plan[]
}
traces[]
```

Every `profile_results` entry contains finishing position, tournament-win
indicator, top-third indicator, starting/final stack, chip differential,
hands survived, survival ratio, the `bnc_per_100` numerator and denominator,
the computed `bnc_per_100`, style metrics, and metric denominators. Aggregates
contain the same named metrics, sample counts, and uncertainty estimates.

Privacy is strict: ordinary reports and every trace mode **never contain
unrevealed opponent hole cards**, even after a tournament finishes. They may
contain a profile's own decision-time cards in that profile's recipient-safe
trace and cards legitimately revealed by core showdown events. Internal deck
order, mucked cards, and another recipient's unrevealed cards are never report
or trace fields.

### 4.4 Stdout, stderr, and `--output`

- `validate --format json` writes exactly one canonical manifest-and-plan JSON
  document to stdout. Text mode writes the equivalent human-readable plan.
- `run --dry-run` follows the same rule and writes the planned shard indexes,
  seeds, regimes, matchups, occurrences, and rotations to stdout.
- A successful `run` writes the complete report only to `--output`. JSON
  stdout contains exactly one small completion object with report path,
  checksum, shard, and aggregate summary; text stdout contains the equivalent
  human-readable completion summary. It never duplicates the full report.
- `inspect` writes the requested report summary to stdout and never changes
  the report.
- `replay` without `--output` writes the replay comparison and recipient-safe
  trace to stdout. With `--output`, it writes the complete replay artifact to
  that path and stdout contains only the small completion summary.
- Progress, warnings, and diagnostics always go to stderr. No command writes
  progress to stdout.

Exit code `0` means verified success; `2` means invalid arguments or manifest;
`3` means input/output or report-read failure; and `4` means a simulation
invariant, unexpected action fallback, or replay mismatch.

`replay` reuses the stored manifest snapshot, seed, regime, matchup,
occurrence, rotation, and seat map. It may increase trace detail without
changing those values. Winner, termination reason, hand count, and metric
digest must match the stored record.

## 5. External profile-evolution tool

Profile evolution is a separate non-interactive tool outside Godot's
simulation CLI. It never reads prompts, edits source files or `.tres` files in
place, promotes a candidate, or writes the playable roster. Its proposed
contract is:

```text
profile-evolution <command> [options]
```

| Command | Required inputs | Immutable output |
| --- | --- | --- |
| `init-generation` | bounds, population size, generation seed | generation manifest with candidate profiles and parentless lineage records |
| `evaluate-fitness` | generation manifest, completed simulation reports | fitness artifact using section 3.2 and rejecting missing/incompatible plans |
| `select` | fitness artifact, elite fraction (10–20%) | selection artifact listing retained candidate IDs and evidence |
| `crossover` | selection artifact, crossover seed, target count | child profile artifact with two parent IDs per recombined candidate |
| `mutate` | child/profile artifact, mutation seed, mutation policy | new candidates with every integer parameter clamped to inclusive 0–100 and each delta recorded |
| `inspect-lineage` | lineage registry, candidate ID | read-only ancestry and evidence summary on stdout |
| `export-candidates` | evaluated candidate IDs and destination path | versioned candidate bundle for review; never the playable roster |

All commands reject unknown fields and write atomically. Given identical
inputs and seeds they produce byte-equivalent canonical artifacts. Crossover
operates only on immutable `BotProfile` parameter vectors. Mutation uses
integer deltas, applies configured per-gene bounds no wider than 0–100, and
records pre-mutation value, delta, bounded result, and seed.

The lineage registry records candidate ID, profile snapshot, parent IDs,
generation, creation command/version, seeds, regime and evaluation-plan IDs,
simulation report checksums, fitness components, uncertainty, code revision,
and export history. Selected elites remain immutable historical benchmarks.

## 6. Validation and promotion

Fixed-seed validation established that schema-1 `passive_vs_aggressive` and
`call_vs_bet` were commutative inputs to one AND gate. Schema 2 deliberately
separates opening check-versus-bet behavior (`passive_vs_aggressive`) from
facing-wager call-versus-raise behavior (`call_vs_raise`). Continue to verify
each parameter with VPIP, bet/raise frequency, contextual action splits, and
eligible bluff frequency before evolving profiles. See
`StrategyParameterValidation.md` for the baseline, migration, and regression
batch.

Candidates require independent, seat-rotated confirmation against legacy
bots and historical champions across applicable regimes. Reject candidates
that depend on invalid-action fallbacks, only win one narrow matchup, or fail
documented style expectations.

Promotion is reviewed and non-automatic. A reviewer may export an approved
candidate as a new, immutable, versioned `BotProfile` Resource and update one
shared playable roster in a separate source change. Never overwrite a
published profile, allow the external tool to edit the roster, or treat one
batch win as approval. Preserve behavioral diversity and a meaningful set of
hand-authored profiles.

## 7. Examples

```bash
# Validate without playing or writing an artifact.
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  validate --config simulations/gen_004.json

# Run shard 2 of 8. Its report is written only to the requested path.
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  run --config simulations/gen_004.json --shard 2/8 \
  --output artifacts/gen_004_shard_2.json --trace sampled --trace-sample 5

# Replay tournament 417 and print a recipient-safe text trace.
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  replay --report artifacts/gen_004_shard_2.json --tournament-index 417 \
  --format text
```
