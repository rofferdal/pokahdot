# Astra Suggested Improvement Tasks

Status: In progress. Sections 1–4, 6 and 7, plus GUI-02–04, are complete. GUI-01 implementation is updated; the archived phone review preserves its recorded acceptance limitations.
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
Existing phone acceptance evidence remains in the archived
[OptimizingPhoneGuiTasks.md](arkiv/OptimizingPhoneGuiTasks.md); do not duplicate its
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
  CI follow-up 2026-10-27: the Pages release gate hit six missing-directory
  errors because a clean checkout has no ignored `localtmp/`. The shared
  `web-lan-test` target now creates it before discovery. An isolated full source
  archive reproduced all six errors before the change and passed all 34 LAN
  tests afterward. GitHub deployment verification awaits the next workflow run;
  this fix does not change the deployment trigger or bypass release checks.


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

- [x] **GUI-01 — Show who won on phones. [Defect; reopened]**
  [poker_table_controller.gd](../scripts/gui/poker_table_controller.gd) hides
  status bands in phone mode; compact tokens lack a winner state, the summary
  omits pot awards, and final results use `Player N` instead of assigned names.
  Done: named fold/showdown winners and split/side-pot awards are understandable
  on the table or accessible summary, with recipient privacy preserved.
  Verified 2026-10-26: More → Hand summary reports named fold wins and exact
  main/split/side-pot shares from recipient-safe settlement records; final
  winner copy uses GUI-assigned names. Full check passes: 593 GUT tests,
  95,288 assertions, 89 evolution and 34 LAN tests, documentation, lint and
  formatting. Focused summary/privacy regressions pass.
  Reopened 2026-10-27: the user reports that the phone does not show who wins
  at showdown. The earlier tests verify summary formatting/accessibility, not
  that the result is obvious during actual play. Source review finds generic
  `Hand complete` table feedback and no winner state in compact phone badges;
  named awards are behind More → Hand summary. Whether that summary worked
  on the reported device has not been established. Record the tested build,
  browser/device and outcome before claiming a device-specific root cause.
  Revised completion: named winner(s) must be apparent in the default phone
  completed-hand presentation, without discovering a hidden menu; main/split/
  side-pot recipients and amounts remain clear on the table or an obviously
  presented summary. Add a failing real-flow regression through settlement
  and the hand pause for 2-, 4-, 6- and 7-player portrait tables, including hero
  and opponent wins, splits and side pots. Preserve privacy, revealed-card
  legibility, modal pacing, the working iPad layout and the stop-on-cycle rule.
  Close only after the physical phone verification below passes.
  Implementation updated 2026-10-27: the default phone footer now names every
  awarded recipient, retains the revealed cards and the normal hand pause,
  and offers Pots for direct access to exact awards. More returns on the next
  hand. Seven new regressions cover real settlement and the seven-recipient
  boundary at 360 × 640. Full check: 616 GUT tests, 98,158 assertions, 89
  evolution and 34 LAN tests; all four layout gates and five exported Chromium
  cases pass. Single-winner Web and seven-winner native captures were reviewed.
  Initial real-flow coverage permitted byte-identical preexisting board-rank
  clipping measured before settlement. GUI-05-D has since fixed the recorded
  rank/name defects and removed those exemptions: pre/post-settlement layouts
  now require all supported portrait content checks to pass. No fix cycle was
  observed; existing clear layouts remain regression controls.
  - [x] Implement and automatically verify default visible phone winner feedback.
  Physical acceptance is still owned by the unchecked named-winner task in
  [OptimizingPhoneGuiTasks.md](arkiv/OptimizingPhoneGuiTasks.md); the parent GUI-01
  checkbox remains open. Continued engineering work follows GUI-05-A onward in
  order while physical acceptance stays pending; no device pass is inferred.

- [x] **GUI-02 — Keep supported numeric values readable. [Defect]**
  Phone action-width allocation in the same controller leaves a million-chip
  stack just 1 px beside `R999999` at 360×640. Done: align with RULE-02 bounds
  and reflow supported values; test maximum stacks, pots, blinds and wagers
  across supported counts, without truncation or sub-20-px text.
  Verified 2026-10-26: exact values through 7,000,000 on phones and 9,000,000
  on larger layouts reflow without lowering the 20 px floor. Nine numeric
  regressions cover all phone counts, larger-layout counts, isolated triggers,
  fallback fonts/DPR, resize restoration and real Min/Pot/free wagers.
  Full check passes: 602 GUT tests, 96,906 assertions, 89 evolution and 34 LAN
  tests; all four layout gates pass. Four native numeric captures were reviewed.
  Physical acceptance remains separate.

