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
  positions, where 1 is the winner. Finishes follow completed-hand elimination
  history, never final stack or seat order. Players eliminated in the same hand
  share a competition rank: if two players are the last eliminated before the
  winner, both finish second and the preceding finisher is fourth.
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
An invalid request contributes one fallback failure metric, while action-style
metrics consume only the validated fold-first fallback that was actually
applied. A fallback that itself fails validation stops execution and must not
produce a public action record or action-progress metric.
VPIP's conventional name is retained, but “put money in pot” is not used as a
Pokahdot product concept.

Aggregate profile, matchup, seat, and regime groups must include sample sizes
and confidence or bootstrap intervals. The independent unit is one completed
tournament identified by its effective seed, not an individual seat. When a
profile occupies multiple seats in one tournament, its seat metrics are
averaged into one profile observation; table-level groups likewise average
their correlated seats within the tournament. Raw behavior counts remain
pooled for point estimates, while uncertainty uses per-tournament rates.
Intervals are unavailable when fewer than two independent observations exist,
and bounded components use a Wilson half-width floor so an all-zero or all-one
sample does not report false certainty. Do not rank a candidate below a
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

`point_fitness` is the weighted sum before a penalty. `uncertainty_penalty` is
a separate finite-sample regularizer, `min(0.10, 0.10 / sqrt(N))`, where `N`
is the number of independent tournament/seed observations. It is not a
confidence interval. A plan must record its interval estimator and minimum
sample count. The formula compares mixed player counts and stack/blind regimes
without combining raw values with incompatible scales.

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
| `export-roster-manifest` | `--output <path>` | Export an immutable schema-2 baseline from the active curated roster. |

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
      "uncertainty_estimator": "normal_95"
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
seat map, and effective seed. A report derives `roster.version` from the
canonical immutable profile snapshots and records its catalog IDs. Each
tournament also records ordered `selected_profile_ids` matching its seat map,
so evaluation artifacts remain reproducible without relying on the
product-curated roster.

### 4.2.1 Curated roster baseline export

`export-roster-manifest` is the reproducible starting point for evaluating the
currently playable personalities. It reads the source-controlled
`PlayableBotRoster`, takes deep-copy snapshots of every active profile, and
writes a schema-2 manifest; it never changes the catalog or exposes its live
Resources to simulation. With no overrides it derives `batch_id` from the
roster version, uses seed `71001`, 100bb play (1000 chips, 5/10 blinds), cyclic
seat rotation, and 2520 tournaments. Rosters of at most nine profiles use one
`active_roster` matchup. Larger rosters use deterministic translated
nine-player matchups with equal appearances and complete pair coverage, so
the catalog can grow without increasing table capacity. The default count is
balanced for the current 18-profile roster and every single-table size.

Use `--batch-id`, `--seed`, and `--tournament-count` to name a distinct
benchmark. The current `standard` regime preset is the documented 100bb 5/10
baseline; other names are rejected instead of silently producing a different
structural experiment. The minimum-profile-sample threshold is preserved by
the generator, so an overridden count must be divisible by the active roster
size and large enough for every profile's configured minimum. Exported files
are baseline inputs, not promotion evidence: evaluate and confirm candidates
with the ordinary independent report workflow.

### 4.3 Report schema and privacy

The report schema mirrors the manifest's identity structure exactly: the
canonical `manifest` snapshot contains `profiles`, `regimes`, `matchups`, and
`evaluation_plans` unchanged, and every result references their corresponding
IDs. No report-only tournament configuration, unnamed regime, or alternate
matchup shape is permitted.

A schema-4 report contains:

```text
report_schema_version
manifest                         # exact canonical manifest snapshot
manifest_checksum
roster { version, profile_ids[] }
code_revision
execution_provenance { code_revision, source_state,
                       dirty_source_fingerprint, engine_version,
                       algorithm_versions }
command_version
shard { index, count }
started_at, finished_at
tournaments[] {
  tournament_index, plan_id, plan_tournament_index,
  regime_id, matchup_id, matchup_occurrence, rotation,
  effective_seed, seat_map, selected_profile_ids[], termination_reason, winner_profile_id,
  tournament_hand_count, profile_results[], diagnostics[]
}
aggregates {
  by_profile[], by_matchup[], by_seat[], by_regime[], by_evaluation_plan[]
}
traces[]
```

`simulation_cli_v5` is the first command version whose finishing positions use
elimination history. Reports produced by earlier command versions retain their
original bytes as historical artifacts, but their finish, top-third, and
derived fitness evidence must be recomputed before it is used for comparison,
selection, confirmation, or promotion.

