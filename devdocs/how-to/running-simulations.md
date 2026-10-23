# How-To Guide: Running Simulations

Pokahdot includes a headless, non-interactive simulation harness in `scripts/simulation/`. It is designed to evaluate bot profiles, test parameter variations, and measure statistical fitness across thousands of tournaments without rendering or GUI overhead.

---

## 1. Simulation Architecture Overview

The simulation runner operates in batch:
1. **Manifest ([`SimulationManifest`](file:///Users/rofferdal/git/pokahdot/scripts/simulation/simulation_manifest.gd))**: A versioned JSON file (schema 2) specifying profiles, matchups, structural regimes (stacks, blinds, player count), and evaluation plans.
2. **Planner ([`SimulationBatchPlanner`](file:///Users/rofferdal/git/pokahdot/scripts/simulation/simulation_batch_planner.gd))**: Expands the manifest into a deterministic, zero-based sequence of `SimulationTournamentInput` records with cyclic seat rotations.
3. **Runner ([`SimulationBatchRunner`](file:///Users/rofferdal/git/pokahdot/scripts/simulation/simulation_batch_runner.gd))**: Instantiates `TournamentMatch` with all-bot construction contracts (`TournamentConstructionContract.simulation()`), stepping matches to completion.
4. **Metrics ([`SimulationTournamentMetrics`](file:///Users/rofferdal/git/pokahdot/scripts/simulation/simulation_tournament_metrics.gd))**: Calculates VPIP (voluntarily put chips in pot), PFR (preflop raise), win rates, and chip fitness.
5. **Report ([`SimulationReport`](file:///Users/rofferdal/git/pokahdot/scripts/simulation/simulation_report.gd))**: Schema 3 JSON artifact storing complete outcomes, aggregates, recipient-safe traces, deterministic roster provenance derived from immutable profile snapshots, and ordered `selected_profile_ids` per tournament.

---

## 2. Using the Simulation CLI

The simulation entry point is [`scripts/simulation/simulation_cli_app.gd`](file:///Users/rofferdal/git/pokahdot/scripts/simulation/simulation_cli_app.gd). Pass arguments after `--`:

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

### CLI Options Summary

- `--config PATH`: Path to the input `SimulationManifest` JSON file (for `validate`, `run`).
- `--output PATH`: Destination path for the report or replay artifact (writes atomically).
- `--report PATH`: Path to a completed `SimulationReport` JSON file (for `inspect`, `replay`).
- `--format json|text`: Output formatting (defaults to `text` for inspection, `json` for machine interfaces).
- `--overwrite`: Permitted only when intentionally replacing an existing output file. (By default, existing outputs are protected).
- `--shard INDEX/COUNT`: Deterministic parallelization slice (e.g. `0/4`, `1/4`).
- `--dry-run`: Validates plan and prints shard metadata without playing tournaments.
- `--trace none|errors|sampled`: Decision trace recording mode (`none` by default).
- `--trace-sample COUNT`: Number of decisions to deterministically sample when `--trace sampled` is enabled.
- `--tournament-index INDEX`: Specific tournament index to reproduce during `replay` (defaults to `0`).

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
Verify that a specific tournament reproduces byte-for-byte and matches the recorded outcome digest:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  replay --report artifacts/batch_report.json --tournament-index 0 --format json
```
If the recomputed outcome digest matches the report's source digest, the command exits with code `0`.

---

## 4. Integration with Profile Evolution

Simulation reports generated here serve as input evidence for the external profile evolution workflow:
- `tools/profile-evolution evaluate-fitness`: Ingests generation manifests and complete simulation report shards.
- `tools/profile-evolution confirm-candidate`: Ingests mirrored and mixed-table simulation reports to verify candidate eligibility against legacy profiles.