- [x] **GUI-03 — Make keypad Cancel truly transactional. [Defect]**
  [wager_keypad.gd](../scripts/gui/wager_keypad.gd) clears invalid existing text
  before creating its draft; opening and cancelling changes `invalid` to empty.
  Done: Cancel restores exact valid, invalid, blank and whitespace input;
  only Done commits, for both startup fields and wagers.
  Verified 2026-10-26: opening sanitizes only the draft; original field text
  remains unchanged through edits and Cancel. Regression first failed and now
  passes across startup, desktop wager and phone wager modes, including padded
  and whitespace-only text. Full check passes: 603 GUT tests, 97,014 assertions,
  89 evolution and 34 LAN tests. Four isolated exported Chromium input cases
  pass, including actual keyboard entry and touch Cancel for invalid/blank/
  whitespace fields on startup and the table.

- [x] **GUI-04 — Define modal focus and hand-pacing behavior. [Decision]**
  Phone overlays are ordinary panels and do not suspend advancement; summaries
  can disappear when the next hand starts. Done: decide reading/pause policy,
  enforce one active overlay and appropriate input blocking, restore focus,
  and test Escape/back plus actual touch events against underlying actions.
  Keep quit reachable.
  Verified 2026-10-26: exclusive table overlays hold advancement until closed,
  block underlying input, contain/restore focus and expose Quit. Escape and
  synthetic engine-back dismissal preserve keypad drafts; actual browser/device
  Back remains part of GUI-05. Reopening a keypad preserves its popup lifecycle
  across resize. Full check passes: 609 GUT tests, 97,066 assertions, 89 evolution
  and 34 LAN tests; all four layout gates pass. Exported Chromium passes all
  four cases with both working modal touches and blocked underlying touches.
  Native summary/short-keypad captures were reviewed; no input/layout cycle
  remains in these verified cases.

- [x] **GUI-05 — Resolve usable-area and device support with evidence. [Decision]**
  [Web geometry](../scripts/gui/gui_web_viewport_geometry.gd) divides backing
  dimensions by scale; safe-area, browser chrome and keyboard behavior need
  exported-device evidence. Done: complete the existing phone acceptance tasks
  against one identified exported build; measure CSS size/DPR/insets and a second
  browser/device, then fix demonstrated gaps. Keep landscape deferred until
  its support contract is decided.
  Testing plan confirmed by the user, 2026-10-26: use the local Wi-Fi Web
  workflow on desktop browsers at multiple screen sizes, iPad, and phone.
  Record the same pinned LAN build ID, source SHA and dirty-source fingerprint
  on every device. This replaces the hosted-deployment requirement for this
  review; physical results and acceptance remain pending.


### GUI-05 browser capture review

Reviewed 2026-10-27 (Europe/Oslo). Evidence is the four user attachments in
submission order, showing the same six-player preflop human turn: pot 65,
blinds 5/10, Human 1000 with 4-spades/8-diamonds, Wei raised to 20,
Youssef raised to 30, and Haruto folded. Attachment pixels are screenshot
rasters, not measured CSS viewports. Original rasters for captures 1–3 were
2738 × 1448, 2754 × 1554 and 2494 × 1272; the chat display resized these.
No local attachment copies or checksums have been established. Build identity,
browser/device versions, zoom, CSS/canvas geometry, DPR and insets were not
supplied with these captures. Do not assume the previously prepared LAN build
`17924d63` was used without confirmation.

| Evidence | Observed result | Assessment |
| --- | --- | --- |
| Capture 1 | Wei's seat overlaps the community-card region; its `Raise to 20` occupies the board area. Chidi's `Big blind 10` crosses Yael's seat. Human/Youssef names and several stack-label suffixes are clipped. | Fail: obstructive overlap and unreadable required identity text. |
| Capture 2 | Yael's `Small blind 5` crosses Chidi's name/seat; Youssef's `Raise to 30` crosses Haruto's seat. Human and chip-label text are clipped. The left/right pairs reverse their visible clockwise order relative to captures 1, 3 and 4. | Fail: status/seat overlap, text clipping and inconsistent visual position mapping. |
| Capture 3 | Names, complete stack labels, private hero cards, hidden opponent cards, center fields and action controls appear separated and readable. | Provisional visual pass for this captured state only. |
| Capture 4 | Required information appears readable and regions are separated at the shown state. | Provisional visual pass for this captured state only. |
| User's iPad review | User reports that the iPad screen looks OK; association with a numbered attachment was not specified. | Positive user visual evidence for the reviewed screen; preserve it. Other phases/input paths and exact environment remain unverified. |

