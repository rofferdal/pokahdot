# Minimum Raise Implementation Tasks

Status: Complete and user-accepted. MR-00–MR-06 are implemented and verified.

User acceptance (2026-10-28): the user tested after implementation, reported
no errors, and explicitly confirmed that all tasks in this backlog are complete.

## Authority and scope

Implement the rules in
[`ProjectDescription.md`, section 4.5](ProjectDescription.md#45-actions-no-limit)
and the design in
[`ARCHITECTURE.md`, section 5.7](ARCHITECTURE.md#57-betting_roundgd).
This backlog owns the minimum-raise change. Follow its first unchecked task
unless the user selects another task. All tasks in this backlog are complete.

The core must calculate legal wagers and action reopening. GUI, CLI and bots
consume the recipient-safe `GameView`; they must not reconstruct betting
increments from history or implement separate poker rules. Keep target-total
wagers, typed validation errors, card privacy, and the existing No Limit Pot
shortcut contract. Do not combine this work with the
[GUI replacement backlog](RestructureGuiTasks.md).

## Baseline implementation and affected areas (before MR-01)

- `scripts/core/betting_round.gd` calculated minimum raises as
  `current_bet + big_blind` and treats increases of at least one big blind as
  full raises when deciding whether to reopen action. MR-01 replaced both calculations.
- `scripts/core/hand_controller.gd` constructs each street's `BettingRound`.
  `scripts/core/game_view.gd` publishes its minimum/maximum wager totals and
  legal actions. Verify initialization, street resets and view propagation.
- `scripts/gui/poker_table_controller.gd` and
  `scripts/gui/gui_table_action_controls.gd` use the bound view for Minimum,
  Pot and free-entry controls, including keypad configuration.
- `scripts/cli/cli_renderer.gd` prints legal wager ranges, while
  `scripts/cli/cli_command_loop.gd` submits actions and resolves Pot commands.
- `tests/unit/test_betting_round.gd` explicitly expected the old flat increment
  in `test_subsequent_minimum_raise_stays_one_big_blind_after_larger_raise`.
  `tests/unit/test_gui_table_actions.gd` also contained a live repeated-raise
  expectation of 50 after a raise from 20 to 40; the required minimum is 60.
  Audit other fixtures before changing numeric expectations: a synthetic
  initial wager does not necessarily represent an actual prior full raise.

## Acceptance examples

Unless stated otherwise, the big blind is 10, stacks cover the wager, and the
acting player has raise rights. Totals refer to the current street.

| Situation | Required result |
| --- | --- |
| Preflop current wager 10, no raise yet | First full raise minimum 20; reject 19. |
| Preflop raise from 10 to 30 | Increment 20; next full raise minimum 50; reject 49. |
| Next player raises from 30 to 60 | Increment 30; next full raise minimum 90. |
| Postflop opening bet 40 | Increment 40; first full raise minimum 80. |
| Full raise from 20 to 40 | Increment 20; next full raise minimum 60. |
| Raise from 10 to 30, then short all-in to 35 | Preserve increment 20; minimum full raise 55 for a player with raise rights. |
| Raise from 10 to 30, then short all-in to 40 | Increment 10 is below the required 20; preserve increment 20 and do not reopen prior callers' raise rights. Next full raise minimum 60 for a player with raise rights. |
| Stack total below the full-raise minimum but above the call total | Omit ordinary Raise; allow All-in only when raise rights are open. |
| All-in increase exactly equals the required full increment | Treat as a full raise and reopen eligible opponents' action. |
| New street or next hand | Discard the previous street's increment; use the current hand's big blind for initialization. |

## Tasks

Each task includes status, scope and a completion condition. Check it off only
after implementation and verification evidence exists. Add concise evidence
under the task; put session-only logs and captures under ignored
`localtmp/minimum_raise/`.

- [x] **MR-00 — Record the baseline and confirm boundary rules.** Status:
  Complete. Mode: QA / Tech Lead. Run the existing checks before changes;
  record the source revision, relevant uncommitted changes, commands and
  results. Review the core, generated tests, adapter fixtures and authoritative
  rules. Resolve any specification gaps before implementing them, especially
  preflop when the big blind posts short, a postflop opening all-in below one
  big blind, and multiple short all-ins after a player has acted. Preserve the
  documented short-all-in exception; do not silently introduce cumulative
  reopening rules. Record needed clarifications in the product specification
  and architecture before coding.
  Done: baseline results and explicit expected outcomes for these boundaries
  are recorded, with existing failures distinguished from this change.

  Baseline (2026-10-28): source `fcda2e518107c5a8b310e0b90b1dfd02b8e504c6`;
  working tree initially clean; Godot `4.7.2.stable.official.ed1daf0bf`.
  `make GODOT=/Applications/Godot.app/Contents/MacOS/Godot check` stops at
  documentation validation: 56 pre-existing missing targets (including current
  links to the moved Astra backlog), plus 3 unavailable local evidence links.
  `.venv/bin/gdlint scripts tests` and
  `.venv/bin/gdformat --check scripts tests` pass (274 scripts).
  Remaining baseline gates run separately because `make check` stops early.
  LAN socket checks require execution outside the sandbox: the initial run
  failed with `Operation not permitted` on loopback binding, before code changes.
  Logs: `localtmp/minimum_raise/baseline-{check,all,adapters,adapters-unrestricted,gut}.log`.
  Boundary rules confirmed by the user: nominal preflop blind even when
  posted short; postflop short opening 5 / BB 10 permits a full raise to 15;
  short all-ins never cumulatively reopen closed rights.

  Baseline suite: 675/675 GUT tests, 102675 assertions; Python suites pass:
  profile evolution 114, LAN 34 (outside sandbox), web layout 18, CLI/process 9.
  Product section 4.5 and architecture section 5.7 now record the confirmed
  boundaries before code changes. GUI invariant baseline log:
  `localtmp/minimum_raise/baseline-gui-gate.log` (all four gates pass).

- [x] **MR-01 — Track the full betting increment in core.** Status: Complete. Mode: Senior / QA. Add strongly typed street-local increment state
  in `BettingRound`, initialized to the current big blind. An opening full bet
  sets it to the bet amount; a full raise sets it to
  `new_total - previous_current_bet`. Compute the minimum from the current
  wager plus that increment, preserving checked arithmetic and saturation.
  Replace the obsolete flat-increment test with boundary tests for the first
  preflop raise, repeated equal and larger raises, and postflop opening bets.
  Verify calls, checks and folds do not change the increment. Keep the existing
  public wager-total API unless a documented core need requires a change.
  Done: focused tests prove the full-bet/full-raise acceptance examples,
  exact-minimum acceptance, below-minimum rejection without state mutation,
  and overflow handling; run the existing suite after the change.

  Evidence: typed private street increment, tracked full-increase classification,
  saturated addition and unchanged public wager API. Focused tests pass 19/19;
  full GUT passes 679/679 (100304 assertions); changed-file lint/format and
  `git diff --check` pass. Logs: `localtmp/minimum_raise/mr01-focused-only.log`
  and `mr01-gut.log`. Updated the old generated oracle formulas and GUI minimum
  50→60 as necessary compatibility fixes; deeper adapter coverage follows below.
  The shared increase path already applies tracked classification to All-in;
  MR-02 verifies reopening boundaries.

- [x] **MR-02 — Apply the tracked increment to all-ins and reopening.** Status:
  Complete. Mode: Senior / QA. Classify increases against the increment
  required before applying the action, including `ALL_IN`. A short increase
  changes the call total without replacing the increment or reopening closed
  raise rights. A full increase updates the increment and reopens action.
  Cover prior callers, the original bettor/raiser, unacted seats, exact all-in
  calls, and players who can afford a short all-in but no full raise. Include
  a short increase of at least one big blind but less than the tracked
  increment, so the old reopening logic cannot pass the regression.
  Done: legal-action lists, pending seats, turn order and completion agree
  with the rules; rejected actions preserve chips, increment, rights and
  history; focused and existing tests pass.

  Evidence: focused tests pass 26/26 (285 assertions); full GUT passes 686/686
  (100468 assertions). Short increases 35 and 40 after a raise to 30 retain
  increment 20, exact all-in 50 reopens, unacted short stacks retain All-in,
  closed rights retain exact all-in calls, and multiple short increases do
  not cumulatively reopen. Rejected raises/all-ins preserve complete snapshots.
  Lint/format/diff pass. Logs: `localtmp/minimum_raise/mr02-{focused,gut}.log`.

- [x] **MR-03 — Verify street lifecycle, views and bot consumers.** Status:
  Complete. Mode: Senior / QA. Exercise real `HandController` and
  `TournamentMatch` action sequences across preflop, flop, turn, river and
  the next hand, including a changed blind level. Confirm fresh street state
  and accurate `GameView.minimum_wager_total`, `maximum_wager_total`, call
  amount and legal actions for each recipient. Extend
  `tests/unit/test_betting_round_generated.gd` with an independently tracked
  expected increment and replayable seeds; retain chip-conservation,
  rejection-immutability and privacy assertions. Audit strategy sizing and
  scripted bot fixtures, changing sequences only when the old wager becomes
  illegal under the new rules.
  Done: integration and generated tests verify state propagation and reset;
  bot sizing respects published limits without new invalid-action fallbacks;
  the existing suite passes.

  Evidence: `HandController` initializes preflop from the nominal blind; tests
  cover actual short posts, nominal calls/raises, history immutability after
  rejected closed-rights actions, all street resets, recipient limits/privacy,
  and next-hand resets through the 5/10→7/14 blind change. The generated oracle
  independently predicts wager targets and increments before applying actions,
  probes below-minimum rejections and checks every recipient's view (79730
  assertions). Strategic sizing accepts live 10→30→60 views without fallback;
  audit found all bot wager sizing already consumes published view limits.
  Focused lifecycle 14/14, strategy 24/24, generated 2/2; full unrestricted GUT
  690/690 with no engine errors. Lint/format/diff pass. Logs:
  `localtmp/minimum_raise/mr03-{lifecycle,generated,bots,gut}.log`.

- [x] **MR-04 — Verify GUI raise presentation and submission.** Status:
  Complete. Mode: Senior / QA. Extend `tests/unit/test_gui_table_actions.gd`
  with live core-backed repeated-raise and short-all-in sequences. Check
  Minimum text/value, free-entry validation, keypad bounds and Minimum
  submission against the bound view on wide and phone layouts. Include
  tablet/small-desktop keypad entry where relevant. Verify ordinary Raise
  and its presets are unavailable when unaffordable or raise rights are
  closed, while valid Call and All-in remain available. Verify refreshed
  controls use the latest view after an opponent raises or a street changes.
  Test Pot targets below, at and above the minimum: retain `T = H + P`, disable
  unavailable targets and never clamp them into a different wager.
  Done: displayed/submitted totals match core limits, an obsolete flat-BB
  raise is rejected without advancing the turn, and a valid Minimum action
  succeeds. Capture representative wide/phone states and record visual
  review separately from automated checks. Fix presentation only as needed;
  keep poker validation in core.

  Evidence: 39/39 GUI tests (648 assertions), full unrestricted GUT 693/693;
  no engine errors; lint/format/diff pass. Live repeated raises verify Min 60,
  keypad 60–490, free-entry 50 typed rejection without progress, Minimum 60
  success, and next-street refresh to 10 across desktop, phone, tablet and
  small desktop. Core-backed short-all-in views verify closed/open rights and
  unaffordable full raises; existing exact Pot boundary tests remain green.
  No GUI production changes were needed. Logs:
  `localtmp/minimum_raise/mr04-{focused,gut,capture}.log`.
  Separate visual review: Compatibility-rendered live match seed 9123, flop
  20→40, at 1280×720 and 390×844, both with and without the keypad. Reviewed
  `localtmp/minimum_raise/live-{1280x720,390x844}{,-keypad}.png`: wide Min 60,
  phone keypad Min 60 / Max 490 / Pot 80; raise controls fit and remain readable.
  These are local development captures, not exported-browser or device approval.

- [x] **MR-05 — Verify CLI ranges, commands and rejection recovery.** Status:
  Complete. Mode: Senior / QA. Extend `tests/unit/test_cli_renderer.gd`,
  `tests/unit/test_cli_command_loop.gd` and
  `tests/integration/test_cli_preflop_adapter.gd` with core-backed sequences.
  Verify full-state and compact output advertise the updated total range
  after raises and short all-ins; omit Raise when unavailable. Submit an
  obsolete flat-BB amount, confirm a typed rejection and retained turn, then
  submit the exact legal minimum successfully. Check target totals when the
  human already posted a blind or called. Cover `potraise` availability using
  the same exact target as the GUI, plus All-in with open and closed rights.
  Done: deterministic transcripts demonstrate displayed limits, rejection
  recovery and successful actions matching the core; CLI adapter and process
  tests pass without duplicating raise calculations in the CLI.

  Evidence: focused CLI renderer/loop/integration tests 48/48 (649 assertions),
  full unrestricted GUT 700/700 and CLI/process 9/9; no engine errors;
  lint/format/diff pass. Full and genuine compact output show tracked ranges
  50/90, short-all-in min 60 and rights-dependent action availability. Parsed
  All-in and exact Pot targets remain core-validated. Full/compact live
  transcripts reject obsolete 50 once with typed BELOW_MINIMUM, preserve the
  human turn and successfully raise to 60, with no bot fallback or card leaks.
  Logs: `localtmp/minimum_raise/mr05-{focused,gut,process,transcript}.log`;
  reviewed transcripts: `localtmp/minimum_raise/cli-{full,compact}.txt`.

- [x] **MR-06 — Run regression checks and reconcile documentation.** Status:
  Complete. Mode: QA / Code Reviewer / Documentation Updater. Run the full
  repository checks and the current GUI invariant gate. Review state updates,
  arithmetic, type safety and core/UI separation. Inspect failures in seeded
  simulation and browser fixtures for changed legal action sequences rather
  than blindly updating expected totals. Process `README.md`, current
  `docs/` excluding `docs/arkiv/`, and `devdocs/`; remove pending-implementation
  notes only after evidence exists and align examples and test guidance.
  Done: all required gates pass with zero errors, GUI/CLI evidence is recorded,
  documentation links and formatting validate, and this backlog accurately
  records completion and any remaining limitations. Historical archives stay
  unchanged.

  Evidence (2026-10-28): final unrestricted full GUT 702/702, 111949 assertions,
  zero engine errors; all four current GUI invariant matrices pass. Python
  suites pass: profile evolution 114, LAN 34, web layout 18, CLI/process 9;
  documentation checker tests 4/4, lint and formatting pass (274 scripts),
  and `git diff --check` passes. Final review found no remaining core/UI
  separation, privacy or type-safety issues. Checked-addition overflow now
  hides an unrepresentable ordinary full Raise while preserving saturated
  reporting and short All-in; both overflow and exact-limit tests pass.
  Seeded simulation and browser-fixture GUT tests pass without fixture changes.

  Reconciled root README, current task index, product/architecture, core and
  architecture references, testing guidance and affected current browser/LAN
  links. The same documentation checker restricted to current files passes
  all 28 files with zero link/anchor/fence errors. Existing historical records
  remain unchanged. Five current links to the moved Astra backlog were repaired.

  Initial acceptance blocker (resolved by the user's archive policy): the
  repository-wide checker reported 51 pre-existing broken links inside
  `docs/arkiv/`. The user confirmed all documents there are historical legacy
  records whose invalid links are acceptable. The checker now excludes those
  documents recursively while still validating current links to archive
  targets. Six documentation regression tests pass, including archive exclusion
  and continued validation of current links. Added `docs/arkiv/README.md` to
  document the policy; existing archived records remain unchanged.
  Final verification after this policy change:
  `make GODOT=/Applications/Godot.app/Contents/MacOS/Godot check` passes in full,
  including all 702 GUT tests, the Python suites, lint, formatting, six
  documentation regression tests and validation of 28 current Markdown files
  with zero errors. The four GUI invariant gates passed in the preceding run;
  this follow-up changes only documentation and its checker/tests.
  Final gate log: `localtmp/minimum_raise/archive-policy-check.log`.
  Initial verification logs:
  `localtmp/minimum_raise/mr06-{check,docs,adapters,gut,gui-gate,overflow}.log`.
  Optional exported-browser input tests were not run: Playwright and browser
  binaries are absent. Local rendered GUI review and deterministic CLI evidence
  are recorded under MR-04 and MR-05, without claiming physical-device approval.

## Verification commands

Run from the repository root. Use the installed Godot executable in place of
`godot` if it is not on `PATH`. Consult the
[testing guide](../devdocs/how-to/running-and-testing.md) and
[GUI visual workflow](GUI_VISUAL_TESTING.md) for prerequisites and capture
commands. Task evidence above records executed checks and their results.

Historical legacy documents under `docs/arkiv/` are excluded from the
checker by the user's explicit policy. Their internal invalid links are not
minimum-raise regressions and require no repair.

```bash
make GODOT=godot check
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://tests/unit/test_betting_round.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://tests/unit/test_betting_round_generated.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://tests/unit/test_gui_table_actions.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://tests/integration/test_cli_preflop_adapter.gd
make GODOT=godot gui-current-invariant-gate
python3 -B tools/check_docs.py
git diff --check
```
