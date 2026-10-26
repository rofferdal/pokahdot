# Astra Suggested Improvement Tasks

Status: In progress; sections 1–4 are complete.
Reviewed: 2026-10-26, baseline `c6166b5`.

Themes and tasks are ordered by importance. **Defect** means an observed code
or documentation problem; **Decision** requires investigation or an explicit
contract; **Improvement** addresses maintainability or usability. Each task
includes its completion condition. Follow the product specification, including
its intentional fixed-BB minimum raise and Pot shortcut rules.

## Review scope and evidence

The repository-wide inventory contained 905 non-ignored files, including
43 Markdown documents. Review covered core, CLI, GUI, simulation, Python
evolution/promotion tooling, resources, scenes, tests, examples, current and
archived documentation, and build/export configuration. Binary assets and UID/
import metadata were inventoried; bundled GUT was inspected for dependency
integration, version/license, and file/process boundaries, not certified by an
independent upstream audit. Ignored files were excluded as review inputs.

Baseline `make GODOT=/Applications/Godot.app/Contents/MacOS/Godot check` passed:
546 GUT tests, 18,062 assertions, 72 Python tests, lint and formatting. An
unrestricted rerun completed without the initial sandbox file-access errors.
Targeted probes nevertheless reproduced the all-in, blind-overflow, river-draw,
keypad-cancel, and phone-number issues below. Existing confirmation fixtures
also demonstrated promotion eligibility with seven tournaments. These are
coverage gaps, not failures in the existing suite.

No application behavior was changed. Browser/device acceptance was not run.
Existing phone acceptance remains owned by
[OptimizingPhoneGuiTasks.md](OptimizingPhoneGuiTasks.md); do not duplicate its
checkboxes or treat deferred landscape support as accepted.

## 1. Poker correctness and bot decisions — highest priority

- [x] **RULE-01 — Close the all-in raise-rights bypass. [Defect]**
  In [betting_round.gd](../scripts/core/betting_round.gd), `ALL_IN` bypasses
  `can_raise`. With stacks 100/100/15, bet 10, call, shove 15, the first player
  can illegally shove 100 despite closed raising. Done: reject that increase
  without mutation, retain legal all-in calls/short raises, and align advertised
  GUI, CLI, and bot actions with validation.

- [x] **RULE-02 — Bound numeric inputs and check arithmetic. [Defect]**
  [Blind progression](../scripts/core/blind_level_progression.gd) overflows:
  starting BB `2000000000000000000` becomes negative after ten hands.
  Audit minimum-raise addition, pot targets, seed arithmetic, and CLI integer
  conversion too. Done: document supported bounds and a blind-growth limit
  policy; boundary inputs never produce negative values or silent truncation.
  No input numbers on start page should exceed 1000000.

- [x] **RULE-03 — Remove impossible river draw value. [Defect]**
  [hand_potential_estimate.gd](../scripts/core/agents/hand_potential_estimate.gd)
  still scores future draws on the river: A♠ K♠ on 2♠ 7♠ 9♦ 4♥ J♣ reports nine
  flush outs and draw quality 85. Done: missed river draws contribute no future
  value; flush/straight and decision regressions pass; affected profiles are
  reevaluated before old rankings support new promotions.

- [x] **RULE-04 — Correct strategy context and position. [Defect]**
  [strategy_decision_model.gd](../scripts/core/agents/strategy_decision_model.gd)
  treats the button as ordinal zero postflop, includes folded opponents, passes
  hero stack as effective stack, and minimum wager as BB. Done: define these
  inputs precisely, use actual street order and public values, and verify
  heads-up/multiway/folded-seat cases using real views before recalibration.

- [x] **RULE-05 — Reconcile invalid-bot fallback and retain diagnostics. [Defect]**
  [hand_controller.gd](../scripts/core/hand_controller.gd) uses check/call-first
  fallback while [the specification](ProjectDescription.md) requires fold-first;
  it drops the rejection reason and does not verify fallback success.
  Done: resolve the policy explicitly, validate the applied fallback, and emit
  safe requested/applied-action and rejection details without false progress.

## 2. Trustworthy simulation and promotion evidence

- [x] **SIM-01 — Rank finishes by elimination history. [Defect]**
  [simulation_tournament_metrics.gd](../scripts/simulation/simulation_tournament_metrics.gd)
  sorts final stacks, then seat number. Every eliminated stack is zero, so
  loser ranks, top-third results, and fitness depend on seat order. Done: track
  elimination order, define simultaneous-elimination ties, test deliberately
  non-seat-order busts, and version/recompute affected evidence.

