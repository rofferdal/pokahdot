# How-To Guide: Running and Testing Pokahdot

This guide provides step-by-step commands for running the game in GUI or CLI mode, executing tests with GUT and Python unittest, running simulations, and using code quality linters.

---

## 1. Prerequisites

- **Godot 4.7+**: Download from [godotengine.org](https://godotengine.org) or ensure the `godot` binary is in your `PATH` (on macOS, `/Applications/Godot.app/Contents/MacOS/Godot`).
- **Python 3 with dev dependencies**:
  ```bash
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r requirements-dev.txt
  ```

---

## 2. Running the Game

### Launch the Graphical UI
To launch the Godot graphical interface:
```bash
godot --path . scenes/main.tscn
```
*Alternatively, open the project in the Godot Editor and press **F5** (Play).*

### Launch the Interactive CLI
To play an interactive poker tournament in your terminal:
```bash
godot --headless --path . --script res://scripts/cli/cli_app.gd
```

By default, product games select only strategic `StrategyDecisionModel`
profiles. To include legacy heuristic profiles in the CLI roster:
```bash
godot --headless --path . --script res://scripts/cli/cli_app.gd -- --use-legacy-models
```

The GUI provides the equivalent unchecked **Use legacy heuristic models**
startup checkbox. With the option enabled, `ceil(bot_count / 2)` bot seats use
legacy profiles and the rest use strategic profiles.

#### In-Game CLI Commands:
When it is your turn, enter any of the following commands:
- `check` or `call`
- `fold`
- `bet <total>` (e.g. `bet 20` to make your street bet 20 chips)
- `raise <total>` (e.g. `raise 60` to raise the wager to 60 chips)
- `allin` (push all remaining chips)
- `help` (list available commands)
- `quit` or `exit` (conclude and exit the tournament)

---

## 3. Running Automated Tests

Pokahdot has two test suites:
1. **GUT (Grand Unified Test)**: Headless GDScript tests for poker rules, tournament match engine, and UI adapters.
2. **Python `unittest`**: Tests for the external profile evolution tool, artifact schemas, and confirmation gates.

### Run All GUT Tests (GDScript)
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

### Run Only Unit Tests
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit
```

### Run Only Integration Tests
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration
```

### Run a Specific GUT Test File
Use `-gtest=` with the resource path:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_playable_bot_roster.gd
```

### Run Python Profile Evolution Tests
```bash
python3 -B -m unittest discover -s tests/profile_evolution -t . -v
# Or via Makefile:
make profile-evolution-test
```

### Run GUI Visual Verification

These commands have deliberately different scopes and evidence status. They
require a rendering-capable display except for the invariant gate. See the
authoritative [GUI visual testing workflow](../../docs/GUI_VISUAL_TESTING.md)
for the viewport/state matrix, manifest fields, storage, and review rules, and
use the [GUI defect record](../../docs/templates/GUI_DEFECT.md) for failures.

Verify the rendering and capture pipeline with one development-only case:

```bash
make gui-visual-capture-smoke
```

Run all current regression matrices, including historical Milestone 3 and
the dedicated phone, iPad, and desktop gates, without producing screenshots:

```bash
make gui-current-invariant-gate
```

Capture the complete matrix while developing, including from a dirty tree:

```bash
make gui-visual-capture-development
```

This records dirty paths and their fingerprint and is never acceptance
evidence. It does not run the ordinary complete suite or the standalone
invariant gate first.

Run the dedicated 406-case phone v2 invariant matrix and render its
development screenshots with:

```bash
make gui-phone-invariant-gate
make gui-phone-capture-development
```

The phone matrix covers 2, 4, 6, and 7 players across canonical portrait,
landscape, and reduced-height viewports. It excludes the event-history state
because the phone composition has no event-history surface. The development
capture remains non-acceptance evidence and requires 100% visual review.

Run the dedicated iPad geometry and full-state matrix with landscape as the
primary orientation and portrait as secondary regression coverage:

```bash
make gui-ipad-invariant-gate
```

This includes canonical 1024 x 768 landscape and 768 x 1024 portrait, the
1194 x 696 reduced-height Chrome regression, and the 2388 x 1450 observed
surface at 2, 4, 6, 7, and 9 players. It does not expand the frozen Milestone 3
capture count.

Produce candidate evidence only from a clean committed tree:

```bash
make gui-visual-capture
```

The clean target runs `make check`, runs `gui-current-invariant-gate`, rechecks tree
cleanliness, and renders all 348 Milestone 3 captures. Its manifest is
acceptance-eligible only if every expected capture settles and passes its
recorded invariants. Capture commands refuse to overwrite existing evidence.
Use `make GODOT=/full/path/to/godot <target>` when Godot is not on `PATH`.

### Exercise exported Web input

Install `requirements-web-test.txt` into a development virtual environment,
then install its pinned Chromium browser with `python -m playwright install
chromium`. Matching Godot Web export templates are required. Run
`python tools/run_web_input_tests.py --godot /full/path/to/godot --output
localtmp/web-input-<run-id>` from that environment; choose a new output directory
for each run.

The runner copies the production GUI into an isolated test project, exports it,
and uses real browser pointer, touch, and keyboard events. It checks startup
and wager fields, keypad drafts, Cancel/Done, and pointer/keyboard focus after
touch. The observer only reports state and is excluded from production
exports. Export logs, browser snapshots and screenshots remain under
`localtmp/`. This local Chromium regression does not establish physical-device
or hosted-browser acceptance.

---

## 4. Running Simulations & Profile Evolution

### Headless Batch Simulation Runner
To validate manifests, run batch tournaments, inspect metrics, or replay outcomes:
```bash
# Snapshot the currently playable roster before changing a bot or roster membership.
# This writes isolated profile snapshots; it does not change the product roster.
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  export-roster-manifest --output artifacts/curated_roster_before.json

# Validate manifest
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  validate --config path/to/manifest.json --format json

# Run batch
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  run --config path/to/manifest.json --output artifacts/report.json

# Inspect results
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  inspect --report artifacts/report.json --format text

# Replay tournament
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  replay --report artifacts/report.json --tournament-index 0
```

### External Profile Evolution CLI
To run genetic evolution operations, inspect lineages, or verify candidate promotion eligibility:
```bash
# View all available evolution commands
tools/profile-evolution --help

# Example: Inspect a candidate's lineage
tools/profile-evolution inspect-lineage --registry artifacts/lineage.json --candidate-id <id>
```

---

## 5. Code Quality & Pre-Commit Verification

Before submitting pull requests, ensure all tests and linters pass.

Run `make check gui-current-invariant-gate` while developing. Pull requests
run `make release-candidate-gate` on the clean proposed merge with pinned
Godot 4.7.2. The **Checks and current layouts** status covers the full suite,
lint, formatting, and all four layout gates. It performs no deployment;
maintainers can require this status in branch protection. The release gate
also checks that verification leaves the working tree clean.
The separate **Exported Web input** PR status runs the browser regression
described above; maintainers can require both statuses before merging.

### Check Formatting (Without Modifying Files)
```bash
.venv/bin/gdformat --check scripts tests
```

### Automatically Format Files
```bash
.venv/bin/gdformat scripts tests
```

### Run GDScript Linter
```bash
.venv/bin/gdlint scripts tests
```

### Run Complete Pre-Commit Check (`Makefile`)
The project `Makefile` runs Python unit tests, imports Godot assets, checks GDScript linting and formatting, and runs all GUT tests:
```bash
make check
```

---

## 6. Building the Web Release

For working-tree testing on the Mac, iPad or Android over Wi-Fi, use the
[local LAN runbook](../../docs/OPTIONAL_WEB_SETUP.md#local-wi-fi-development-before-merging).
The workflow is `web-lan-network`, `web-lan-tls WEB_LAN_ADDRESS=<Wi-Fi-IP>`,
`web-lan-build`, and `web-lan-serve`. It runs the normal production startup
scene, permits identified uncommitted changes, and uses local HTTPS with
explicitly trusted test-device certificates. Reopen the root URL after
`web-lan-rebuild` and compare the browser tab's build ID with `web-lan-status`.
The server runs in the foreground; use another terminal for these commands.
`web-lan-stop` performs authenticated shutdown. `make web-lan-test` runs the
focused build/server regressions, also included in `make check`. The exported
Web input checks above remain separate from physical Wi-Fi evidence. Device
acceptance remains tracked in [LanTestTasks.md](../../docs/LanTestTasks.md).

To export the web release target to `build/web/index.html`:
```bash
make web-release
```
*(Requires a clean git working tree and the Godot HTML5 export template installed).*

This is a local export check. Every push to `main` automatically starts the
release workflow, which checks out the pushed SHA and runs
`make release-candidate-gate web-release` in headless CI before deploying to
GitHub Pages. For optional manual hosted checks, follow the
[Web publishing and hosted-verification runbook](../../docs/OPTIONAL_WEB_SETUP.md).
