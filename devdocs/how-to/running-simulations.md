# How-To Guide: Running Simulations

Pokahdot includes a headless, non-interactive simulation harness in `scripts/simulation/`. It is designed to evaluate bot profiles, test parameter variations, and measure statistical fitness across thousands of tournaments without rendering or GUI overhead.

The authoritative [simulation contract](../../docs/Simulation_And_Evolutionary_Bot_Strategy.md)
owns formats, defaults, streams, statistics, and confirmation policy. This guide
provides commands for that contract.

---

## 1. Simulation Architecture Overview

The simulation runner operates in batch:
1. **Manifest ([`SimulationManifest`](../../scripts/simulation/simulation_manifest.gd))**: A versioned JSON file (schema 2) specifying profiles, matchups, structural regimes (stacks, blinds, player count), and evaluation plans.
2. **Planner ([`SimulationBatchPlanner`](../../scripts/simulation/simulation_batch_planner.gd))**: Expands the manifest into a deterministic, zero-based sequence of `SimulationTournamentInput` records with cyclic seat rotations.
3. **Runner ([`SimulationBatchRunner`](../../scripts/simulation/simulation_batch_runner.gd))**: Instantiates `TournamentMatch` with all-bot construction contracts (`TournamentConstructionContract.simulation()`), stepping matches to completion.
4. **Metrics ([`SimulationTournamentMetrics`](../../scripts/simulation/simulation_tournament_metrics.gd))**: Calculates VPIP (voluntarily put chips in pot), PFR (preflop raise), win rates, and chip fitness.
5. **Report ([`SimulationReport`](../../scripts/simulation/simulation_report.gd))**: Schema 4 (`simulation_cli_v6`) JSON artifact storing complete outcomes, aggregates, recipient-safe traces, deterministic roster provenance derived from immutable profile snapshots, and ordered `selected_profile_ids` per tournament.

Simulation manifests are not subject to the playable product roster's limit of
25 `StrategyDecisionModel`-based profiles. Use that freedom for larger
candidate pools and profile-evolution experiments; the limit is enforced only
when validating `PlayableBotRoster` for GUI and CLI games.

---

## 2. Using the Simulation CLI

The simulation entry point is [`scripts/simulation/simulation_cli_app.gd`](../../scripts/simulation/simulation_cli_app.gd). Pass arguments after `--`:

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- <command> [options]
```

### Available Commands

| Command | Purpose | Example |
| :--- | :--- | :--- |
| `help` | Show command usage and options | `... -- help` |
| `validate` | Check manifest syntax and plan inputs without playing | `... -- validate --config manifest.json --format json` |
| `run` | Execute tournament batch and write atomic report | `... -- run --config manifest.json --output report.json` |
| `inspect` | Summarize metrics from a saved report | `... -- inspect --report report.json --format text` |
| `replay` | Re-run a previous report tournament to verify deterministic reproduction | `... -- replay --report report.json --tournament-index 0` |
| `export-roster-manifest` | Export the active playable roster as an immutable baseline manifest | `... -- export-roster-manifest --output roster.json` |

### CLI Options Summary

- `--config PATH`: Path to the input `SimulationManifest` JSON file (for `validate`, `run`).
- `--output PATH`: Destination path for the report or replay artifact (writes atomically).
- `--report PATH`: Path to a completed `SimulationReport` JSON file (for `inspect`, `replay`).
- `--format json|text`: Output formatting (defaults to `json` for all commands).
- `--overwrite`: Permitted only when intentionally replacing an existing output file. (By default, existing outputs are protected).
- `--shard INDEX/COUNT`: Deterministic parallelization slice (e.g. `0/4`, `1/4`).
- `--dry-run`: Validates plan and prints shard metadata without playing tournaments.
- `--checkpoint DIR`: Run checkpoint directory (default `OUTPUT.checkpoint`); use a separate directory for each shard.
- `--resume`: Reuse validated completed records from the same checkpoint, manifest, provenance, shard and trace settings. Supported only by `run`.
- `--trace none|errors|sampled`: Decision trace recording mode (`errors` by default for `run` and `replay`).
- `--trace-sample COUNT`: Maximum trace entries per tournament (decisions and hand outcomes) to deterministically sample when `--trace sampled` is enabled.
- `--tournament-index INDEX`: Specific tournament index to reproduce during `replay` (required; no default index).
- `--batch-id ID`: Optional batch identity for `export-roster-manifest`; the default derives from the roster version.
- `--seed INTEGER`: Non-zero export seed (default `71001`).
- `--tournament-count COUNT`: Export plan count; it must be divisible by the active roster size and satisfy the configured sample minimum (default `2520`).
- `--regime-preset standard`: The explicit 100bb, 5/10 roster-table export preset. Other preset names are rejected.

Manifest and effective seeds must satisfy the
[lossless JSON seed bounds](../../docs/Simulation_And_Evolutionary_Bot_Strategy.md#21-batch-architecture-and-sharding)
across the entire plan, including seeds generated after the starting value.

### Exporting a Curated-Roster Baseline

Use this command when the evaluation should begin with every active playable
profile. It takes deep-copy snapshots, so later catalog edits cannot mutate an
exported manifest or invalidate its checksum.

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  export-roster-manifest --output artifacts/curated_roster_baseline.json \
  --batch-id curated_baseline --seed 71001 --tournament-count 2520
```