- [x] **SIM-02 — Enforce an explicit promotion evidence policy. [Decision]**
  [confirmation.py](../tools/profile_evolution/confirmation.py) accepts fixtures
  with mirrored samples 2+2 and mixed samples 3; caller-selected minimums can
  be one. Guidance claims 300 tournaments and 100 per seat. Done: distinguish
  exploratory results from promotion eligibility, enforce approved sample
  minimums and performance/uncertainty rules, and reject weak or insufficient
  evidence. Structural validity alone must not imply demonstrated improvement.

- [x] **SIM-03 — Honor estimator and sample settings consistently. [Defect]**
  [evaluation plans](../scripts/simulation/simulation_evaluation_plan.gd) accept
  `bootstrap_95`, Godot aggregates calculate normal intervals, and
  [Python fitness](../tools/profile_evolution/fitness.py) rejects bootstrap.
  [Batch results](../scripts/simulation/simulation_batch_result.gd) also use a
  default minimum of 30 instead of plan minimums. Done: implement or reject
  estimators consistently and test non-default thresholds across both runtimes.

- [x] **SIM-04 — Bind reports to executable provenance. [Defect]**
  [simulation_cli_app.gd](../scripts/simulation/simulation_cli_app.gd) never
  supplies the report's code revision; fitness permits empty/mixed revisions.
  Done: record commit, dirty-source fingerprint, engine and algorithm versions;
  reject incompatible shard combinations and explain replay mismatches.
  Link each published profile's ID/hash to its confirmation and review checksums.
  Preserve immutable old reports rather than rewriting their provenance.

- [x] **SIM-05 — Resolve seed aliases in independence checks. [Defect]**
  [rng_stream_factory.gd](../scripts/core/rng_stream_factory.gd) reduces seeds
  modulo 2147483647: seeds 1 and 2147483648 generate identical named streams.
  Disjoint numeric ranges therefore do not guarantee independent evidence.
  Done: constrain the supported seed domain or version stronger derivation,
  detect effective overlap, and retain replay support for old algorithms.

- [x] **SIM-06 — Validate the statistical unit and uncertainty. [Decision]**
  [Aggregates](../scripts/simulation/simulation_aggregate_calculator.gd) report
  zero uncertainty for some zero/one-sample or boundary-rate cases; fitness
  treats repeated profile seats as observations. Done: define independent
  tournament/seed units, handle within-table correlation and missing evidence,
  and report uncertainty for candidate differences. Separate the fitness
  penalty from a confidence interval; test sparse and repeated-profile cases.

- [x] **SIM-07 — Preserve failure evidence and sample traces fairly. [Defect]**
  [simulation_batch_runner.gd](../scripts/simulation/simulation_batch_runner.gd)
  samples replacement against fixed buffer size, biasing retained traces toward
  recent events; failures discard collected traces and some plan identity.
  Done: use the total observed-item count for reservoir sampling and retain
  safe partial diagnostics plus plan/regime/rotation identity on failure.

- [x] **SIM-08 — Evaluate the complete proposed roster. [Decision]**
  [Confirmation diversity](../tools/profile_evolution/confirmation.py) measures
  gene distance against declared benchmarks, not observed behavior or every
  newly promoted peer. Done: distinguish genetic from behavioral diversity;
  review the proposed roster together using parameter distances and measured
  VPIP/PFR/action splits. Retain explicit human promotion approval.

## 3. Regression prevention and release confidence

- [x] **QA-01 — Add generated rule invariants and independent oracles. [Improvement]**
  Extend [core tests](../tests/unit/test_betting_round.gd) with seeded legal and
  illegal action sequences across 2–9 seats, chip conservation after every
  mutation, rejection immutability, raise rights, and privacy checks. Add
  evaluator permutation/suit invariance and independent known-result cases.
  Done: failures emit a replayable seed and action sequence; RULE-01–04 cannot
  regress while the ordinary suite stays green.
  Verified: seeded preflop/postflop runs and rotated short-all-in sequences,
  all 24 suit mappings, independent seven-card oracle vectors, and real-view
  strategy contexts. Full `make check` passes: 580 GUT tests, 94,884 assertions,
  85 Python tests, lint and formatting (2026-10-26).