`simulation_cli_v6` adds executable provenance. A run records its Git object,
dirty execution-source fingerprint when applicable, Godot version, and
versioned algorithms. Fitness requires exact provenance equality across
shards, while replay reports field-level provenance differences separately
from outcome differences. Existing schema-3/v5 reports are never rewritten;
rerun them under schema 4/v6 for current promotion evidence.

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
or trace fields. Sampled traces use a deterministic fixed-size reservoir over
all eligible decision and hand-outcome entries, giving every eligible entry
the same retention probability. If tournament execution fails, its report
keeps the safe partial traces, structured diagnostic, and complete
plan/regime/matchup-occurrence/rotation identity needed to reproduce it.

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
digest must match the stored record. Replay also selects the report's recorded
RNG stream derivation. New reports use `named_stream_sha256_v2`, while
`named_stream_v1` is retained for replaying immutable legacy reports.

## 5. External profile-evolution tool

Profile evolution is a separate non-interactive tool outside Godot's
simulation CLI. It never reads prompts, edits source files or `.tres` files in
place, promotes a candidate, or writes the playable roster. Its proposed
contract is:

```text
profile-evolution <command> [options]
```

| Command | Required options | Output |
| --- | --- | --- |
| `init-generation` | `--bounds <path> --population-size <count> --seed <seed> --output <path>` | generation manifest with candidate profiles and parentless lineage records |
| `evaluate-fitness` | `--generation <path> --report <path>` (repeatable) `--output <path>` | fitness artifact using section 3.2 and rejecting missing/incompatible plans |
| `select` | `--fitness <path> --elite-fraction <0.10..0.20> --output <path>` | selection artifact listing retained candidate IDs and evidence |
| `crossover` | `--selection <path> --seed <seed> --target-count <count> --output <path>` | child profile artifact with two parent IDs per recombined candidate |
| `mutate` | `--input <path> --seed <seed> --policy <path> --output <path>` | new candidates with every integer parameter clamped to inclusive 0–100 and each delta recorded |
| `build-lineage` | `--artifact <path>` (repeatable) `--output <path>` | deterministic lineage registry rebuilt from immutable generation, candidate, fitness, and selection history |
| `inspect-lineage` | `--registry <path> --candidate-id <id>` | read-only ancestry and evidence summary on stdout |
| `confirm-candidate` | `--registry <path> --candidate-id <id> --legacy-id <id>` (repeatable) `--historical-champion-id <id>` (repeatable) `--mirrored-report <path>` (repeatable) `--mixed-report <path>` (repeatable) `--output <path>` | independent confirmation evidence and promotion-gate result |
| `prepare-promotion-review` | `--confirmation <path>` (repeatable) `--reviewer-id <id> --output <path>` | one editable JSON plan listing every candidate, exact confirmation binding, and one initially `pending` decision field per candidate |
| `finalize-promotion-review` | `--plan <path> --confirmation <path>` (repeatable) `--output <path>` | one immutable `promotion_review_batch` after every candidate decision is changed to `approve` or `reject` and revalidated against its confirmation |
| `publish-profile` | `--confirmation <path> --review <path> --version <id> [--display-name <text>] [--project-root <path>]` | manually write one candidate approved in the consolidated review as a new no-clobber versioned `BotProfile` Resource; never edits the roster |
| `export-candidates` | `--registry <path> --confirmation <path>` (repeatable) `--candidate-id <id>` (repeatable) `--output <path>` | versioned review-only candidate bundle; never the playable roster |

All commands reject unknown fields and write atomically. Given identical
inputs and seeds they produce byte-equivalent canonical artifacts. Crossover
operates only on immutable `BotProfile` parameter vectors. Mutation uses
integer deltas, applies configured per-gene bounds no wider than 0–100, and
records pre-mutation value, delta, bounded result, and seed.

The deterministic commands use a tool-owned SplitMix64 generator and unbiased
bounded sampling, never Python's runtime-defined `random` implementation.
`gene_bounds` payloads contain one `minimum` and `maximum` for each of the
exact schema-2 genes (`tight_vs_loose`, `passive_vs_aggressive`,
`call_vs_raise`, and `bluff_rate`); all bounds and candidate values are
inclusive integers in `0..100`. `mutation_policy` payloads contain exactly an
inclusive `mutation_probability_percent` and `maximum_delta`, also in
`0..100`. A selection identifies its source generation, embeds its bounds,
and contains ordered complete candidate snapshots. Candidate and generation
artifacts preserve input order, use content-derived deterministic IDs, and
carry immutable bounds snapshots and parent IDs.