The differing visual clockwise order in capture 2 is an observed presentation
problem, not evidence that core seat IDs or poker state changed. Captures 1,
3 and 4 place Yael below Chidi on the left and Youssef below Haruto on the
right; capture 2 reverses both pairs. All four show complete numeric stack
amounts at ordinary values; the observed stack-text clipping is in the label
suffix, so do not describe these images as proof of missing amount digits.

Additional phone result, 2026-10-27: the user reports that showdown does not
show who wins. This is a failed winner-clarity check and reopens GUI-01 above;
it is separate from the four preflop captures. No showdown screenshot, exact
build/device/browser or test of More → Hand summary was supplied with this
report. The user's positive iPad screen review remains unchanged. GUI-05-F
must include the [physical winner check](arkiv/OptimizingPhoneGuiTasks.md) before
acceptance; earlier synthetic summary tests do not close this defect.

**GUI-05 remains incomplete.** These captures establish real browser layout
failures despite earlier automated passes. They do not demonstrate phone
portrait composition, safe-area/browser-chrome behavior, overlays, touch,
keyboard/keypad, showdown awards, or tournament completion. Keep GUI-01–04's
recorded automated evidence scoped to its tested cases; it is not blanket
browser acceptance. Do not reopen the archived LAN workflow or historical iPad
acceptance record.

Execute these follow-ups in order. Change only the responsible presentation
owner and compare the same state on all four surfaces and the working iPad
after each fix. Apply the stop-on-cycle rule below; do not trade the original
failure for a regression in a previously clear layout.

- [x] **GUI-05-A — Bind and reproduce the browser evidence. [Evidence]**
  Record the pinned LAN build ID, source SHA/fingerprint, device/OS/browser,
  browser zoom, CSS viewport, canvas CSS/backing sizes, DPR, selected layout
  profile and usable rectangle for each capture; record insets/browser chrome
  where relevant. Identify the working iPad environment without assuming which
  attachment represents it. Retain originals under ignored `localtmp/` with
  recorded filenames/checksums when available. Done: known values and remaining
  unknowns are explicit, and an exported same-state reproduction is documented;
  screenshot raster sizes are never substituted for logical viewport sizes.
  Verified 2026-10-27: `gui_browser_capture_fixture.gd` reproduces the captured
  public state, roles, names, actions and event history without private cards.
  `tools/run_web_layout_tests.py` mounts production main, records real CSS/canvas/
  DPR/engine geometry, all invariant failures and full clockwise order, and
  captures settled transitions in both directions. The 39-case Chromium
  140.0.7339.16 report is `localtmp/gui05-a-browser-20261027/results.json`.
  These are new measured environments, not historical screenshot metadata.
  Historical build/zoom/CSS/DPR/insets and the working iPad's identity remain
  explicitly unknown. The last served LAN candidate is known separately:
  `c163b935b90b456b8b3dd175aca6cc56`, source `7d8bc4ba664e44e082967e1069c2f938a154f52f`,
  dirty fingerprint `aa9f8edec416adaa9e89164644a7ad9c646337544c7955866216da1260787bb7`;
  this does not establish which build the user captured.
  The reproduction export uses source `f1f4ef87bfb5740bd411a9f91952832b5ffb0f71`,
  copied-project hash `a6dba31920ae3dac0b4742664778de6701bb4a128ad6ebbaf5181628b6017eef`
  and pack hash `133e4bb89037fba508f79baface6f579c17dc4408449d582b2bde5cce203c89a`.
  Measured 1369 × 724 reproduces clipping/containment failures; 1377 × 777 also
  reproduces the reported pair reversal `[0, 2, 1, 3, 5, 4]` and both status/seat
  collisions. Clear automated controls are 1855 × 918, 1920 × 1080 and
  1024 × 768; they do not identify the user's physical iPad. Original capture 1's
  board overlap has not been exactly attributed. Full check passes: 618 GUT
  tests, 98,197 assertions, 89 evolution and 34 LAN tests, lint/format/docs;
  the five existing exported input cases pass. Report mode deliberately retains
  failures and is not an acceptance gate. GUI-05-B owns strict regressions.