- [x] **QA-02 — Validate changes before merge and gate current layouts. [Improvement]**
  The only [workflow](../.github/workflows/deploy-web.yml) runs on pushes to
  `main`; [release-candidate-gate](../Makefile) runs the historical M3 matrix,
  not the dedicated phone/iPad/desktop gates. Done: add non-deploying PR checks
  and the supported current regression matrices, with failures visible before
  merge. Preserve the existing automatic deployment policy.
  Verified: non-deploying PR workflow and shared current-layout gate; 580 GUT
  tests, 94,890 assertions, 85 Python tests and all four matrices pass locally.
  GitHub execution awaits a PR; requiring the check remains branch protection
  configuration. Push-to-main deployment is unchanged (2026-10-26).

- [x] **QA-03 — Test visible content and actual exported input paths. [Defect]**
  [GUI assertions](../tests/support/gui_invariant_assertions.gd) skip ellipsized
  labels and omit overlay text-fit checks. The
  [harness](../tests/support/gui_scene_harness.gd) opens a phone showdown overlay
  that obscures cards in canonical captures. Done: separate bare-table and
  overlay fixtures, fail deliberate required-content clipping, and exercise
  exported Web pointer/touch/keypad/focus paths. Version matrix changes.
  Verified: M3 v2 retains 348 cases; phone v2 has 406 cases with separate
  table/summary fixtures. Required ellipsis, wrapped text and popup clipping
  regressions pass, with demonstrated iPad/phone clipping fixed. Full check:
  588 GUT tests, 95,084 assertions and 85 Python tests; all four layout gates
  pass. Four Chromium cases pass on an isolated release export, including
  real pointer/keyboard and touch/keypad tournament wagers. Affected native
  captures were reviewed; physical-device acceptance remains separate
  (2026-10-26).

- [x] **QA-04 — Share cross-language artifact conformance fixtures. [Improvement]**
  [Godot report validation](../scripts/simulation/simulation_report.gd) and
  [Python validation](../tools/profile_evolution/fitness.py) duplicate contracts
  with different checks. Done: shared valid/invalid fixtures cover types,
  parameters, terminal stacks, seed limits, duplicate IDs, derived metrics and
  estimators through inspect, fitness, selection, and confirmation.
  Verified: 55 shared cases (9 valid, 46 invalid) exercise direct Godot
  validation/CLI inspection and Python fitness, selection and confirmation.
  Validation checks semantic outcomes and preserves partial failure diagnostics.
  JSON seed bounds and full-precision writes prevent cross-runtime seed drift;
  exact whole numeric spellings agree without changing source-byte checksums.
  Full check passes: 591 GUT tests, 95,281 assertions, 89 Python tests, lint,
  formatting and all four layout gates (2026-10-26).

## 4. Documentation accuracy and ownership

- [x] **DOC-01 — Repair current indexes and backlog status. [Defect]**
  [docs/README.md](README.md) links a missing active desktop file, while the
  [archived file](arkiv/OptimizingDesktopGuiTasks.md) still says active.
  `AGENTS.md`/`.cursorrules` direct work to missing `docs/TASKS.md`.
  Done: establish one current task index, reconcile archive/acceptance status,
  and check local links automatically. Preserve historical evidence and identify
  unavailable local screenshots without inventing replacements.
  Verified 2026-10-26: `docs/README.md` owns the active task index; archived
  LAN/desktop status and relocated links are reconciled. `make docs-check`
  checks 41 Markdown files with zero broken links/anchors and reports three
  unavailable ignored historical screenshots separately. `git diff --check` passes.

- [x] **DOC-02 — Correct API references and executable examples. [Defect]**
  [Core reference](../devdocs/reference/core-domain.md) describes string card
  IDs/suits, `ROYAL_FLUSH`, and registry `create_parameters`, which do not match
  the code. [Architecture](ARCHITECTURE.md) names nonexistent files and an
  obsolete observation contract. Done: reconcile API/type/path examples against
  source, smoke-test runnable snippets, and label pseudocode explicitly.
  Verified 2026-10-26: card/evaluator/registry smoke script and tutorial
  composition run under Godot 4.7.2; the extension guide example passes its
  GUT test (3 assertions). API signatures and directory maps match source;
  hypothetical integration fragments are labeled. Documentation links and
  `git diff --check` pass.