Initialization records the generation seed and empty parent lists. Crossover
uses two distinct selected parents for each child and records both ordered
parent IDs plus the chosen source parent for every gene. Mutation produces a
new candidate snapshot for each source candidate and records, in schema gene
order, `seed`, `gene`, `before`, requested `delta`, bounded `after`, and a
`clamped` flag. Every operation validates all candidates before producing an
output and leaves its input snapshots unchanged.

`evaluate-fitness` requires all shards for one identical schema-2 simulation
manifest. It verifies `simulation_cli_v6`, identical executable provenance, the canonical manifest checksum,
the exact ID/model/four-gene snapshot of every candidate, deterministic plan
and tournament identities, unique global indexes, complete shard and plan
coverage, successful tournaments, finite metric values, and bounded rates.
Traces and any card data are ignored. For each candidate and evaluation plan,
the tool counts observations and applies that plan's
`minimum_profile_samples`; candidates below any threshold are recorded as
ineligible and are not ranked.

The tool recomputes all six normalized components in section 3.2 for every
independent candidate tournament/seed observation, averaging repeated
candidate seats within a tournament before aggregation. It records component
means and normal 95% confidence-interval half-widths, or explicit missing
intervals when fewer than two units exist. Eligible fitness is the documented
point fitness minus its separate finite-sample penalty, clamped to `[0, 1]`.
The fitness artifact also records
source-generation identity, report and manifest checksums, shards, regime and
plan IDs, code revisions, sample counts, and explicit style checks. Version 1
requires zero invalid-action fallbacks and finite behavioral rates in
`[0, 1]`; a fallback makes that candidate ineligible, while malformed or
out-of-range report metrics invalidate the evaluation.
External evaluator v1 requires each plan to name `normal_95`; it rejects
`bootstrap_95` until a deterministic bootstrap contract is implemented. The
Godot schema-2 manifest validator enforces the same rule, so an estimator is
never accepted by one runtime and silently calculated differently by the
other. Godot aggregate `reportable` flags use the originating plan's
`minimum_profile_samples` (the strictest contributing plan for cross-plan
rows), not a separate default. Evaluator regime validation uses the product
table-size limit of two through nine players.

Elitist selection accepts an inclusive fraction from `0.10` through `0.20`
and retains `ceil(population_size * elite_fraction)` candidates; ceiling is
the normative rounding rule. It considers only eligible candidates with
finite numeric fitness, ordering them by fitness descending and then stable
candidate ID. Selection fails rather than weakening the contract when the
rounded count is below two crossover parents or eligible candidates are too
few. Its immutable artifact preserves each selected candidate's full fitness,
uncertainty, style, sample, and report evidence as a historical benchmark and
records the source fitness checksum plus a content-derived next-generation
manifest identity. Crossover consumes the selected snapshots without changing
those benchmarks.

The selection artifact's `next_generation_manifest` supplies the exact next
generation number and ID. Crossover uses that identity, and mutation preserves
it while emitting the final `generation_manifest` accepted by
`evaluate-fitness`. Thus intermediate crossover candidates and their final
mutated descendants belong to one explicitly named generation rather than
silently deriving competing IDs.

`build-lineage` rebuilds a registry from repeatable `--artifact` history
inputs; it does not update an existing registry in place. Inputs may be
generation manifests, intermediate candidate batches, fitness artifacts, and
selection artifacts. Every checksum and cross-artifact reference is verified,
and conflicting snapshots or orphan parents are rejected. Registry entries
contain the complete profile and creation provenance, generation/bounds,
evaluation configuration, regime and plan IDs, code revision, report
identities/checksums, normalized metrics, style/sample evidence, uncertainty,
fitness, and selection history for retained champions. Canonical checksum
ordering makes rebuilds byte-equivalent regardless of input order.
`inspect-lineage` validates the registry and emits the requested candidate's
ordered ancestors and evidence as JSON without modifying the registry.

`confirm-candidate` evaluates mirrored and mixed-table report sets
independently with the same strict schema-2 evaluator. Each manifest group
must contain complete shards and plans, the exact candidate snapshot,
successful tournaments, bounded metrics, and zero invalid-action fallbacks
for every participant. A plan's caller-selected `minimum_profile_samples`
controls exploratory fitness eligibility only and never promotion.