- [x] **GUI-05-B — Add failing browser regressions before changing layout. [QA]**
  Reproduce the six-player ordinary-value state with the same names, markers,
  folds and actions. Assert complete seat-plus-status footprints do not cross
  another seat or the board; required names/stack labels fit; visual clockwise
  seat order remains consistent through resize/profile transitions. Exercise
  the actual exported font/layout path and settled resize, retaining captures
  3/4 and the working iPad as positive controls. Done: the observed defects fail
  before remediation without weakening existing assertions or inventing missing
  device measurements; boundary values remain covered too.
  Verified 2026-10-27: strict `all`, `geometry`, `content` and `order` modes now
  preserve full engine failures, check complete seat/status footprints and all
  six seats' clockwise order, and require visible, correctly bound Name/Stack/
  role labels. Existing compact S/B aliases retain their SB/BB semantics.
  Thirteen pure checker tests pass; full check passes 618 GUT tests and 98,197
  assertions, 89 evolution and 34 LAN tests. The strict 39-case baseline exits
  1 as intended: 23 cases fail overall, 13 geometry, 12 content and 15 order
  (families overlap). All clear desktop/tablet controls pass. Before evidence:
  `localtmp/gui05-b-browser-final-red-20261027/results.json`; runner checksum
  `02e9b2780092355098174973b12073851e46a8448d2dbb708a0c68045cc67706`, checker
  `4653afca87ff27f12d3cfe4b931bb49264af48d9a22ded7acb6d0b4d771456f8`.
  These are failing regressions ready for C/D/E remediation, not accepted UI.


- [x] **GUI-05-C — Remove seat/status/board collisions. [Defect]**
  Fix the demonstrated collisions in captures 1 and 2 using a single layout
  owner for each complete seat/status footprint and the center region. Done:
  `Big blind 10`, `Small blind 5`, `Raise to 20` and `Raise to 30` remain attached
  to their seats and clear of other seats, community cards and controls across
  the recorded failing surfaces and intervening resize widths. Preserve the
  clear layouts and iPad result; verify before adding geometry exceptions.
  Implemented a single complete-footprint plan for constrained six-seat
  desktops. Selection measures whether the complete plan fits; density
  transitions rebuild seat content, and this composition bypasses the old
  successive collision resolvers. Phone, tablet and clear desktop paths remain
  covered by their existing matrices. Verification: all 39 strict exported
  geometry cases pass (`localtmp/gui05-c-final/results.json`); full checks pass
  with 623 GUT tests / 98,647 assertions and all four current GUI matrices
  (`localtmp/gui05-c-check-final.log`). Four content cases and eight order cases
  remain explicitly tracked by D/E. No fix cycle occurred; physical acceptance
  remains F.

- [x] **GUI-05-D — Preserve complete seat identity and stack copy. [Defect]**
  Fix clipped `Human`, `Youssef` and stack-label text in captures 1/2 at normal
  970–1000-chip values. Done: names, numeric stacks, chosen chip-label format,
  position badges and card cells fit without masking one another, ellipsis or
  sub-20-px text. If the redundant `chips` suffix is omitted, use a consistent,
  intentional presentation rather than clipped fragments; preserve maximum
  supported-value regressions and the working iPad layout.
  Additional preexisting evidence from GUI-01 real-hand fixtures: board rank
  `10` needs 25 px but receives 24.4 px in the compact community-card face;
  the exported browser capture also shows only `1`. A valid eight-character
  test name `Santiago` needs 84 px but receives 78 px beside combined role/
  all-in state. These failures exist before the winner change. Include them
  in this task's glyph/cell measurements and failing regressions; do not fix
  them through repeated viewport-specific offsets or hide them from acceptance.
  Verified 2026-10-27: small-desktop and portrait-tablet seats consistently
  display full numeric stacks, resolved by core seat ID even after source-array
  reordering. Fixed card faces measure rank width at the current font; portrait
  board cards use 48 × 54 px with 5 px gaps, retaining at least 18 px suit cells.
  A finite three-row phone content plan preserves names, stacks, complete
  role/state components, exact actions and hidden/revealed cards, including
  active heads-up and positive stacks after settlement. All prior winner-flow
  clipping exemptions are removed. Same-widget resize cycles are covered.
  Final exported report `localtmp/gui05-d-final-browser/results.json` passes
  all 39 content and geometry cases; eight order cases remain E. Full checks
  pass 629 GUT tests / 99,464 assertions, plus docs/evolution/LAN/checker suites;
  all four current layout matrices pass (`localtmp/gui05-d-verified-layouts.log`).
  Post-scope targeted checks pass 31 tests / 1,985 assertions. The native
  seven-player 360 × 640 showdown capture in `localtmp/gui05-d-phone-review/`
  was visually reviewed. New complete-component overlap checks apply to
  supported portrait; all preexisting landscape checks remain. Landscape's
  preexisting name/stack overlap and insufficient 38 px card width stay deferred.
  No fix cycle occurred; physical acceptance remains F.