The output is atomic and refuses to replace an existing file unless
`--overwrite` is supplied. Immediately validate the exact file with
`validate --config artifacts/curated_roster_baseline.json` before scheduling
its reports. The default batch ID is `roster_<ROSTER_VERSION>`; use an
explicit `--batch-id` when the artifact needs a more descriptive experiment
identity.

For at most nine active profiles, the generated manifest contains one
`active_roster` matchup and one `roster_<count>_max` 100bb regime. Larger
catalogs use a `roster_9_max` regime and deterministic translated matchups that
give every profile equal appearances, complete pair coverage, and aggregate
cyclic seat balance. This preserves the nine-player simulation limit. The
manifest is a reproducible baseline, not a promotion result. To test a
candidate, keep this export unchanged and build a separately validated
candidate manifest with balanced coverage.

---

## 3. Step-by-Step: Running a Batch

### Step 1: Validate Your Manifest
Before launching long runs, validate that your manifest schema, model parameters, and regimes are well-formed:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  validate --config my_manifest.json --format json
```
If valid, it outputs the normalized manifest and full plan summary, exiting with code `0`.

### Step 2: Run the Simulation
Execute the batch and produce a report:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  run --config my_manifest.json --output artifacts/batch_report.json \
  --trace sampled --trace-sample 5 --format json
```

Both output formats write progress to stderr: completed/assigned tournaments,
elapsed time and throughput. Stdout contains the completion summary. To capture
JSON stdout without the engine banner, add Godot's `--no-header` before `--`;
redirect stdout and stderr separately. `--quiet` suppresses application output
too. On resume, counts include reused records; elapsed time and throughput cover
the current invocation, including checkpoint reads.

For an immutable roster baseline, use a separate report path and retain both
the manifest and report. A later roster export is a new benchmark; never
overwrite the pre-change artifact merely because its catalog version changed.

After interruption, repeat the exact run command with `--resume`. Completed
records are reused; an unfinished tournament restarts from its seed. Fresh runs
refuse existing checkpoints, including with `--overwrite`. Choose a new
`--checkpoint DIR` for a new run; retain the old evidence. The final schema-4
report streams from checkpoints without retaining the entire batch in memory.
See the [checkpoint contract](../../docs/Simulation_And_Evolutionary_Bot_Strategy.md#422-checkpointed-execution-and-resume)
for identity checks, storage and commands that still materialize full output.

#### Parallel Sharding:
To parallelize across multiple CPU cores or worker machines, specify `--shard INDEX/COUNT`:
```bash
# Worker 1
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  run --config my_manifest.json --shard 0/4 --output artifacts/shard_0.json

# Worker 2
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  run --config my_manifest.json --shard 1/4 --output artifacts/shard_1.json
```
> [!IMPORTANT]
> When evaluating fitness with `tools/profile-evolution evaluate-fitness`, you must provide the **complete, non-overlapping set of shards** generated from that single manifest.

### Step 3: Inspect Aggregate Results
Print summarized win rates, VPIP, and fitness scores from a report:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  inspect --report artifacts/batch_report.json --format text
```

### Step 4: Verify Determinism with Replay
Verify the recorded outcome digest and executable provenance for a specific tournament:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  replay --report artifacts/batch_report.json --tournament-index 0 --format json
```
The command exits with code `0` only when both outcome and provenance match.
Request bounded recipient-safe traces with `--trace sampled --trace-sample 100`.
Add `--output artifacts/replay.json` to store the recomputed tournament,
comparison, trace policy and traces. Default error-only tracing is empty for a
successful replay. Increasing trace detail does not affect the outcome digest.
See the authoritative [stream and replay contract](../../docs/Simulation_And_Evolutionary_Bot_Strategy.md#44-stdout-stderr-and---output).

---

## 4. Integration with Profile Evolution

Simulation reports generated here serve as input evidence for the external profile evolution workflow:
- `tools/profile-evolution evaluate-fitness`: Ingests generation manifests and complete simulation report shards.
- `tools/profile-evolution confirm-candidate`: Ingests mirrored and mixed-table simulation reports to verify candidate eligibility against legacy profiles.

Use [experiment preparation and comparison](preparing-bot-experiments.md) to
generate common candidate evaluation and independent confirmation manifests
from validated configuration, compare cross-generation candidates from one
compatible report cohort, and prepare commands for consolidated review.
