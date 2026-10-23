# How-To Guide: Running Simulations

Pokahdot includes a headless, non-interactive simulation harness in `scripts/simulation/`. It is designed to evaluate bot profiles, test parameter variations, and measure statistical fitness across thousands of tournaments without rendering or GUI overhead.

---

## 1. Simulation Architecture Overview

The simulation runner operates in batch:
1. **Manifest (`SimulationManifest`)**: A versioned JSON file specifying profiles, matchups, structural regimes (stacks, blinds, player count), and evaluation plans.
2. **Planner (`SimulationBatchPlanner`)**: Expands the manifest into a deterministic, zero-based sequence of `SimulationTournamentInput` records with cyclic seat rotations.
3. **Runner (`SimulationBatchRunner`)**: Instantiates `TournamentMatch` with all-bot construction contracts (`TournamentConstructionContract.simulation()`), stepping matches to completion.
4. **Metrics (`SimulationTournamentMetrics`)**: Calculates VPIP (voluntarily put chips in pot), PFR (preflop raise), win rates, and chip fitness.
5. **Report (`SimulationReport`)**: Writes full outcomes, aggregates, and execution digests to an output JSON file.

---

## 2. Using the Simulation CLI

The simulation entry point is `scripts/simulation/simulation_cli_app.gd`. Pass arguments after `--`:

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- <command> [options]
```

### Available Commands

| Command | Purpose | Example |
| :--- | :--- | :--- |
| `help` | Show command usage | `... -- help` |
| `validate` | Check manifest syntax and plan inputs without playing | `... -- validate --config manifest.json` |
| `run` | Execute tournament batch and write report | `... -- run --config manifest.json --out report.json` |
| `inspect` | Summarize metrics from a saved report | `... -- inspect --report report.json` |
| `replay` | Re-run a previous report to verify deterministic reproduction | `... -- replay --report report.json` |

---

## 3. Step-by-Step: Running a Batch

### Step 1: Validate Your Manifest
Before running a large batch, validate that your manifest schema, model parameters, and regimes are valid:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- validate --config my_manifest.json
```

### Step 2: Run the Simulation
Execute the batch and produce a report:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- run --config my_manifest.json --out my_report.json
```

#### Optional Flags:
- `--shard <i>/<n>`: Splits the tournament plan into `n` deterministic slices and executes slice `i` (0-indexed). Example: `--shard 0/4`. Useful for parallelizing across CPU cores.
- `--trace <none|errors|sample>`: Controls debug decision tracing:
  - `none` (default): Minimal memory, fastest execution.
  - `errors`: Traces only unexpected/illegal actions.
  - `sample`: Records deterministically sampled decision trees for inspection.
- `--dry-run`: Prints planned matches without running them.

### Step 3: Inspect Aggregate Results
Print summarized win rates, VPIP, and fitness scores from the report:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- inspect --report my_report.json
```

### Step 4: Verify Determinism with Replay
Verify that every action and outcome reproduces identically:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- replay --report my_report.json
```
If the digest matches, exit code is `0`.