- [x] **GUI-05-E — Keep visual clockwise order stable across profiles. [Defect]**
  Correct the observed pair reversals in capture 2. Done: the same recipient
  remains at the bottom and opponents retain their clockwise core-seat order
  across all recorded layouts and resize transitions; Yael/Chidi and
  Haruto/Youssef do not swap apparent poker position. Verify using stable seat
  IDs and role markers, without changing the match or assigning new names.
  Verified 2026-10-27: small-desktop placement retains the occupied authored
  cells, sorts their centers clockwise and assigns them by relative core seat
  ID instead of dictionary iteration. Pure/rendered regressions cover 2–9
  players, nonzero human seats, reversed source arrays, profile transitions
  and exact name/stack/role ownership. All 39 exported cases now pass geometry,
  content and complete clockwise order (`localtmp/gui05-e-final/results.json`).
  Full checks and all four current GUI matrices pass: 632 GUT tests / 100,922
  assertions, plus docs/evolution/LAN/checker suites and lint/format
  (`localtmp/gui05-e-check-final.log`). No new geometry resolver or fix cycle.

- [x] **GUI-05-F — Verify corrections and finish the device review. [Acceptance]**
  Review corrected captures at the identified failing sizes plus the clear
  sizes/iPad, then run full checks, current layout gates and exported input
  tests against one identified candidate. Complete the still-open
  [phone acceptance tasks](arkiv/OptimizingPhoneGuiTasks.md) for supported portrait
  counts, showdown cards, overlays and the independent browser/device check;
  include browser bars, insets, keypad/focus and real device/browser Back.
  Done: results and remaining limitations are recorded for the same pinned
  build and the user accepts the reviewed experience. The current iPad report
  is a pass for its reviewed screen only. Phone landscape remains deferred.
  - [x] Verify corrected source automatically and prepare one pinned LAN candidate.
    Build `b5766701eb8a40f4a70ae283836e2d24` is ready and served by the existing
    HTTPS server, source `7ba6598d044faa9336ac6c7b98e75b3887eaa96e`, dirty-source
    fingerprint `123af41c3b928ae1d8b618732ff361266f844ff5d3388f22d67ea331af0c9744`.
    Full check: 632 tests / 100,922 assertions; all four current layout matrices
    and 39 strict exported content/geometry/order cases pass. Five exported input
    cases pass (`localtmp/gui05-f-input/results.json`). Production LAN startup
    passes at desktop 1377 × 777 / DPR 1 and phone 390 × 844 / DPR 3 without
    browser errors (`localtmp/gui05-f-production-smoke/results.json`). The root
    redirects to this build and its index returns HTTP 200. Corrected measured
    desktop captures and the native seven-player phone showdown were reviewed.

## 6. Code readability, economy, and runtime cost

- [x] **CODE-01 — Split the table controller by responsibility. [Improvement]**
  [poker_table_controller.gd](../scripts/gui/poker_table_controller.gd) has
  2,849 lines and an approximately 577-line layout method. Incrementally extract
  seat views, action controls, overlays, and profile layout plans; unify
  classification/style policy. Done: typed component boundaries replace
  repeated traversal and geometry exceptions, with before/after tests and
  unchanged privacy, pacing and viewport behavior.
  Verified 2026-10-27: six typed components own seat construction/handles,
  action-control rows, overlay views, layout policy and seat geometry. The
  controller is 2,545 lines (previously 3,504), its layout coordinator 68
  (previously 659), and repeated child traversal is replaced by widget-owned
  handles. Baseline and final checks pass; final evidence is 635 GUT tests /
  100,960 assertions, all Python/docs/lint/format checks and all four current
  layout matrices (`localtmp/code01-check.log`,
  `localtmp/code01-current-layouts.log`). All 39 strict exported layout cases
  and five exported pointer/touch/keypad/focus/showdown input cases pass
  (`localtmp/code01-web-layout/results.json`,
  `localtmp/code01-web-input/results.json`). Independent code review found no
  remaining behavior, privacy or ownership issues.

