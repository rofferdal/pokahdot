# Bot Fold versus Call after Raises

Status: complete; BFCR-00–10 implemented and verified on 2026-11-01.
The follow-up restores balanced aggression under policy `street_response_v3`.
BFCR-00–05 were authorized for sequential implementation on 2026-11-01.
The follow-up retains the constraints of no GUI or interactive CLI changes;
stop and explain before any required presentation change. Published profile
Resources remain immutable.
Evidence date: 2026-11-01. Baseline: `2cc5963`, Godot 4.7.2.

## Finding

The investigation and controlled examples below describe the original policy
at the recorded baseline revision. The implemented correction and measured
results are recorded in the execution sections below.

The observation has merit: the baseline model could repeatedly minimum-raise and
then fold with Call available. Two distinct mechanisms are reproducible.
However, repeated raises do **not** establish that either bot holds a strong
hand. The clearest reproduced raise war consists entirely of weak-hand bluffs.
These controlled examples establish behavior, not its frequency in normal
play or the mathematically optimal response. Measure those separately before
claiming that the roster generally folds too often.

## Verified baseline implementation

The relevant sources are:

- [StrategyDecisionModel](../scripts/core/agents/strategy_decision_model.gd):
  `_eligible_bluff`, `_choose_legal_action`, `_should_continue`,
  `_choose_continuation`, and `_wager_target_for_estimate`.
- [HandPotentialEstimate](../scripts/core/agents/hand_potential_estimate.gd)
  and [StrategyDecisionTrace](../scripts/core/agents/strategy_decision_trace.gd):
  heuristic scores and weak/marginal/strong/premium boundaries.
- [PlayableBotRoster](../scripts/core/agents/playable_bot_roster.gd): the
  current catalog includes five hand-authored strategic profiles and ten
  published strategic profiles, plus three optional legacy profiles.
- [PublicActionRecord](../scripts/core/public_action_record.gd) and
  [HandController](../scripts/core/hand_controller.gd): public history and
  action validation.

### 1. Repeated weak-hand bluff rolls create raise-or-fold behavior

`_eligible_bluff` runs before normal continuation. A score below 30 and a
legal Bet or Raise make a fresh bluff roll eligible on every decision. A
successful roll chooses the legal minimum wager. There is no restriction
based on earlier raises, a previous bluff, opponent resistance, or the number
of remaining opponents. No same-street aggression history is consulted.

If the roll fails, the model proceeds to normal continuation. A weak hand
usually fails that threshold and folds. A failed bluff roll does not switch
the bot into a special calling policy. If raising rights are closed, the
bluff branch is unavailable and the same continuation gate still applies.

This is particularly relevant to the actual product roster: published
**Phantom-Copper Inferno** has `bluff_rate = 92`, and **Phantom Blaze** has
`bluff_rate = 88`. The other eight published profiles range from 34 to 55.
These percentages apply to each eligible decision, not once per hand.
Hand-authored Loose Cannon uses 22; Balanced uses 12.

### 2. A hard continuation gate decides whether calling is considered

With an estimate available, the current threshold is:

```text
T = 75 - 0.45 * tight_vs_loose
    + 8 * C / (P + C)
    + 4 * C / (S + C)
    - min(position_ordinal, 5)
continue iff score >= T
```

Here `C` is the actual capped additional call, `P` is the pot before calling,
and `S` is the actor's remaining stack. The zero-denominator guards remain
part of the implementation. The stack term uses the actor's stack, despite
nearby comments referring to effective stacks.

`call_vs_raise` is consulted only **after** this gate succeeds. Lowering that
parameter cannot make a rejected call acceptable. Conversely, if this gate
passes and Call is legal, the ordinary continuation branch already chooses
Call or Raise, not Fold. A raise/fold reversal can occur when rising stack
pressure moves the threshold across an unchanged score.

The score is a heuristic, not a winning probability. Postflop it is based on
made-hand category, draws and board texture; preflop it also includes position.
Cheap pot odds currently reduce the price penalty toward zero but do not
remove the profile's base strength requirement.

### 3. Other mechanisms must remain distinguishable

- Non-bluff sizing uses minimum/half-pot/pot/maximum targets by score band,
  clamped to legal bounds. A minimum raise alone does not prove a bluff.
- Invalid model actions can produce a separate fold-first fallback in
  `HandController`. The reproductions below apply successfully through
  `BettingRound`; they are ordinary policy folds, not rejection fallbacks.
- Public action history spans the whole hand. Its records currently carry
  no street identifier. Counting all recorded raises as current-street raises
  would introduce a new bug.

## Controlled reproductions

All cases use the existing model and unmodified profile Resources. Two seats,
button/small blind at seat 0, blinds 5/10, preflop. Construct `Player`, `Table`,
`BettingRound` and `PotManager`; record blinds and each applied action's
`chips_committed`. Obtain each decision through `GameView.for_preflop`.
Use independent `RandomNumberGenerator` seeds as listed below. Apply every
chosen action through `BettingRound.apply_action` and require success.
These are controlled betting-round fixtures, not tournament seed replays.

### A. Published profile: six minimum raises followed by a fold

Both seats use
`published/candidate_g1_mut_0004_23c4aa0775d54bec__20261024_r3b0.tres`
(Phantom-Copper Inferno). Starting stacks: 1000 each. Cards: seat 0 `7S 2H`,
seat 1 `8C 3D`. Model RNG seeds: seat 0 = 2, seat 1 = 3.

| Actor | Score | Pot before action | Call cost | Chosen action | Trace branch |
| --- | --- | --- | --- | --- | --- |
| 0 | 6 | 15 | 5 | Raise to 20 | `bluff_raise` |
| 1 | 14 | 30 | 10 | Raise to 30 | `bluff_raise` |
| 0 | 6 | 50 | 10 | Raise to 40 | `bluff_raise` |
| 1 | 14 | 70 | 10 | Raise to 50 | `bluff_raise` |
| 0 | 6 | 90 | 10 | Raise to 60 | `bluff_raise` |
| 1 | 14 | 110 | 10 | Raise to 70 | `bluff_raise` |
| 0 | 6 | 130 | 10 | Fold | `fold` |

The last call would cost 10 into a final pot of 140 (7.14%). This establishes
the observed pattern, but does not prove that calling with `7S 2H` is correct.
The more direct weakness is the repeated bluff eligibility that creates it.

A second reproduction uses both hand-authored Loose Cannon profiles, the same
cards/stacks, and RNG seeds 382/383: raise to 20, raise to 30, raise to 40,
then fold with a 10-chip call into a 70-chip pot.

