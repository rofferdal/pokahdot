# Pokahdot

Pokahdot er et poker-spill laget i [Godot](https://godotengine.org/) 4. Spillreglene ligger i en felles kjerne (`scripts/core/`), slik at det samme spillet kan vises både grafisk og i terminalen.

Prosjektet er under utvikling.

## Krav

- Godot **4.7** (GDScript, Compatibility-renderer)
- Godot-binæren tilgjengelig som `godot` i `PATH`, eller full sti til editoren

## Start the graphical application (GUI)

1. Open the `pokahdot` folder in the Godot editor (**Import** / **Open**).
2. Press **Play** (F6). The startup screen is prefilled with 6 participants,
   1000 chips, and 5/10 blinds. Select **Start tournament** without editing to
   use those defaults, or change any value before starting.
3. The form validates whole-number input and the tournament constraints inline.
   A match is created only after all values are valid.
   Small-phone layouts support 2–7 players; tablet, small-desktop, desktop,
   CLI, and core configuration retain 2–9 support. Touch presses open the
   in-canvas number pad, while pointer focus leaves ordinary physical-keyboard
   entry available regardless of layout size.
4. **Use legacy heuristic models** is unchecked by default. Leave it unchecked
   to select only strategic `StrategyDecisionModel` profiles. Select it to
   include legacy heuristic profiles; this choice resets when returning to the
   startup screen.

Fra terminal, med prosjektroten som arbeidsmappe:

```bash
godot --path .
```

På macOS, hvis Godot ikke ligger i `PATH`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Start headless (terminal)

Kjør CLI-inngangen uten vindu:

```bash
godot --headless --path . --script res://scripts/cli/cli_app.gd
```

På macOS uten `godot` i `PATH`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/cli/cli_app.gd
```

The terminal interface supports a complete tournament with optional startup
overrides, poker actions, `help`, `quit`, and `exit`. Game rules remain in
`scripts/core/`, not in either presentation layer.

## Blind levels and Pot wager

The selected blinds are the first level's blinds. A level that begins with five
or more active players lasts twice that starting player count in completed
hands; a level that begins with fewer than five players lasts 10 completed
hands. An increase applies to the next hand. The next big blind is 125% of the
previous big blind, rounded upward to an even integer, and the small blind is
half of it (for example, 5/10 becomes 7/14, then 9/18). The CLI and table show
the current blinds, level, completed hands, and hands remaining in the level.

When it is a legal bet or raise and the hero can cover it, the GUI's **Pot
bet** or **Pot raise** button submits the currently displayed pot amount
through the normal wager-validation path. It is disabled if that target is not
a legal wager; **All-in** and the free wager entry remain separate controls.

### Bot roster selection

Standard GUI and CLI games select strategic `StrategyDecisionModel` profiles
only. To include legacy heuristic models in an interactive CLI game, pass this
flag after Godot's `--` argument separator:

```bash
godot --headless --path . --script res://scripts/cli/cli_app.gd -- --use-legacy-models
```

When legacy models are enabled, `ceil(bot_count / 2)` bot seats receive legacy
heuristic profiles and the remaining seats receive strategic profiles. The
selection is deterministic for a fixed tournament seed; diagnostics state
whether legacy models are included and list every selected model and profile
ID. Neither option exposes opponent hole cards.

## Deterministic simulation and bot-profile workflow

The non-interactive simulation command evaluates bot-only tournaments. It is
separate from the interactive CLI and never prompts for human input. Run every
command from the repository root:

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  help
```

Simulation manifests are schema-2 JSON documents with a batch ID, seed start,
immutable profile snapshots, regimes, matchups, and named evaluation plans.
Every matchup must provide exactly the number of profiles required by its
regime. The manifest is the source of profile identity for an evaluation; it
does not read or mutate the playable product roster.

To establish a benchmark for the presently playable roster, export a baseline
manifest. The command atomically writes immutable profile snapshots; it does
not alter the roster. Defaults use the `curated_v2`-derived batch ID, seed
`71001`, 100bb 5/10 tables, and 2520 balanced cyclic tournaments. The current
18-profile catalog is covered by deterministic nine-seat matchups without
raising the product table-size limit.

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  export-roster-manifest --output artifacts/curated_roster_baseline.json \
  --batch-id curated_baseline_2026 --seed 72001 --tournament-count 2520
```

`--overwrite` is required to replace an existing export. `--regime-preset
standard` explicitly selects the current 100bb baseline; no other preset is
accepted. Validate the exported file unchanged before running it.

Validate a manifest before starting a tournament. This prints the normalized
manifest and complete deterministic plan without creating an artifact:

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  validate --config path/to/manifest.json --format json
```

Run a batch by choosing a new output path. `run` writes the complete report
atomically and prints only a compact completion summary. Progress and failures
are written to stderr. Existing outputs are protected; use `--overwrite` only
when intentionally regenerating the same artifact.

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  run --config path/to/manifest.json --output artifacts/batch_report.json \
  --trace sampled --trace-sample 5 --format json
```

For parallel execution, give every worker the same manifest and a distinct
`--shard INDEX/COUNT`, such as `0/4`, `1/4`, `2/4`, and `3/4`. Keep all shard
reports: fitness evaluation requires the complete, non-overlapping set from
one manifest. A dry run verifies the selected shard without playing:

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  run --config path/to/manifest.json --shard 2/4 --dry-run --format json
```

Reports use schema 3. They retain the exact manifest/checksum, roster
provenance derived from immutable profile snapshots, ordered selected profile
IDs for every tournament, seeds, seat maps, metrics, diagnostics, and only
recipient-safe traces. Inspecting is read-only; replay rebuilds one stored
tournament and returns failure unless its outcome digest matches.

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  inspect --report artifacts/batch_report.json --format text

godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  replay --report artifacts/batch_report.json --tournament-index 17 --format json
```

Keep manifests, every report shard, replay outputs, code revision, and the
command output together in durable storage. Never edit a completed report or
reuse a filename for a different run. The checked-in
[`examples/simulation/milestone6`](examples/simulation/milestone6) pair is a
small three-profile, three-seat smoke batch; it demonstrates validation,
cyclic rotation, inspection, and replay. It is not promotion evidence.

### External profile evolution and reviewed promotion

`tools/profile-evolution` is a separate Python workflow that writes strict,
checksummed JSON artifacts. It never writes the playable roster. Start from
bounded strategy genes, then create a deterministic generation:

```bash
tools/profile-evolution init-generation \
  --bounds examples/profile_evolution/milestone5/bounds.json \
  --population-size 20 --seed 7001 --output artifacts/generation_0.json
```

Build a simulation manifest that contains the candidate snapshots from that
generation plus the required baselines. Run every planned shard with the
simulation command above, then evaluate and select only the complete report
set:

```bash
tools/profile-evolution evaluate-fitness \
  --generation artifacts/generation_0.json \
  --report artifacts/evaluation_shard_0.json \
  --report artifacts/evaluation_shard_1.json \
  --output artifacts/fitness_0.json

tools/profile-evolution select --fitness artifacts/fitness_0.json \
  --elite-fraction 0.15 --output artifacts/selection_0.json

tools/profile-evolution crossover --selection artifacts/selection_0.json \
  --seed 7002 --target-count 20 --output artifacts/crossover_1.json

tools/profile-evolution mutate --input artifacts/crossover_1.json \
  --policy examples/profile_evolution/milestone5/mutation_policy.json \
  --seed 7003 --output artifacts/generation_1.json
```

Build and retain lineage before confirmation. A promotion candidate needs
independent mirrored and mixed-table reports against declared legacy bots and
historical champions. A batch win, a single narrow matchup, an invalid-action
fallback, or insufficient uncertainty/diversity evidence cannot promote a
profile.

```bash
tools/profile-evolution build-lineage --artifact artifacts/generation_0.json \
  --artifact artifacts/fitness_0.json --artifact artifacts/selection_0.json \
  --artifact artifacts/generation_1.json --output artifacts/lineage.json

tools/profile-evolution confirm-candidate --registry artifacts/lineage.json \
  --candidate-id candidate_id --legacy-id random_default \
  --legacy-id tight_passive_default --legacy-id loose_aggressive_default \
  --historical-champion-id champion_id \
  --mirrored-report artifacts/mirrored_report.json \
  --mixed-report artifacts/mixed_report.json --output artifacts/confirmation.json
```

An independent reviewer handles the complete proposed candidate set in one
editable plan. Each candidate receives exactly one `approve` or `reject`
decision, after which the plan is finalized into one immutable review artifact
bound to every exact eligible confirmation. Publication creates a new
versioned `.tres` file for an approved candidate and refuses to overwrite an
existing one. It still does not activate the profile: roster membership is a
separate reviewed source change that must retain the legacy personalities.

```bash
tools/profile-evolution prepare-promotion-review \
  --confirmation artifacts/confirmation.json \
  --reviewer-id reviewer_id \
  --output artifacts/promotion_review_plan.json

# In the plan, change each decision from "pending" to "approve" or "reject".
tools/profile-evolution finalize-promotion-review \
  --plan artifacts/promotion_review_plan.json \
  --confirmation artifacts/confirmation.json \
  --output artifacts/promotion_review_batch.json

tools/profile-evolution publish-profile --confirmation artifacts/confirmation.json \
  --review artifacts/promotion_review_batch.json --version v1 \
  --display-name "Candidate v1" --project-root .
```

Repeat `--confirmation` in both review commands for additional candidates.
The editable plan also has optional `display_name` and `review_note` fields.
Do not alter candidate or confirmation fields, checksummed artifacts,
overwrite published profiles, or
treat an approval as permission to change `PlayableBotRoster` automatically.

## Development checks

Install the pinned development tools in a local virtual environment:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
```

Run the GDScript linter and verify formatting without modifying files:

```bash
.venv/bin/gdlint scripts tests my_test_node.gd
.venv/bin/gdformat --check scripts tests my_test_node.gd
```

Run the Godot tests headlessly:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

For GUI layout work, start with the rendering-enabled capture smoke test:

```bash
make gui-visual-capture-smoke
```

The invariant gate, dirty-tree development capture, and clean candidate
capture have different evidence semantics. Follow
[`docs/GUI_VISUAL_TESTING.md`](docs/GUI_VISUAL_TESTING.md) and use
[`docs/templates/GUI_DEFECT.md`](docs/templates/GUI_DEFECT.md) for every GUI
defect. The complete command reference is also available in
[`devdocs/how-to/running-and-testing.md`](devdocs/how-to/running-and-testing.md).
`make web-release` creates a local export. Every successful push to `main`
automatically validates and deploys that commit to GitHub Pages; follow
[`docs/WEB_SETUP.md`](docs/WEB_SETUP.md).

## GUI action pace

The GUI waits two seconds after rendering each player action before advancing to the next automatic action. It uses the same configured pause after each flop, turn, and river reveal, then waits five seconds after any completed hand before starting the next hand. At showdown the shared seat-status band displays the winning hand; when one player wins before showdown, that band displays exactly `Winner`. Edit `resources/gui_action_timing_config.tres` in Godot to change `default_pause_seconds`, add a `pause_seconds_by_seat` entry for an individual bot seat (for example, seat `1`), or change `showdown_pause_seconds`. Set a value to `0.0` for immediate progression during development.

## Mappestruktur

```
pokahdot/
├── scenes/                 # Grafisk UI (.tscn)
├── scripts/
│   ├── core/               # Spilllogikk uten UI
│   ├── gui/                # Scripts til Control-noder
│   └── cli/                # Terminal-UI (headless)
├── resources/              # Custom Resources, f.eks. kortdata (.tres)
└── assets/                 # Sprites, fonter og lyder
```