- [x] **CODE-02 — Bound diagnostic history and remove repeated copies. [Improvement]**
  [bot_agent.gd](../scripts/core/agents/bot_agent.gd) accumulates decision history
  in product games; simulation repeatedly retrieves copied histories/profile
  maps. Done: opt-in/drainable simulation diagnostics and one snapshot per
  operation; long-run memory stays bounded without losing metrics or changing
  RNG consumption. Retain defensive copies at ownership boundaries.
  Verified 2026-10-27: product agents skip diagnostic allocation and trace
  reads; simulation opts in and drains once per bounded advancement. Events,
  legal alternatives and identity maps are read once per operation; identity
  consumers copy scalar IDs instead of complete profile Resources. Rejected
  requests and their applied fallbacks consume one decision snapshot without
  false executed-bluff counts. Tests cover 10,000 product decisions, bounded
  drains, isolated ownership, RNG parity and fallback correlation. All 144
  seeded runs retain exact baseline outcomes, metrics and sampled traces.
  Full check passes 640 GUT tests / 102,247 assertions and all Python/docs/
  lint/format checks (`localtmp/code02-check-final.log`); code review passes.

- [x] **CODE-03 — Unify hand stepping and honor budgets. [Improvement]**
  [hand_controller.gd](../scripts/core/hand_controller.gd) duplicates advancement
  paths, including a loop that always returns on its first iteration;
  [tournament_match.gd](../scripts/core/tournament_match.gd) drops the supplied
  transition budget when starting another hand. Done: one authoritative small
  step operation and consistent budgets, preserving seeded outcomes and GUI pacing.
  Verified 2026-10-27: both hand drivers share one step operation; paced GUI
  calls retain explicit human submission, while bulk calls consume a pending
  mailbox. Next-hand setup forwards the requested budget, retaining the
  existing one-step clamp for nonpositive values. The new next-hand regression
  fails before the fix and passes afterward; mailbox preservation is covered.
  All 144 seeded runs retain exact baseline outcomes, metrics and sampled
  traces. Full check passes 642 GUT tests / 102,274 assertions, all Python/
  docs/lint/format checks and all four current layout matrices
  (`localtmp/code03-check.log`); independent code review passes.

- [x] **CODE-04 — Make large simulations resumable and memory-bounded. [Improvement]**
  [Manifest planning](../scripts/simulation/simulation_manifest.gd) materializes
  the full plan before shard filtering; the CLI retains outcomes until its final
  write. Done: iterate assigned global indexes and checkpoint by manifest,
  provenance and index; interrupted/resumed runs match uninterrupted digests.
  Measure peak memory and throughput on a representative large batch.
  Verified 2026-10-27: assigned-index cursor/direct lookup, bounded online
  aggregate moments, schema-1 per-index checkpoints and streamed schema-4
  reports are implemented. Resume binds manifest/provenance/shard/trace identity,
  validates records and preserves completed failures. A killed CLI resumes
  without rewriting committed records; 120 tournament digests, metrics, traces
  and file checksum match uninterrupted execution. Sparse billion-index plans,
  descriptor ownership, malformed records and trace framing are covered.
  Full check passes 659 GUT tests / 102,565 assertions and Python/docs/lint/
  format checks (`localtmp/code04-check-final.log`); independent review passes.
  All 144 seeded probes and 11,000 benchmark tournament rows/traces match the
  pre-streaming implementation. The checkpoint contract and memory limits are
  documented in the simulation specification and current guides.

  Fresh-process headless CLI measurements on Godot 4.7.2 / macOS 26.7.1 use
  the two-player, 20-chip, 5/10 fixture, seed 9100, with report I/O included.
  Final runs had no concurrent checks. Checkpoint I/O and record validation
  trade throughput for bounded memory and resumability; these are local
  measurements, not promotion evidence or forecasts for deeper-stack games.

  | Tournaments | Old peak RSS | New peak RSS | Old tournaments/s | New tournaments/s |
  | --- | --- | --- | --- | --- |
  | 1,000 | 198.6 MiB | 144.5 MiB | 408.2 | 307.7 |
  | 10,000 | 707.6 MiB | 144.5 MiB | 476.6 | 336.6 |

  Evidence: `localtmp/code04-benchmark-results.json`,
  `localtmp/code04-before-{1000,10000}.log` and
  `localtmp/code04-final-{1000,10000}.log`.