### B. Non-bluff raise followed by a threshold-driven fold

Seat 0 uses Loose Cannon, holds `JS 8S`, and has model RNG seed 2. Both seats
start with 30 chips; seat 1 holds `3C 2D`. Seat 1 is scripted to make the next
legal minimum raise, so this does not assert its model would choose that raise.

| Decision | Score | Remaining stack | Pot | Call | Threshold | Result |
| --- | --- | --- | --- | --- | --- | --- |
| Seat 0 first action | 33 | 25 | 15 | 5 | 32.6667 | `continue_aggressive`, raise to 20 |
| Seat 1 scripted response | — | 20 | 30 | 10 | — | Raise to 30, all-in |
| Seat 0 response | 33 | 10 | 50 | 10 | 33.3333 | `fold` |

The cards and score did not change. The remaining 10-chip call would complete
a 60-chip pot (16.67%). Calling is legal; raising is no longer available.
This demonstrates the threshold discontinuity, not that `JS 8S` is a premium
hand or that a solver would always call against an unknown opponent range.

### Verification performed

- Both mechanisms reproduced through legal core betting transitions.
- Existing strategy model, sizing and action-policy coverage suites: **37
  tests passed, 1260 assertions**. These mainly establish current policy and
  legality; passing them does not establish strategic quality.
- Session probe and logs are under ignored `localtmp/bot-fold-investigation/`.
  They are optional local evidence. The setup, seeds and results above are
  retained here so future tests can recreate the cases without those files.

## Implementation design

### MVP: distinguish calling, value raising, and bluff eligibility

1. **Evaluate call viability separately from raise desirability.** Keep a
   price-sensitive calling policy and a stricter value-raise policy. A hand
   that can justify a cheap call should not need to meet the same criterion
   for putting in another raise. Start with an explicitly heuristic,
   calibrated policy using additional call cost, contestable pot, remaining
   stack, street, made-hand/draw quality and public opponent pressure. Do not
   compare `score / 100` directly with pot odds as if it were equity.
2. **Constrain repeated weak bluffs.** Proposed initial eligibility rule:
   at most one weak-hand bluff attempt by a bot per street; no new weak bluff
   re-raise after an opponent re-raises that bot. Keep `bluff_rate` as the
   probability within the eligible set. Then evaluate Call versus Fold using
   the hand and price. This intentionally allows a failed bluff to fold.
3. **Reduce repeated marginal value raises after resistance.** Make an
   opponent re-raise reduce raise propensity for marginal hands that still
   qualify to call. Preserve meaningful value re-raises for strong hands and
   differences between profiles; avoid a universal raise-count cap.
4. **Explain decisions in private diagnostics.** Record call cost, relevant
   pot, score, call threshold, raising eligibility, street raise context,
   bluff eligibility/rejection reason and final branch in test/simulation
   traces. Do not expose hidden strategy diagnostics through normal UI,
   events, or another seat's `GameView`.

Do not implement “always call after raising.” Previous contributions are
already committed; a prior raise is context, not a reason to spend more chips
regardless of price. A legal minimum re-raise can still be expensive after a
large previous raise. Short all-ins, side-pot eligibility, multiway action
behind the caller, missed draws and large bets must remain explicit cases.