The fixed `promotion_evidence_v1` policy requires every confirmation matchup
to contain at least 300 candidate observations and at least 100 observations
in every candidate seat. The effective minimum is therefore
`max(300, 100 * player_count)`. For every declared benchmark present in a
matchup, the tool calculates the paired per-tournament difference between the
candidate's and benchmark's raw six-component composite scores. Improvement
is demonstrated only when `mean_difference - normal_95_half_width > 0` for
every comparison; a tie or overlapping interval is exploratory-only evidence.
The artifact records the fixed policy, actual coverage, comparisons, and
reasons. Mirrored evidence is heads-up and cyclic: it
must place the candidate in every seat against every declared legacy profile
and historical champion. Mixed evidence uses tables of at least three players
with cyclic candidate seat coverage, and every matchup must contain the
candidate plus both a declared legacy opponent and a declared historical
champion.

The original fitness evidence, mirrored confirmation, and mixed confirmation
must have disjoint report checksums, manifest checksums, and effective seed
identities; separate confirmation batches must also use disjoint effective
identities. The check uses each report's RNG derivation version. In particular,
legacy `named_stream_v1` ranges separated by 2147483647 still overlap, because
that derivation reduces seeds modulo 2147483647. Evidence recorded with
different RNG derivation versions is incompatible. The
immutable `confirmation` artifact records the exact candidate and registry
checksum, exact opponent profile snapshots, per-mode
fitness/component/style/sample evidence,
uncertainty, report identities, and explicit ineligibility reasons.
`promotion_eligible` is true only when all gates pass. This is an evidence
gate, not promotion: `export-candidates` accepts only eligible confirmations
bound to the same lineage registry and exact candidate snapshots, then emits
a `candidate_bundle` whose purpose is `review_only`. It never writes a roster,
Resource, or source file.

Every confirmation also records a genetic-diversity gate. For each declared
legacy or historical-champion opponent that uses `strategy_parameterized`, the
tool calculates the L1 distance across the four percentage genes. The nearest
such profile must be at least 10 total percentage points away; a missing
comparable profile or a smaller distance is ineligible. Separately, the
confirmation records count-weighted measured VPIP, PFR, bet/raise frequency,
bet frequency, and call-versus-raise share from its confirmation tournaments.

Passing confirmations are collected into one editable review plan. The plan
compares every proposed-candidate pair, recording both four-gene L1 distance
and absolute differences for the measured behavior rates. These are distinct
review signals: parameter distance is not mislabeled as observed behavior, and
passing candidate-versus-benchmark checks cannot hide two near-identical new
peers. No automatic threshold approves the proposed roster. The reviewer must
record exactly one `approve` or `reject` decision per candidate and may add a
display name or note.
Finalization rejects pending, missing, duplicate, altered, or ineligible
approvals and creates one immutable `promotion_review_batch` bound to every
exact confirmation. Neither the plan nor finalized review can publish a
Resource or modify the playable roster.

Every persisted artifact is a strict JSON object envelope containing exactly
`schema_version`, `type`, `tool_version`, `payload`, and `checksum`.
The checksum is SHA-256 over the sorted, compact, UTF-8 canonical envelope
with the `checksum` field omitted and one trailing newline. Writes reject an
existing destination and publish a flushed and synced temporary sibling via
an atomic hard link, then clean up and sync the parent directory. Exit code
`0` means success, `2` means invalid
arguments or JSON/schema input, `3` means an input/output failure, and `4`
means an invariant or unavailable workflow-stage failure. Machine diagnostics
are strict JSON on stderr; artifact-producing commands do not duplicate their
artifact on stdout.

The lineage registry records candidate ID, profile snapshot, parent IDs,
generation, creation command/version, seeds, regime and evaluation-plan IDs,
simulation report checksums, fitness components, uncertainty, code revision,
and champion selection history. Selected elites remain immutable historical
benchmarks; confirmation and export remain separate immutable artifacts.

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

Promotion is reviewed and non-automatic. One consolidated review plan covers
the whole proposed candidate set and must be finalized before any approved
candidate is published as a new, immutable, versioned `BotProfile` Resource.
The shared playable roster remains a separate source change. `publish-profile`
requires the exact eligible confirmation and its approved decision in the
finalized batch review, derives a versioned
profile ID, and writes only a new file under
`resources/bot_profiles/published/`; it rejects any existing destination. An
adjacent `.provenance.json` binds the published ID and exact Resource SHA-256
to its confirmation and consolidated-review checksums; neither file remains
if the pair cannot be published.
Publication never activates a profile or edits the roster. The curated roster
must retain the legacy Random, Tight Passive, and Loose Aggressive profiles
alongside any later promoted personalities. Never overwrite a published
profile, allow the external tool to edit the roster, or treat one batch win as
approval.

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