- [x] **CODE-05 — Consolidate repeated infrastructure selectively. [Improvement]**
  Three Python atomic writers and several GUI matrix runners duplicate control
  flow. Done: shared no-clobber publication with serializer-specific boundaries,
  and declarative matrix suites with one runner; preserve race/cleanup/error
  semantics and historical fixture identities. Remove unused
  prototype files (`my_test_node.gd` and its scene/UID) only after checking references.
  Verified 2026-10-27: one byte-publication primitive retains serializer and
  caller error boundaries, hard-link race protection, temporary cleanup,
  existing fsync policies and profile-sidecar rollback. Python tests pass
  before/after (89 → 97), including concurrent publication and injected failures.
  Declarative suite definitions and one runner preserve the original ordered
  348 M3 / 406 phone / 288 iPad / 232 desktop cases, manual entry points and
  phone-specific privacy/content/resize checks. A deliberate private-card
  exposure still fails the phone contract. Capture provenance includes the
  shared authorities. Filename/class/UID reference checks confirmed the three
  prototype files unused; they and stale command/export references are removed.
  Full check passes 664 GUT tests / 102,598 assertions, all Python/docs/lint/
  format checks and all four current matrices (`localtmp/code05-check.log`,
  `localtmp/code05-current-layouts.log`). Current guidance is reconciled.

- [x] **CODE-06 — Profile GUI refresh before retaining widgets. [Decision]**
  Each table refresh rebuilds seats/cards and reapplies layout/styles. Done:
  measure Web/native frame time and allocations during turns, runouts and
  resize; reuse nodes only where measured benefit justifies complexity, with
  privacy, focus and long-text regressions. Avoid blanket caching of views.
  Measured 2026-10-27: test-only instrumentation drives actual product handlers
  through seeded turns, all-in streets/settlement and profile transitions.
  Native Apple M4 Compatibility and exported Chromium 140.0.7339.16 each have
  nine workloads × 120 active samples, plus idle baselines and separate Node
  census. Real textures, eight-character names and maximum chip values are
  included. Source hash is
  `cb6dcab772d526e22e14247f48d76262740383733fd9afdf69a96d19850cf5b7`.

  | Profile | Native refresh p95 | Web refresh p95 | Native transition-layout p95 | Web transition-layout p95 |
  | --- | --- | --- | --- | --- |
  | Phone | 4.03 ms | 6.0 ms | 5.96 ms | 9.6 ms |
  | Tablet | 5.58 ms | 10.9 ms | 7.45 ms | 11.9 ms |
  | Desktop | 5.86 ms | 12.9 ms | 7.23 ms | 13.3 ms |

  Refresh columns take the larger turns/runout p95, not a pooled percentile.
  Decision: retain disposable widgets; synchronous costs and the product's
  2 s / 5 s update cadence do not demonstrate enough benefit for retention
  complexity. Whole-frame wall p95 reaches 27.3 ms native / 21.5 ms Web and
  includes waiting/deferred work; these measurements do not guarantee 60 fps.
  The identical-launch browser probe identifies SwiftShader software rendering,
  not a physical-phone measurement. Native render-CPU p95 is 0.25–0.38 ms;
  TIME_PROCESS is separately labeled as a coarse, potentially lagging monitor.
  Census observes up to 113/159 new Nodes per refresh and 85–131 on transitions,
  excluding transient IDs and other allocator events. Resize live object/node/
  resource/orphan deltas are zero; native static bytes include about 198 KB of
  retained profiler buffers. Release-Web allocator bytes are unavailable;
  renderer-pool RSS is recorded separately. No leak-freedom claim is made.
  Privacy, actual textures, every runout street and settlement, and real
  transition validation pass. Five report-integrity tests guard empty samples,
  missing workloads and privacy failures. Raw samples, percentiles, identity
  and memory scopes: `localtmp/code06-native-final/results.json`,
  `localtmp/code06-web-final/results.json` and the adjacent browser-backend probe.
  Reproduction commands are in the current running/testing guide. Final check
  passes 664 GUT tests / 102,604 assertions, 97 evolution / 34 LAN / 18 checker /
  4 documentation tests, lint/format and all four current GUI matrices
  (`localtmp/code06-check-final.log`). All 39 strict exported layout cases and
  five pointer/touch/keypad/focus/showdown input cases pass
  (`localtmp/code06-web-layout/results.json`, `localtmp/code06-web-input/results.json`).
  Concurrent phone-record archival is preserved; relocated links are repaired
  and all 42 current/archived Markdown files pass documentation checks.

## 7. CLI and experiment workflow usability

- [x] **CLI-01 — Handle commands by phase and return real failure statuses. [Defect]**
  [cli_command_loop.gd](../scripts/cli/cli_command_loop.gd) lets unknown/ordinary
  action commands advance between hands; errors become EOF and the app exits
  successfully. Done: explicit continue/blank semantics, phase-specific errors
  without advancement, and distinct completion/quit/EOF/error results with
  nonzero failure exits.
  Verified 2026-10-27: only blank/`continue` starts the next hand; poker actions,
  help and unknown commands preserve phase. Completion, quit, EOF and fatal
  error are distinct; the process maps fatal errors to exit 1. Full check passes
  667 GUT tests / 102,616 assertions and all Python/docs/lint/format checks
  (`localtmp/cli01-check.log`); targeted phase/start/advancement regressions
  and independent code review pass.