- [x] **DOC-03 — Consolidate operational contracts and mark historical claims. [Defect]**
  Reconcile [README](../README.md), [architecture](ARCHITECTURE.md),
  [simulation specification](Simulation_And_Evolutionary_Bot_Strategy.md), and
  [developer guides](../devdocs/README.md): estimator support, promotion
  minimums, mirrored opponents, progress streams, replay traces, version pins,
  and current report schema disagree. Done: one authoritative contract per
  subject with shorter linked guides; historical schema-2 measurements remain
  dated history. Clarify that checksums establish integrity, not reviewer identity.
  Verified 2026-10-26: the simulation specification owns operational contracts;
  guides link to its versions/statistics/confirmation/stream rules. Historical
  measurements retain their checksums and are explicitly historical. A current
  smoke batch validates, runs, inspects, and replays successfully; replay has
  matching provenance/outcomes and empty traces as documented. Full check:
  591 GUT tests, 95,281 assertions, 89 evolution and 34 LAN tests pass;
  documentation checks and `git diff --check` pass.

- [x] **DOC-04 — Reconcile GUI assets and acceptance language. [Defect]**
  The specification requires 32×32 avatars, but all sixteen
  [avatar PNGs](../assets/avatars/) are 64×64. Visual guidance and architecture
  mix historical matrix acceptance, optional device checks, and active phone
  acceptance. Done: document actual source/display dimensions, supported
  profiles, and distinct automated/physical acceptance status; remove stale
  prototype commentary without rewriting historical decisions.
  Verified 2026-10-26: all 16 PNG headers report 64×64; source constants use
  112×112 opponent / 128×128 human base regions and phone tokens omit avatars.
  The visual-testing contract separates current automated coverage, historical
  iPad acceptance, unrecorded desktop sign-off, active phone acceptance, and
  deferred phone landscape. Stale prototype/asset comments are corrected.
  Final `make check`: 591 GUT tests, 95,281 assertions, 89 evolution tests,
  34 LAN tests, 4 documentation-gate tests, lint and formatting pass.
  All 41 Markdown files pass local link/anchor checks; three unavailable
  historical local screenshot links are reported, not replaced. API/tutorial
  and simulation smoke examples pass. `git diff --check` passes.

## 5. GUI clarity and interaction

- [ ] **GUI-01 — Show who won on phones. [Defect]**
  [poker_table_controller.gd](../scripts/gui/poker_table_controller.gd) hides
  status bands in phone mode; compact tokens lack a winner state, the summary
  omits pot awards, and final results use `Player N` instead of assigned names.
  Done: named fold/showdown winners and split/side-pot awards are understandable
  on the table or accessible summary, with recipient privacy preserved.

- [ ] **GUI-02 — Keep supported numeric values readable. [Defect]**
  Phone action-width allocation in the same controller leaves a million-chip
  stack just 1 px beside `R999999` at 360×640. Done: align with RULE-02 bounds
  and reflow supported values; test maximum stacks, pots, blinds and wagers
  across supported counts, without truncation or sub-20-px text.

- [ ] **GUI-03 — Make keypad Cancel truly transactional. [Defect]**
  [wager_keypad.gd](../scripts/gui/wager_keypad.gd) clears invalid existing text
  before creating its draft; opening and cancelling changes `invalid` to empty.
  Done: Cancel restores exact valid, invalid, blank and whitespace input;
  only Done commits, for both startup fields and wagers.

- [ ] **GUI-04 — Define modal focus and hand-pacing behavior. [Decision]**
  Phone overlays are ordinary panels and do not suspend advancement; summaries
  can disappear when the next hand starts. Done: decide reading/pause policy,
  enforce one active overlay and appropriate input blocking, restore focus,
  and test Escape/back plus actual touch events against underlying actions.
  Keep quit reachable.

- [ ] **GUI-05 — Resolve usable-area and device support with evidence. [Decision]**
  [Web geometry](../scripts/gui/gui_web_viewport_geometry.gd) divides backing
  dimensions by scale; safe-area, browser chrome and keyboard behavior need
  exported-device evidence. Done: complete the existing phone acceptance tasks
  at one identified deployed SHA; measure CSS size/DPR/insets and a second
  browser/device, then fix demonstrated gaps. Keep landscape deferred until
  its support contract is decided.

## 6. Code readability, economy, and runtime cost

- [ ] **CODE-01 — Split the table controller by responsibility. [Improvement]**
  [poker_table_controller.gd](../scripts/gui/poker_table_controller.gd) has
  2,849 lines and an approximately 577-line layout method. Incrementally extract
  seat views, action controls, overlays, and profile layout plans; unify
  classification/style policy. Done: typed component boundaries replace
  repeated traversal and geometry exceptions, with before/after tests and
  unchanged privacy, pacing and viewport behavior.

