# How-To Guide: Running and Testing Pokahdot

This guide provides step-by-step commands for running the game in GUI or CLI mode, executing tests with GUT and Python unittest, running simulations, and using code quality linters.

---

For validated manifest preparation, common-cohort comparison and pending human
review, see [Preparing and comparing bot experiments](preparing-bot-experiments.md).

## 1. Prerequisites

- **Godot 4.7.2**: Download from [godotengine.org](https://godotengine.org) or ensure the `godot` binary is in your `PATH` (on macOS, `/Applications/Godot.app/Contents/MacOS/Godot`).
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

Press Enter for the displayed defaults, or type `configure` to edit them.
Blank configuration fields retain their displayed value. After validation
fails, only fields with errors are prompted again; other edits remain intact.
Use `--configure` to open the configuration fields directly.

Options after Godot's `--` separator are validated before setup: `--players`
(2–9), `--stack`, `--small-blind`, `--big-blind` (each 1–1,000,000), `--seed`
(a signed 64-bit integer), and `--use-legacy-models`. The small blind cannot
exceed the big blind. Unknown, duplicate, missing, malformed and out-of-range
options exit with status 1 before a hand starts. `--help` prints usage without
reading stdin. With no options, immediate Enter startup remains available.

```bash
godot --headless --path . --script res://scripts/cli/cli_app.gd -- \
  --players 3 --stack 100 --small-blind 5 --big-blind 10 --seed 4242
```

Seed 0 chooses a time seed. Startup prints the **effective seed** from the same
RNG streams used for profile selection and the match, followed by reproduction
options. Copy those options to repeat the game using the same source/roster
and command sequence. A saved stdin transcript includes the initial Enter:

```bash
printf '\nstate\nhistory\nraise 20\nquit\n' > localtmp/cli-transcript.txt
godot --headless --no-header --path . --script res://scripts/cli/cli_app.gd -- \
  --players 3 --stack 100 --seed 4242 < localtmp/cli-transcript.txt \
  > localtmp/cli-transcript.log
```

The app prints a full state when a hand starts or completes. Intermediate
updates show new public actions, board, pot, stacks, your cards and legal
actions. `state` prints the full recipient-safe snapshot; `history` prints
the current hand's complete public action history. Both commands preserve
the current turn or completed-hand phase. Reproduction is tied to the same
source/roster; the seed alone does not promise compatibility across versions.

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
- `state` (full recipient-safe state) and `history` (current hand public actions)
- `help` (list available commands)
- `quit` or `exit` (conclude and exit the tournament)

Between hands, press Enter or type `continue` to deal the next hand. Poker
actions and unknown commands leave the completed hand unchanged. Blank input
during a human turn leaves that turn unchanged. Completion, quit and EOF exit
with status 0; startup/tournament errors exit with status 1.

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

### Run CLI Process Contracts

```bash
make GODOT=godot cli-process-test
```

These tests capture actual process exit codes and output, including help,
invalid startup options, retained edits and deterministic stdin transcripts,
as well as separate simulation stdout/stderr, progress and bounded replay traces.
They run as part of `make check`.

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

The four gate entry points share one runner. Coverage lives in
[`gui_invariant_matrix_suites.gd`](../../tests/support/gui_invariant_matrix_suites.gd);
phone-specific checks remain in
[`gui_phone_matrix_contract.gd`](../../tests/support/gui_phone_matrix_contract.gd).
Preserve historical case IDs and version intentional coverage changes through
the [visual evidence contract](../../docs/GUI_VISUAL_TESTING.md).

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

`make check` includes the step-80 GUI layout characterization. Use
`make gui-layout-characterization` to run it alone, or `make gui-layout-sweep`
for denser step-20 diagnostics. Read the
[characterization guidance](../../docs/GUI_VISUAL_TESTING.md#policy-and-fit-characterization)
before reviewing or explicitly changing the failure registry.

The app-level `GuiViewportAdapter` owns Window normalization and usable origins;
startup/table/popups consume its immutable geometry. Run the additional exported
viewport gate with a fresh output directory:

```sh
make GODOT=/Applications/Godot.app/Contents/MacOS/Godot web-geometry-test \
  WEB_GEOMETRY_OUTPUT=localtmp/geometry-review-01
```

It uses the same pinned Playwright setup as the input gate. If browsers were
installed under `localtmp/playwright-browsers`, set
`PLAYWRIGHT_BROWSERS_PATH="$PWD/localtmp/playwright-browsers"`. Finite inset
presets belong only to the exported fixture; production observers provide no
live input/geometry mutators. Real native measurements use
`tests/performance/gui_geometry_fixture.tscn -- --app-adapter --output ...`.

Shared GUI assertions and exported observers use `get_layout_snapshot()`.
When adding a replacement composition, inject its fixture driver into
`GuiSceneHarness`; keep reference node setup and exact legacy density checks
in the reference driver. Browser layout reports use semantic label roles and
one viewport-coordinate space (report suite v2). Keep observer helpers in the
isolated test export support list and out of the production export.


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

### Profile GUI refresh cost

Import the project with the matching engine before profiling, then use a new
output directory for each run:

```bash
godot --headless --path . --import
python3 tools/profile_gui_refresh.py --mode native --godot /full/path/to/godot \
  --output localtmp/gui-profile-native
python tools/profile_gui_refresh.py --mode web --godot /full/path/to/godot \
  --output localtmp/gui-profile-web
```

Native mode requires a real display and the Compatibility renderer. Web mode
uses the Playwright environment and export templates described above. Run the
two modes sequentially without other heavy checks. Defaults collect 120 active
samples for turns, all-in runouts and resize transitions at phone, tablet and
desktop sizes, with seeded matches, real avatars, long names and maximum chip
values. `--samples`, `--profiles` and `--scenarios` select smaller investigations.

The test-only observer suppresses pacing delays and drives production action
handlers. `results.json` retains raw measurements, nearest-rank percentiles,
source fingerprints and renderer/browser identity. Refresh/layout elapsed
times, render CPU monitors and frame waiting intervals have separate scopes;
the 16.7 ms threshold flags investigation and is not a correctness gate.
Node-ID census runs separately and counts newly observed Nodes, including
layout rebuilds; it does not count every allocation. Godot allocator counters
are unavailable in release Web builds, so browser renderer-pool RSS is sampled
externally and labeled separately. Profiler arrays contribute to measured
memory, and these finite runs cannot establish leak freedom. The observer is
excluded from production exports.

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

Both simulation formats send progress to stderr: completed/total, elapsed time
and tournaments/second. Stdout contains the completion summary. Use
`--no-header` before `--` when consuming stdout as JSON:

```bash
godot --headless --no-header --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  run --config path/to/manifest.json --output artifacts/report.json --format json \
  > localtmp/simulation-result.json 2> localtmp/simulation-progress.log

godot --headless --no-header --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  replay --report artifacts/report.json --tournament-index 0 \
  --trace sampled --trace-sample 100 --output artifacts/replay.json
```

Replay's optional artifact records its trace policy and bounded recipient-safe
traces. Default error-only tracing produces no traces for a successful replay.
Requesting sampled traces does not alter outcome/provenance comparison. Resume
progress counts reused records too; elapsed time and throughput cover the
current invocation, including checkpoint reads.

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

LAN builds also reject raw engine/script errors in the check log, even when
the command exits successfully. A negative test that deliberately triggers
`push_error` must capture and assert that diagnostic in a child process, as
the native-popup guard test does. Preserve checks for unexpected diagnostics;
do not disable engine error reporting or relax the LAN log scanner.

---

## 6. Building the Web Release

For working-tree testing on the Mac, iPad or Android over Wi-Fi, use the
[dedicated local Wi-Fi how-to](local-wifi-web-testing.md).
First-time setup uses `web-lan-network`, `web-lan-tls WEB_LAN_ADDRESS=<Wi-Fi-IP>`,
`web-lan-build`, and `web-lan-serve`. Subsequent game changes need only
`web-lan-rebuild` while the existing server runs. It runs the normal production startup
scene, permits identified uncommitted changes, and uses local HTTPS with
explicitly trusted test-device certificates. Reopen the root URL after
`web-lan-rebuild` and compare the browser tab's build ID with `web-lan-status`.
The server runs in the foreground; use another terminal for these commands.
`web-lan-stop` performs authenticated shutdown. `make web-lan-test` runs the
focused build/server regressions, also included in `make check`. The exported
Web input checks above remain separate from physical Wi-Fi evidence. Device
acceptance remains tracked in [LanTestTasks.md](../../docs/arkiv/LanTestTasks.md).

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

## Minimum-raise regression checks

The core tracks full betting increments per street. Focused tests cover repeated
raises, short all-ins and raise rights, nominal short-blind calls, street/hand
resets, generated action sequences, and GUI/CLI limits and rejection recovery.
Run `make check gui-current-invariant-gate` for regression. Historical
implementation and acceptance evidence lives in the
[archived minimum-raise backlog](../../docs/arkiv/MinimumRaiseTasks.md).
Local rendered evidence and deterministic CLI transcripts are recorded in that
backlog separately from automated and physical-device acceptance.

## Documentation checks

Run `make docs-check` to validate local Markdown targets and heading anchors in
`README.md`, current `docs/`, and `devdocs/`. Documents under `docs/arkiv/`
are historical legacy records and are excluded; their internal links may be
invalid. Links from current documents to archive targets are still checked.
Missing ignored `localtmp/` evidence is reported separately and never treated
as a replacement for retained screenshots. The same check runs with `make check`.

Development pins: Godot and Web templates 4.7.2; CI Python 3.12; GUT 9.7.1;
`requirements-dev.txt` pins gdtoolkit 4.5.0 and `requirements-web-test.txt` pins
Playwright 1.55.0. Keep engine/templates aligned for reproducible exports.