- [x] **CLI-02 — Make setup correction and game reproduction easy. [Improvement]**
  [Startup arguments](../scripts/cli/cli_startup_arguments.gd) expose only the
  legacy flag; cross-field setup failures restart all fields. Done: validated
  help/config/seed options, effective-seed reporting, retained valid edits,
  and reproducible transcripts. Keep immediate default startup; add compact
  updates and an explicit full-state/history command if repeated output obscures play.
  Verified 2026-10-27: strict help/configuration/seed switches reject invalid
  startup arguments before a hand starts. Field corrections preserve valid
  edits; the match's actual effective seed and complete reproduction options
  are printed. Compact updates retain recipient privacy and new public actions;
  `state`/`history` inspect without advancing, and history cursors reset per
  hand/match. Five captured process contracts include seeded and time-seed
  transcript replay. Full check passes 675 GUT tests / 102,677 assertions,
  all five CLI process tests, Python/docs/lint/format checks
  (`localtmp/cli02-check.log`); independent code review passes.

- [x] **CLI-03 — Make simulation output and replay contracts reliable. [Defect]**
  [simulation_cli_app.gd](../scripts/simulation/simulation_cli_app.gd) sends text
  progress to stdout despite the documented stderr contract; replay does not
  collect the promised traces. Done: separate progress/results, test captured
  stdout/stderr for both formats, and implement or explicitly remove unsupported
  replay claims. Show completed/total, elapsed time and throughput for long runs.
  Verified 2026-10-27: both formats send plan/timed progress only to stderr;
  stdout carries results and argument errors/usage stay on stderr. Replay
  honors none/error/sampled policies and records bounded safe traces without
  changing outcome/provenance checks. Captured process tests cover both streams,
  deterministic sampled replay, failures and resumed counts. A 1,000-tournament
  smoke confirms intermediate timed progress. Full check passes 675 GUT tests /
  102,679 assertions, 9 CLI process tests and all existing Python/docs/lint/format
  checks (`localtmp/cli03-check.log`); independent code review passes.

- [x] **CLI-04 — Automate experiment preparation and comparison. [Improvement]**
  [ImprovingBotScript.md](arkiv/ImprovingBotScript.md) requires manual manifest and
  cross-generation comparison work. Done: validated experiment configuration
  generates candidate/confirmation manifests with independent seeds, compares
  compatible cohorts, and prepares a consolidated review. Dry-run explains
  commands, artifacts and incompatibilities; publication still requires the
  existing explicit review decision.
  Verified 2026-10-27: strict experiment configuration snapshots lineage and
  benchmarks, generates one common heads-up evaluation cohort plus independent
  per-candidate mirrored/mixed confirmations, and checks complete cyclic seat
  counts, seed blocks and prior evidence compatibility. Dry-run reports commands,
  artifact identities and incompatibilities without writes. Comparison recomputes
  cross-generation fitness from one validated cohort, preserves original creation
  checksums/history, and emits an evaluated registry for confirmation. Generated
  recipes end at one consolidated pending review; publication gates are unchanged.
  Seventeen new tests cover cohort/provenance rejection, reconstructible lineage,
  ineligible ranks, malformed inputs, no-clobber races/cleanup and explicit review.
  All five generated manifest fixtures pass actual Godot validation with exact
  Python/Godot checksum parity (`localtmp/cli04-manifest-smoke/`). Full check
  passes 675 GUT tests / 102,677 assertions, 179 Python tests across five suites,
  lint/format and documentation checks (`localtmp/cli04-check.log`); independent
  code review passes. No ranking experiment or profile publication was run.

## Execution notes

Phone GUI stop rule (user instruction, 2026-10-26): stop the active task if a
chain of fixes reintroduces substantially the original failure. Do not continue
cycling between fixes. Leave that task unchecked, record the cycle and preserve
the last verified behavior before considering a different design.

Fix RULE-01–05 and SIM-01–06 before treating newly generated fitness as reliable
promotion evidence. Determine which existing evaluations need replacement;
do not silently invalidate, overwrite, or remove published profiles. Introduce
the regression checks alongside each fix, then refactor in small verified steps.
Exploratory features such as [bot tilt](PossibleBotTiltConcept.md) should follow
correctness and trustworthy measurement, with their own explicit scope decision.