- [ ] **CODE-02 — Bound diagnostic history and remove repeated copies. [Improvement]**
  [bot_agent.gd](../scripts/core/agents/bot_agent.gd) accumulates decision history
  in product games; simulation repeatedly retrieves copied histories/profile
  maps. Done: opt-in/drainable simulation diagnostics and one snapshot per
  operation; long-run memory stays bounded without losing metrics or changing
  RNG consumption. Retain defensive copies at ownership boundaries.

- [ ] **CODE-03 — Unify hand stepping and honor budgets. [Improvement]**
  [hand_controller.gd](../scripts/core/hand_controller.gd) duplicates advancement
  paths, including a loop that always returns on its first iteration;
  [tournament_match.gd](../scripts/core/tournament_match.gd) drops the supplied
  transition budget when starting another hand. Done: one authoritative small
  step operation and consistent budgets, preserving seeded outcomes and GUI pacing.

- [ ] **CODE-04 — Make large simulations resumable and memory-bounded. [Improvement]**
  [Manifest planning](../scripts/simulation/simulation_manifest.gd) materializes
  the full plan before shard filtering; the CLI retains outcomes until its final
  write. Done: iterate assigned global indexes and checkpoint by manifest,
  provenance and index; interrupted/resumed runs match uninterrupted digests.
  Measure peak memory and throughput on a representative large batch.

- [ ] **CODE-05 — Consolidate repeated infrastructure selectively. [Improvement]**
  Three Python atomic writers and several GUI matrix runners duplicate control
  flow. Done: shared no-clobber publication with serializer-specific boundaries,
  and declarative matrix suites with one runner; preserve race/cleanup/error
  semantics and historical fixture identities. Remove unused
  [prototype files](../my_test_node.gd) only after checking references.

- [ ] **CODE-06 — Profile GUI refresh before retaining widgets. [Decision]**
  Each table refresh rebuilds seats/cards and reapplies layout/styles. Done:
  measure Web/native frame time and allocations during turns, runouts and
  resize; reuse nodes only where measured benefit justifies complexity, with
  privacy, focus and long-text regressions. Avoid blanket caching of views.

## 7. CLI and experiment workflow usability

- [ ] **CLI-01 — Handle commands by phase and return real failure statuses. [Defect]**
  [cli_command_loop.gd](../scripts/cli/cli_command_loop.gd) lets unknown/ordinary
  action commands advance between hands; errors become EOF and the app exits
  successfully. Done: explicit continue/blank semantics, phase-specific errors
  without advancement, and distinct completion/quit/EOF/error results with
  nonzero failure exits.

- [ ] **CLI-02 — Make setup correction and game reproduction easy. [Improvement]**
  [Startup arguments](../scripts/cli/cli_startup_arguments.gd) expose only the
  legacy flag; cross-field setup failures restart all fields. Done: validated
  help/config/seed options, effective-seed reporting, retained valid edits,
  and reproducible transcripts. Keep immediate default startup; add compact
  updates and an explicit full-state/history command if repeated output obscures play.

- [ ] **CLI-03 — Make simulation output and replay contracts reliable. [Defect]**
  [simulation_cli_app.gd](../scripts/simulation/simulation_cli_app.gd) sends text
  progress to stdout despite the documented stderr contract; replay does not
  collect the promised traces. Done: separate progress/results, test captured
  stdout/stderr for both formats, and implement or explicitly remove unsupported
  replay claims. Show completed/total, elapsed time and throughput for long runs.

- [ ] **CLI-04 — Automate experiment preparation and comparison. [Improvement]**
  [ImprovingBotScript.md](arkiv/ImprovingBotScript.md) requires manual manifest and
  cross-generation comparison work. Done: validated experiment configuration
  generates candidate/confirmation manifests with independent seeds, compares
  compatible cohorts, and prepares a consolidated review. Dry-run explains
  commands, artifacts and incompatibilities; publication still requires the
  existing explicit review decision.

## Execution notes

Fix RULE-01–05 and SIM-01–06 before treating newly generated fitness as reliable
promotion evidence. Determine which existing evaluations need replacement;
do not silently invalidate, overwrite, or remove published profiles. Introduce
the regression checks alongside each fix, then refactor in small verified steps.
Exploratory features such as [bot tilt](PossibleBotTiltConcept.md) should follow
correctness and trustworthy measurement, with their own explicit scope decision.