For terminology, [PokerStars Learn's pot-odds guide](https://www.pokerstars.com/poker/learn/lesson/pot-odds/)
explains the relationship between calling price and required equity. A
price-aware heuristic is still not an equity estimator or proof of optimal
tournament play. Range-based equity evaluation is a possible later phase,
not an MVP dependency; it would need its own performance and calibration work.

### Architecture boundaries

Keep the policy in `scripts/core/agents/`, using typed values and only the
recipient-safe view plus injected per-seat RNG. Keep poker legality and chip
accounting in the existing core rules. GUI and CLI need no policy duplication.

`PublicActionRecord` now carries an optional street identity, preserved in
copies and stamped by `HandController`. `StrategyStreetContext` filters this
history for current-street actions and reconstructs whole-hand contributions
for prospective side-pot pricing. No private bluff intent is stored in public
records, and no private per-hand model state is needed. Private scalar
`StrategyDecisionDiagnostics` snapshots explain eligibility and call/raise
criteria through existing test/simulation trace hooks only.

Changing model behavior affects all 15 strategic profiles and invalidates
assumptions behind their earlier performance results. Keep published Resources
and historical reports immutable. Record the new policy/source identity,
rebenchmark the whole curated roster, and follow the existing promotion
workflow for any later profile changes. Do not silently reinterpret parameter
values or compare old/new reports as equivalent experiments.

## BFCR-00–05 execution decisions and pre-registered acceptance

The independent parameter review recommends retaining the existing four profile
fields for this correction. The user also declined additional call-tolerance
or resistance-response parameters. No parameter extension is planned; the
shared weak-bluff attempt limit is a policy rule. Profile publication remains
outside this correction.

Before candidate measurements, the following policy and margins were selected:

- Add an optional street identifier to public action records. Preserve it in
  copies; production records supply the actual street and blinds use preflop.
  Existing GUI/interactive CLI consumers continue reading the original fields.
- Derive typed street context from public history. A weak bluff roll is eligible
  only before the hero's first voluntary action on that street. This provides
  at most one opportunity without retaining private lifecycle state.
- Reconstruct contributions from maximum street-total amounts per seat/street;
  require the reconstructed sum to match the current pot. Cap each contribution
  at the hero's prospective hand contribution after calling to exclude side
  pots the hero cannot win. Ambiguous side-pot snapshots receive no cheap-call
  credit. Folded chips remain included when contestable.
- Preserve the former threshold for value aggression. For nonweak scores
  (at least 30) and price below 25%, lower the **call** threshold by
  `4 * (1 - price / 0.25) / (1 + 0.5 * max(0, opponents - 1))`.
  This is a bounded heuristic adjustment, not an equity calculation. Calls at
  prices of 25% or more receive zero credit. Suppress marginal value re-raises
  after opponent aggression following the hero's own aggression; strong and
  premium hands retain value-raise options.
- Identify the candidate policy explicitly in private diagnostics and benchmark
  evidence. Count actual eligible bluff opportunities in simulation diagnostics;
  do not silently compare old and new metric denominators as equivalent.

Baseline calibration has 180 tournaments and 1,378 cheap nonweak responses,
with 148 folds (10.740%); confirmation has 180 tournaments and 1,347 such
responses, with 147 folds (10.913%). Both have zero invalid actions and complete
chip-conserving outcomes. Each cohort covers all 15 profiles, 2/6/9 seats,
100/1000-chip starting stacks, and mirrored seat orders. Cheap means call price
at most 20%; expensive means at least 40% in this benchmark.

Candidate acceptance, fixed before inspecting candidate results:

- Zero repeated weak bluffs by the same seat on a street, invalid actions,
  incomplete tournaments, or chip drift in either cohort.
- At least 50% fewer chains of three consecutive raises in each cohort.
- A strictly lower cheap-nonweak response fold rate in each cohort; retain
  denominators and confidence intervals, without claiming causal significance
  from changed game trajectories.
- The controlled J8 suited case calls; weak-hand controls still fold; paired
  expensive-price unit cases preserve rejection rather than broadly loosening.
- Same-machine cohort runtime no more than three times baseline. Report every
  profile's behavior and tournament outcomes; do not infer overall strength
  improvement from this sample. Expensive tournament strata are descriptive
  because baseline sample sizes are only 6 and 14.

## Tasks and acceptance criteria

### BFCR-00 — Verify the reported mechanisms

- [x] **Status: complete.** Inspect model, estimator, roster and existing tests;
  reproduce bluff chains and a non-bluff raise/fold threshold crossing.
- [x] Distinguish verified mechanisms from unmeasured frequency and unproven
  strategic optimality; retain portable reproduction details above.

### BFCR-01 — Capture a reproducible behavioral baseline

- [x] **Status: complete. Depends on: BFCR-00.** Promote both cases into tracked
  deterministic regression fixtures generated by the tests themselves.
- [x] Sample all 15 strategic profiles in heads-up, six-seat and nine-seat
  games, with mirrored seats, fixed seeds and shallow/deep stacks. Include
  real hand/tournament transitions as well as controlled betting rounds.
- [x] Count response opportunities after own aggression: fold/call/raise,
  bluff/value branch, call-to-pot ratio, stack pressure, street and opponent
  count. Separate chains of at least three consecutive raises and separate
  invalid-action fallback folds. Report denominators and uncertainty.
- [x] Acceptance: a repeatable baseline distinguishes whether observed folds
  follow bluffs, value raises, threshold crossings or invalid actions. No
  test depends on pre-existing `localtmp/` files.

Evidence: tracked benchmark support, manual runner and three integration tests
pass (37 assertions). Complete-history baseline reports use seeds 61001 and
91001, respectively, with 180 tournaments each. Calibration: 76,953 decisions,
12,375 responses, 1,685 long raise chains, 5,862 repeated weak bluffs;
confirmation: 75,344 decisions, 12,701 responses, 1,598 chains, 6,140 repeats.
All tournaments completed with conserved chips and zero invalid actions.
Reports include per-profile/price/pressure/street/opponent/previous-branch
strata, source/profile hashes and Wilson intervals. Local reports are
`localtmp/bfcr/baseline-{calibration,confirmation}-complete-history.json`;
regenerate them using the baseline source when needed, never as test inputs.

### BFCR-02 — Define street context and diagnostic contracts

- [x] **Status: complete. Depends on: BFCR-01.** Choose and document the typed
  street-context representation, reset rules and private diagnostic fields.
- [x] Test multi-street histories, blind records, short all-in raises, opponent
  folds, multiway re-raises, snapshot copies and deterministic replay.
- [x] Acceptance: current-street aggression counts exclude prior streets;
  hidden cards and private bluff intent never enter public records. Update
  `ARCHITECTURE.md` with the selected design before policy implementation.

Evidence: context, GameView and complete-hand tests pass (20 tests, 114
assertions); private diagnostic/trace copy tests pass (6 tests, 65 assertions).
Street metadata is stamped only in core public records; no adapter files were
changed. `StrategyDecisionDiagnostics` is copied through private trace hooks
and contains scalar policy explanations, never cards or mutable game objects.

### BFCR-03 — Implement and calibrate the MVP policy

- [x] **Status: complete. Depends on: BFCR-02.** Separate call viability and
  value raising; constrain repeated weak bluffs and marginal re-raises.
- [x] Define numeric policy margins and expected outcomes from BFCR-01 evidence
  before tuning. Keep existing four parameters unless evidence demonstrates
  that an explicit, versioned extension is necessary.
- [x] Add cheap-call, expensive-call, strong-value, weak-bluff, missed-river-draw,
  multiway, side-pot, all-in and closed-raise-rights cases. Include a sequence
  where a non-bluff raise receives a small re-raise and a qualifying hand calls.
- [x] Acceptance: repeated weak bluff chains are prevented under the defined
  eligibility rule; qualifying calls survive when further raising is rejected;
  expensive or hopeless calls still fold. All actions validate, chip totals
  are conserved, and fixed seeds reproduce results under the new policy.

Evidence: policy, sizing, trace and legality suites pass (43 tests); new legal
response sequences pass (14 tests, 182 assertions after BFCR-04 refinement), including cheap/expensive
calls, weak bluffs, missed river draws, strong value raises, side pots and
closed raising rights. Simulation metrics/parameter endpoint/batch suites pass
(16 tests). Private diagnostics identify `street_response_v2`; eligible-bluff
metrics use actual attempt eligibility and fallback traces preserve context.

### BFCR-04 — Compare behavior and protect roster quality

- [x] **Status: complete. Depends on: BFCR-03.** Run matched baseline/candidate
  cohorts plus independent confirmation seeds. Retain source/profile hashes,
  seat assignments and the denominators from BFCR-01.
- [x] Acceptance: fewer repeated weak-bluff raise chains and fewer rejected
  cheap calls in the targeted eligible cohort, without achieving this by
  indiscriminately calling weak hands. Report profile-level effects, expensive
  call behavior, invalid actions, runtime and tournament performance separately.
  Set quantitative acceptance margins from baseline data before evaluating
  the candidate; do not choose them after seeing the result.
- [x] Re-evaluate all curated strategic profiles. Do not overwrite published
  Resources or claim performance improvement from these two examples alone.

Evidence: refined calibration and fresh confirmation each pass all eight
pre-registered comparison checks. Both contain 180 completed tournaments across
all 15 profiles; no profile Resources changed. Final figures are retained
below. Comparison validation reconstructs summary counts from raw rows and
rejects inconsistent counters, non-finite values and invalid cohort identities.

### BFCR-05 — Regression and documentation completion

- [x] **Status: complete. Depends on: BFCR-04.** Run the complete existing GUT
  and Python suites and required checks, plus targeted new sequence tests.
- [x] Reconcile current `README.md`, `docs/ARCHITECTURE.md`, strategy calibration
  guidance and affected `devdocs/` material with implemented behavior. Preserve
  archived reports and distinguish former calibration from new evidence.
- [x] Acceptance: all checks pass, Markdown links validate, measured results
  and limits are recorded, and tasks are marked complete only after verification.

Final verification: `make check gui-current-invariant-gate` passes with
944 main Godot tests, 245 Python tests, 17 layout characterization tests,
all four M3/phone/iPad/desktop invariant gates, lint and formatting. A final
`make docs-check` passes (35 documentation/tool tests, 29 current Markdown files,
zero link/format errors, and policy/coverage guards). Independent code review
found no remaining blocker. The full log is `localtmp/bfcr/full-check.log`.
No files under `scripts/gui/`, `scripts/cli/` or `scenes/` changed; existing
CLI/GUI tests and all presentation gates pass. Published `.tres` profiles and
all four parameter fields are unchanged. `localtmp/` was emptied before work;
new session evidence was then generated there and is not a test prerequisite.

## Follow-up: restore sensible aggression

The user reports that bots now feel too passive. Review supports this concern:
across calibration and fresh confirmation, nonweak responses after the actor's
own earlier aggression raised 1,337/3,047 times (43.88%) under the original
policy, versus 223/1,548 (14.41%) under `street_response_v2`. These are
conditional response rates, not all-action raising frequencies. Reached states
differ, so the figures describe a concern rather than prove optimal aggression.

Two absolute restrictions explain the change: a score below 60 cannot value
re-raise after resistance, regardless of `call_vs_raise`; weak bluffs are
unavailable after the actor's first voluntary action or two prior increases.
The heuristic's marginal band includes useful hands such as A-K suited
preflop. The bluff restriction also excludes delayed bluffs and bluff
check-raises. Removing all of these choices can flatten profile personalities.

The earlier acceptance criteria over-weighted chain reduction. Passing them
verified suppression and legality, but did not adequately protect healthy
aggression. BFCR-00–05 remain completed historical work; their 50% chain-
reduction minimum and zero-repeat-bluff target are **not acceptance targets
for this follow-up**. Existing hard-ban regression tests must be explicitly
reconciled with the selected replacement policy, not silently deleted.

Direction: preserve separate call evaluation and reliable contestable-pot
pricing, but replace broad aggression bans with bounded, context-sensitive
probabilities where appropriate. Use the existing four profile parameters.
No new call-tolerance or resistance parameter, profile publication, tilt
functionality, GUI change, or interactive CLI change is included. If a
presentation change becomes necessary, stop and explain before proceeding.

### Follow-up baseline and pre-registered balance criteria

The user authorized BFCR-06–10 implementation on 2026-11-01. The immediate
baseline is frozen `street_response_v2`, with production/resource SHA-256
values and an isolated source copy under `localtmp/bfcr-aggression/`.
The original policy remains historical context, not an aggression target.
The new calibration cohort starts at seed 201001; bank calibration uses
151001–151032. Confirmation is reserved at tournament seed 301001 and bank
seed 351001 (32 samples) and must not be inspected before candidate selection.

The fixed decision bank uses real legal transitions, complete public history,
all four streets, 2/6/9-seat tables plus targeted three-seat cases, shallow/deep
stacks, all 15 current profiles, and five isolated parameter controls. The
verified A-K suited response has score 49 and legal raising rights; v2's
0/50/100 raising controls all call because the blanket veto blocks the choice.
The weak backdoor fixture is A-S/2-S on 8-S/9-D/J-H: score 24 and draw quality
25, not a direct-out draw. Selected backdoor cases build their larger pots
through a legal preflop raise/calls so additional price is below 20%.

Acceptance, selected before changing production policy:

- **Call quality:** preserve 100% of fixed-state continuations with bluffing
  disabled where v2 continues; when no full raise is legal, preserve exact
  Call decisions (including J8 suited and closed-rights controls). Preserve
  all Fold decisions in expensive-value, weak-repeat and missed-river-draw
  control rows. A newly sensible Raise may replace Call when rights are open.
- **Value aggression:** in the selected heads-up deep A-K small re-raise case,
  raising preference 0 must produce zero raises; preference 50 must raise in
  more than 5% of the 32 coupled seeds and less often than preference 100;
  preference 100 must raise in 20–85%. These broad margins require meaningful
  aggression and retained calls, without aiming for the original policy's
  rate. Increasing only the preference must not turn a same-seed Raise into
  Call. Positive preferences must retain positive effective percentages when
  the intrinsic strength/legal gate passes; do not require every tight profile
  to enter every hand. Strong-value and initial-aggression control actions
  remain identical to v2 on coupled seeds.
- **Bluff opportunities:** the selected cheap, heads-up/three-seat flop
  backdoor windows become eligible after a prior Check/Call or two opposing
  wager increases. Eligible 100-percent controls bluff in every sample;
  zero-percent controls never bluff. Expensive, missed-river and no-useful-draw
  controls remain ineligible. Both initial and one explicitly distinct delayed
  opportunity may occur; applied own aggression prevents another weak bluff
  on that street. No private attempt state or UI contract is required.
- **Tournament balance:** nonweak post-aggression raise share must improve by
  at least five percentage points over v2 in calibration and untouched
  confirmation. Cheap-nonweak fold rate may not worsen by more than two
  percentage points; fixed-state preservation is the primary call-quality
  guard because tournament populations change. Report all-profile/action
  denominators and paired tournament uncertainty, not only aggregate counts.
- **Escalation and correctness:** report complete chain-length distributions,
  not a minimum percentage reduction in chains of three. Streets with more
  than 12 consecutive raises must be at most 1% of observed betting streets,
  and no observed chain may exceed 32. Require zero invalid actions, chip drift
  and incomplete tournaments. Same-machine runtime must stay within twice v2
  for matching workloads. These guardrails protect against pathological tails;
  they do not reward eliminating ordinary multi-raise hands.

These margins deliberately evaluate healthy raising and preserved calling
separately. They must not be relaxed after seeing a candidate; failed criteria
require recorded analysis and revised candidates with fresh confirmation if
previously held-out results were inspected.

### BFCR-06 — Establish balanced acceptance criteria

- [x] **Status: complete. Depends on: BFCR-05.** Freeze `street_response_v2`
  source/profile identities and establish the overcorrected policy as the
  immediate comparison baseline. Retain original-policy evidence as historical
  context, without treating its aggression rates as ideal targets.
- [x] Build a deterministic bank of identical legal decision situations across
  streets, profiles, prices, stack depths and table sizes. Include A-K suited
  after a small re-raise, J8 suited facing the documented small all-in, strong
  value re-raises, weak repeated minimum raises, prior checks/calls, and
  expensive or hopeless calls. Recreate all fixtures from tracked inputs.
- [x] Measure legal and policy-eligible raising opportunities separately from
  realized raises. Separate initial aggression, value re-raises, initial bluffs,
  delayed/check-raise bluffs, and repeated weak bluffs; report all-action and
  post-aggression rates with explicit denominators per profile and street.
- [x] Before tuning, record numeric improvement/non-regression margins for
  appropriate re-raise opportunities, profile responsiveness, cheap-call
  retention, excessive weak escalation, and runtime. Choose margins from the
  frozen decision bank and baseline evidence; document the rationale. Use
  bounded escalation measures and tail lengths rather than minimizing every
  chain of three raises. Do not reinstate a blanket reduction percentage.
- [x] Acceptance: candidate selection requires both preserved calling quality
  and restored appropriate aggression. Fixed-state comparisons distinguish
  direct policy effects from tournament population changes. Hold out new
  confirmation seeds that have not been inspected during earlier work.

Evidence: the frozen bank has 237 legal states, 4,740 profile/state rows and
151,680 seeded decisions (32 samples each), covering all 15 actual profiles
plus five isolated controls. Five integration tests pass with 10,469 assertions.
The heads-up A-K response has zero v2 raises for all 0/50/100 controls; selected
backdoor controls have score 24 and cheap prices 1/6, 2/11 and 1/12. The helper
SHA-256 is `0fc390c749611f6906f12a5eeaa3e5a0c17d16c0b4b6547352ee56c358667bf0`.
The baseline report SHA-256 is
`b3ea50a359a378e23e13900fe3d02f814b56e99b6c20e0757c23c1d2535ac6df`.
Baseline bank runtime is 37.165 seconds; v2 calibration has 180 completed
chip-conserving tournaments, 89,385 decisions, 112 three-raise chains and zero
invalid actions. Numeric balanced criteria are recorded above before candidate
implementation; no code, resource or test requires these local report files.

### BFCR-07 — Replace the blanket marginal re-raise ban

- [x] **Status: complete. Depends on: BFCR-06.** Design and document a bounded
  resistance adjustment using hand potential, additional price, prior wager
  sizes, opponents and the existing `call_vs_raise` preference. Retain the
  ability to reject poor raises, but do not make every score below 60 ineligible
  solely because an opponent raised back.
- [x] Separate whether a value raise is sensible from how often a profile
  selects it. For controlled qualifying situations, resistance should reduce
  raising propensity while leaving a nonzero re-raise option for aggressive
  profiles. Update private diagnostics to explain that adjustment and identify
  a new policy revision; do not relabel the current implementation in place.
- [x] Replace the regression requiring A-K suited always to call after
  resistance with seeded, identical-view tests for sensible calls and re-raises.
  With bluffing disabled and other settings fixed, test that increasing
  `call_vs_raise` affects re-raising in eligible situations; zero still selects
  the passive alternative. Preserve strong-hand aggression and illegal-raise
  exclusion, including short all-ins and closed raising rights.
- [x] Acceptance: existing aggressive profiles retain observable re-raise
  personality under the BFCR-06 criteria. The legal J8 suited small-all-in case
  still calls, and expensive/weak controls can still fold. No sunk-cost rule
  forces either calling or raising simply because chips were committed earlier.

Evidence: the value-only policy is frozen separately as
`street_response_v3_value` for ablation. Forty-five focused tests pass; the
updated legal response suite passes 15 tests with 1,093 assertions. On the
identical A-K case, raising preferences 0/50/100 produce 0/15/22 raises out of
32 (effective percentages 0/31.8333/63.6667); paired-seed monotonicity holds.
J8 all-in calls, strong raises, expensive/missed-draw folds, side-pot prices
and closed raising rights still pass. Call-policy code remains unchanged from
v2; no UI, profile or parameter-schema changes were needed.

### BFCR-08 — Restore selective bluff opportunities without repeated roll wars

- [x] **Status: complete. Depends on: BFCR-07.** Reconsider first-action and
  two-increase bans independently. Distinguish a first bluff after an earlier
  check/call from another bluff raise after the actor's own aggression; a prior
  passive action alone must not automatically rule out every later bluff.
- [x] Define a coherent, bounded opportunity policy using public betting
  context, price, street, draw potential and existing `bluff_rate`. Decide
  explicitly which delayed/check-raise and repeat-bluff situations are eligible.
  Avoid restoring an unrestricted independent bluff roll after every min-raise;
  high bluff settings must still respect escalation constraints.
- [x] Add deterministic tests for a selected delayed bluff/check-raise, a failed
  first opportunity, opponent resistance, repeated small raises, high-price
  pressure, and street/hand resets. If private attempt state is necessary,
  specify reset and repeated-snapshot semantics before implementation; do not
  infer opponents' private intent or expose own intent through public records.
- [x] Preserve zero-percent and eligible hundred-percent parameter behavior,
  RNG reproducibility, actual eligibility denominators and fallback diagnostics.
  Reconcile the old hard-ban tests with positive and negative replacement cases.
- [x] Acceptance: the selected plausible bluff opportunities are restored while
  repeated weak escalation stays within the BFCR-06 bounds. Failed bluffs may
  still fold; cheap calls continue to depend on useful hand potential and price.

Evidence: final policy `street_response_v3` passes 45 focused tests and the
expanded policy/context suite (30 tests, 1,630 assertions). Positive backdoor
Check/Call/pressure-entry windows and negative expensive, river, multiway,
no-draw, prior-aggression and exhausted-window controls pass. Eligible 0/100%
bluff behavior and seeded outcomes reproduce; ineligible decisions consume no
bluff RNG. The null/empty-view trace guard now supplies an explicitly typed
empty legal-action array; its error-handling contract is tested. Call evaluation
and the BFCR-07 value logic remain unchanged. Separate source-frozen value-only
and bluff-only variants support the BFCR-09 ablation; no private attempt state,
UI change, profile Resource or parameter extension was needed.

### BFCR-09 — Validate the balance and profile diversity

- [x] **Status: complete. Depends on: BFCR-08.** Compare the corrected policy
  with frozen `street_response_v2` on identical decision-bank snapshots and
  seeded full tournaments across all 15 profiles, 2/6/9 seats, shallow/deep
  stacks and mirrored positions. Evaluate BFCR-07 and BFCR-08 effects separately
  as well as together so one change cannot conceal a regression in the other.
- [x] Report per-profile legal/eligible opportunity counts and fold/call/raise
  rates, value/bluff split, chain lengths/tails, cheap and expensive decisions,
  invalid actions, chip conservation, completion, runtime and tournament
  outcomes. Account for tournament clustering and changed reached states when
  describing uncertainty; do not call a higher raise count proof of strength.
- [x] Update comparison tooling and its tests for the new pre-registered
  criteria. Preserve the old reports/check results and record why the earlier
  blanket chain/zero-repeat criteria were superseded. Report hashes and source
  identities must distinguish original, overcorrected and follow-up policies.
- [x] Acceptance: satisfy both aggression and calling criteria from BFCR-06
  on calibration and untouched confirmation evidence, with zero invalid actions
  and chip drift. Do not relax margins after seeing results. If tuning follows
  a confirmation failure, record it and reserve fresh confirmation seeds.
  Retain per-profile evidence and limitations without changing published Resources.

Evidence: calibration and untouched confirmation pass all 14 balanced guards
in `compare_strategy_aggression.py`, including the separate value-only variant.
The bluff-only calibration additionally isolates restored bluff windows without
restoring the old marginal value ban. Reports preserve source/profile hashes,
all-profile summaries, legal/eligible denominators, complete positive-chain
histograms and whole-tournament paired bootstrap intervals (1,000 resamples).
The checker validates counts, cohort identities and complete state metadata;
nine Python tests cover acceptance and corrupted evidence. Earlier chain-
reduction criteria and comparison artifacts remain historical and unchanged.
Final quantitative results are recorded below; no margin was relaxed after
candidate or confirmation results were inspected.

### BFCR-10 — Complete regression and documentation review

- [x] **Status: complete. Depends on: BFCR-09.** Run all existing GUT/Python
  suites and required quality/presentation gates, including new positive
  aggression, cheap-call, side-pot, reset, privacy and deterministic tests.
- [x] Reconcile `README.md`, `docs/ARCHITECTURE.md`, this backlog, simulation
  metric/parameter guidance and affected `devdocs/` with verified behavior.
  Preserve the original and `street_response_v2` results as historical evidence;
  no old passing count certifies the new policy.
- [x] Acceptance: all checks pass, current Markdown links validate, and the
  follow-up record explains both restored aggression and preserved call quality.
  Confirm no GUI/interactive CLI code or profile parameter schema changed;
  mark these tasks complete only after the corresponding evidence exists.

Final follow-up verification: `make check gui-current-invariant-gate` passes
956 main Godot tests, 254 Python tests, 17 layout characterization checks and
all four M3/phone/iPad/desktop invariant gates, plus lint and formatting.
Final `make docs-check` passes 44 documentation/tool tests and 29 Markdown
files with zero errors. Independent review found no remaining production
blocker; two comparison-validation findings were fixed and regression tested.
Logs are under `localtmp/bfcr-aggression/` and are optional generated evidence.

SHA-256 scope verification against the initial frozen v2 manifest confirms
unchanged GUI scripts (207 files), interactive CLI scripts (30), scenes (33)
and profile Resources (18). Final measured production sources remain identical
to the accepted candidate. Only the three strategy/context/diagnostic core
files changed in production for this follow-up. Test support, comparison tools
and documentation supply the new validation; report/profile schemas, game
interfaces and existing parameter values remain unchanged.

## Follow-up measured results: `street_response_v3`

Calibration and untouched confirmation pass all 14 balanced acceptance guards.
Each cohort includes 180 full tournaments across all 15 frozen profiles,
2/6/9 seats, 100/1000-chip stacks and mirrored positions. Each fixed bank has
237 legal situations, 20 actual/control profiles and 32 coupled seeds
(151,680 decisions). Source identities and input SHA-256 values are retained
in `calibration-accepted.json` and `confirmation-accepted.json` under
`localtmp/bfcr-aggression/`; production/resource manifests preserve v2 and the
isolated variants. No new parameter or profile Resource was introduced.

| Metric | Calibration: v2 → v3 | Confirmation: v2 → v3 |
| --- | --- | --- |
| Nonweak post-aggression raises/opportunities | 112/739 → 264/826 | 116/774 → 265/862 |
| Nonweak post-aggression raise share | 15.16% → 31.96% | 14.99% → 30.74% |
| Cheap nonweak folds/opportunities | 23/594 → 28/671 | 10/630 → 18/724 |
| Cheap nonweak fold rate | 3.87% → 4.17% | 1.59% → 2.49% |
| Maximum consecutive raises | 4 → 5 | 4 → 4 |
| Chains with at least three raises | 112 → 142 | 88 → 123 |
| Observed streets with more than twelve raises | 0 → 0 | 0 → 0 |
| Invalid actions/chip drift/incomplete tournaments | 0 → 0 | 0 → 0 |
| Full-tournament runtime, seconds | 24.37 → 26.42 | 25.08 → 27.74 |

The controlled A-K preference sweep 0/50/100 raises 0/15/22 times out of 32 in
calibration and 0/13/24 in confirmation. Raising probabilities are 0/31.8333/
63.6667%; observed frequencies differ with the seeds. QA additionally checks
same-seed monotonicity; aggregate counts alone do not prove that property.
Call-only J8/closed-rights decisions, qualifying continuations, expensive and
missed-draw Fold controls, and all-profile initial/strong actions are preserved
on fixed snapshots. All selected cheap backdoor windows are taken by the
100% bluff control and never by the 0% control. Ineligible controls and applied
own-aggression/window limits pass.

The cheap-fold tournament rates increase by 0.30 and 0.90 percentage points,
within the pre-registered two-point allowance. Calling logic is unchanged;
fixed-state preservation is the direct non-regression evidence. Policy changes
alter which states are reached, so this does not establish identical tournament
calling quality or strategic optimality.

Whole-pair tournament bootstrap intervals (1,000 resamples, fixed seed 769013)
for raise-share improvement are +12.48 to +20.72 percentage points in
calibration and +12.18 to +19.50 in confirmation. Cheap-fold-rate change
intervals are -1.80 to +2.20 and -0.11 to +1.87 points. These describe the
matched cohort and retain tournament clustering; no playing-strength or
promotion claim follows from them.

### Isolated effects and profile variation

The value-only calibration restores nonweak raising to 31.92%; the bluff-only
calibration remains at 15.05%, compared with v2's 15.16%. The combined policy
is 31.96%. Value-only confirmation is 31.24%, combined 30.74%. Restored weak
backdoor opportunities are verified in isolated/combined fixed-state banks.
All 2,060 nonweak calibration bank rows have identical actions and branches
between value-only and combined policies: the bluff change does not conceal
a value-policy regression on those snapshots. The isolated source copies
preserve the v2 value veto for bluff-only and v2 bluff restrictions for value-
only; neither is an exported product mode.

All fifteen profiles were examined. Each has 136 appearances across the two
final cohorts. The following table sums full-decision data across those
cohorts; legal versus eligible raises remain explicit in the raw summaries.
Tournament outcomes reflect this mixed roster and changed trajectories, not
proof that a profile is stronger. Lower-aggression profiles need not enter a
hand their own strength threshold rejects.

| Profile | Wins: v2 → v3 | All-action raises: v2 → v3 | Legal raise opportunities: v2 → v3 |
| --- | --- | --- | --- |
| all | 0 → 0 | 36956 → 38613 | 149927 → 154790 |
| category:initial_bluff | 0 → 0 | 32414 → 33533 | 32414 → 33533 |
| category:initial_value | 0 → 0 | 3725 → 3914 | 100480 → 103223 |
| category:passive_response | 0 → 0 | 589 → 636 | 3334 → 3517 |
| profile:nit_caller | 0 → 0 | 120 → 122 | 9182 → 9278 |
| profile:tight_aggressive | 0 → 0 | 773 → 742 | 10309 → 9680 |
| street:flop | 0 → 0 | 492 → 540 | 2893 → 2916 |
| street:preflop | 0 → 0 | 36175 → 37797 | 145101 → 149929 |
| street:river | 0 → 0 | 76 → 74 | 574 → 607 |
| street:turn | 0 → 0 | 213 → 202 | 1359 → 1338 |
| category:post_bluff_response | 0 → 0 | 0 → 0 | 12445 → 13143 |
| profile:balanced | 0 → 0 | 859 → 913 | 9953 → 10769 |
| profile:candidate_g0_0005_7e36a0b114c9dcaf__20261024_r3b0 | 0 → 0 | 4917 → 5025 | 10897 → 11047 |
| profile:loose_aggressive | 0 → 0 | 2431 → 2990 | 9174 → 10680 |
| profile:loose_passive | 0 → 0 | 297 → 302 | 8052 → 8209 |
| category:value_response | 0 → 0 | 228 → 529 | 1254 → 1373 |
| profile:candidate_g0_0004_65dfe5e8e29beba9__20261024_r3b0 | 0 → 0 | 3070 → 3296 | 9959 → 10780 |
| profile:candidate_g1_mut_0002_e856eeb3b2a832ed__20261024_r3b0 | 0 → 0 | 3091 → 2967 | 11178 → 10671 |
| profile:candidate_g1_mut_0004_23c4aa0775d54bec__20261024_r3b0 | 0 → 0 | 4353 → 4774 | 9410 → 10220 |
| profile:candidate_g0_0009_292e08a42fe29566__20261024_r3b0 | 0 → 0 | 3295 → 3336 | 11605 → 11778 |
| profile:candidate_g0_0001_e944f5fff577f272__20261024_r3b0 | 0 → 0 | 2818 → 2898 | 9919 → 10062 |
| profile:candidate_g1_mut_0001_7420b8a13d172e7f__20261024_r3b0 | 0 → 0 | 2449 → 2619 | 9771 → 10559 |
| profile:candidate_g1_mut_0003_a92c427e3ea36b4a__20261024_r3b0 | 0 → 0 | 3231 → 3117 | 10419 → 10077 |
| profile:candidate_g0_0008_28cda20c09a12235__20261024_r3b0 | 0 → 0 | 3234 → 3339 | 9988 → 10059 |
| profile:candidate_g0_0002_ca41c8c26ecf41cf__20261024_r3b0 | 0 → 0 | 2018 → 2173 | 10111 → 10921 |

### Reproduction and evidence boundaries

The bank and rich collector are tracked test support. Their fixtures generate
all required inputs; no automated test reads the local historical reports.
The runner refuses existing output paths. For example:

```bash
godot --headless --path . --script tests/manual/strategy_aggression_benchmark.gd -- \
  --mode bank --seed-start 151001 --samples 32 \
  --output res://localtmp/bfcr-aggression/new-bank.json
godot --headless --path . --script tests/manual/strategy_aggression_benchmark.gd -- \
  --mode tournaments --seed-start 201001 \
  --output res://localtmp/bfcr-aggression/new-calibration.json
```

For recorded v2/candidate reports, the new comparison tool consumes matching
bank and tournament evidence:

```bash
python3 tools/compare_strategy_aggression.py \
  --baseline-bank BASELINE_BANK.json --candidate-bank CANDIDATE_BANK.json \
  --baseline-tournaments BASELINE_TOURNAMENTS.json \
  --candidate-tournaments CANDIDATE_TOURNAMENTS.json \
  --output localtmp/bfcr-aggression/new-comparison.json
```

Retain source-compatible baseline snapshots when repeating old/new comparisons;
current code alone cannot regenerate an older policy. Seed starts 201001/
151001 are calibration and 301001/351001 are held-out confirmation in this
execution. Future tuning must reserve new confirmation seeds. Positive chain
histograms count consecutive Raises (including preflop raises, excluding
postflop opening Bets); Call/Check/Fold and street changes end a chain. The
street-tail denominator includes only streets with at least one decision;
all-in runouts without an actor are excluded.

Profiles still use `tight_vs_loose`, `passive_vs_aggressive`, `call_vs_raise`
and `bluff_rate`; no additional controls or tilt behavior were implemented.
The estimator uses draw potential and a contestable call price, but does not
compute exact opponent-range equity or compare fold/call/raise expected values.
Backdoor opportunity selection follows a bounded heuristic, consistent with
[the distinction between value and bluff check-raises](https://www.pokerstars.com/poker/learn/lesson/the-check-raise-2/),
not an optimal-strategy or real-equity assertion.

## Candidate 1 result and refinement

The first candidate passed all checks except the calibration long-chain target:
1,685 to 873 chains is a 48.19% reduction, below the pre-registered 50% minimum.
The previously independent cohort had 1,598 to 788 (50.69%). Both cohorts
eliminated repeated own weak bluffs and reduced cheap nonweak fold rates to
42/801 (5.24%) and 20/738 (2.71%). No invalid actions, incomplete tournaments
or chip drift occurred. This candidate is not accepted; its reports remain
under `localtmp/bfcr/candidate-*.json` and `comparison-*.json`.

The refined eligibility rule also rejects a first-action weak bluff after two
prior voluntary wager increases on this street. It represents resistance by
other seats and closes the multiway gap where three different weak hands each
raised once. Ordinary call/fold evaluation follows; strong value raising is
unaffected. Denial uses reason `prior_aggression_limit` before consuming RNG.
The four parameters, calling margins and 50% acceptance criterion are unchanged.
Candidate source hashes distinguish this refinement from candidate 1.

Because the first confirmation cohort has been inspected, final confirmation
uses fresh seeds starting at 121001, with the original policy run separately
from its unchanged source in an isolated project. Calibration reuses 61001;
91001 remains recorded as development evidence. Final acceptance requires the
same criteria in calibration and the fresh confirmation cohort. Price strata
in the benchmark deliberately use the original total-pot price for consistent
labels; prospective side-pot pricing is verified in fixed legal decision tests.
Overall folds can increase as failed weak bluffs stop re-raising; the targeted
metric is cheap **nonweak** folds, not indiscriminately reducing all folds.

## Measured results for `street_response_v2`

The refined policy passes the unchanged acceptance criteria in calibration
(61001–61180) and fresh confirmation (121001–121180). The original-policy
holdout was run from revision `2cc59638911c8a55715959c59697ebf145c00eae` in an
isolated project; its source hashes match the frozen baseline. The frozen
benchmark support SHA-256 is
`6a2c2ca7be3b1a191f9dce08158b88707ab2453f73a43fa1733298bbd6ab1c9b`.
The candidate policy identity is `street_response_v2`, with source and profile
SHA-256 values retained in each report.

| Metric | Calibration: original → revised | Fresh confirmation: original → revised |
| --- | --- | --- |
| Complete tournaments | 180 → 180 | 180 → 180 |
| Decisions | 76,953 → 92,913 | 74,022 → 91,209 |
| Chains of at least three raises | 1,685 → 93 (94.48% fewer) | 1,705 → 102 (94.02% fewer) |
| Repeated weak bluffs by same seat/street | 5,862 → 0 | 6,641 → 0 |
| Cheap nonweak folds/opportunities | 148/1,378 → 31/669 | 154/1,398 → 26/626 |
| Cheap nonweak fold rate | 10.74% → 4.63% | 11.02% → 4.15% |
| Revised fold Wilson 95% interval | 3.28–6.50% | 2.85–6.02% |
| Invalid actions/chip drift/incomplete tournaments | 0 → 0 | 0 → 0 |
| Runtime, seconds | 15.96 → 22.71 | 14.85 → 22.42 |

The exact controlled value sequence is Raise to 20 → opponent Raise to 30 →
Call; the weak-hand control folds. These legal fixtures and paired expensive
call/missed-draw tests guard against solving the problem by calling every hand.
Runtime is about 1.42–1.51 times baseline, within the pre-registered 3x bound.
Overall post-aggression folds rise as repeated weak bluffs stop raising;
this is consistent with the intended distinction between weak bluffs and
reasonably priced nonweak calls. Observed response populations change with
policy, so the opportunity intervals are descriptive and actions within a
tournament are correlated.

### All-profile outcome review

Each profile has 136 appearances across the final two cohorts. The table
combines calibration and fresh confirmation. F/C/R are responses after that
seat's earlier aggression, not all actions. Different reached states mean
these counts and wins do not establish a stronger or optimal strategy.

| Profile | Tournament wins: original → revised | Response F/C/R: original → revised |
| --- | --- | --- |
| Nit Caller | 1 → 1 | 77/16/2 → 62/2/0 |
| Tight Aggressive | 15 → 15 | 245/108/113 → 195/58/15 |
| Loose Passive | 21 → 18 | 127/73/1 → 93/28/0 |
| Loose Cannon | 56 → 56 | 450/219/560 → 454/304/29 |
| Balanced | 2 → 2 | 383/91/69 → 307/47/4 |
| Phantom Blaze | 30 → 26 | 598/5/2485 → 1943/7/5 |
| Phantom-Copper Inferno | 53 → 46 | 536/80/3392 → 2025/75/12 |
| Crimson Surge | 17 → 19 | 1092/105/1180 → 1274/86/35 |
| Copper-Blaze Surge | 16 → 29 | 1101/162/934 → 1128/118/16 |
| Copper Counter | 19 → 16 | 1024/74/887 → 1127/90/45 |
| Scarlet Charge | 27 → 22 | 972/91/1058 → 1196/73/32 |
| Copper-Blaze Drift | 16 → 25 | 986/105/703 → 978/88/2 |
| Copper-Blaze Counter | 30 → 23 | 1019/77/1143 → 1242/51/19 |
| Wild Mirage | 25 → 29 | 872/111/985 → 1117/125/9 |
| River Velvet | 32 → 33 | 746/39/331 → 708/49/0 |

Expensive response strata remain too small for broad conclusions: calibration
original F/C/R=3/1/2 of 6 versus revised 15/3/0 of 18; fresh confirmation
5/2/1 of 8 versus 14/5/0 of 19. Fixed decision tests, rather than these changing
populations, protect the expensive-call boundary. Published profiles and all
historical promotion artifacts remain unchanged; new rankings need their own
independent confirmation workflow.

### Reproducing the current benchmark

These commands generate new evidence; they do not read existing local captures.
Choose new output paths for every run (the runner refuses overwrites):

```bash
godot --headless --path . --script tests/manual/bot_raise_response_benchmark.gd -- \
  --output res://localtmp/bfcr/new-calibration.json --seed-start 61001
godot --headless --path . --script tests/manual/bot_raise_response_benchmark.gd -- \
  --output res://localtmp/bfcr/new-confirmation.json --seed-start 121001
```

Baseline reproduction requires the recorded original production source and the
same frozen benchmark support script. Its manual runner must label the policy
`legacy_shared_gate` without referencing the later model's version constant
or extra source files. Current regular tests generate fixtures independently;
they never require the historical reports. For two compatible complete cohorts:

```bash
python3 tools/compare_bot_raise_response.py BASELINE.json CANDIDATE.json \
  --output localtmp/bfcr/new-comparison.json
```

Final local artifacts are `candidate-calibration-refined.json`,
`baseline-confirmation-fresh.json`, `candidate-confirmation-fresh.json`,
`comparison-calibration-refined.json` and `comparison-confirmation-fresh.json`
under `localtmp/bfcr/`. Full report hashes are in the comparison artifacts.
