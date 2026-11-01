# Simulation-selected strategic bot roster expansion

Status: BRE-00–11 verified. The user-approved revised twenty-profile roster
is published and active as `curated_v3`: Amber Horizon replaces Copper-Blaze
Venture. The catalog has 25 strategic profiles and three optional legacy
profiles. BRE-11 final verification is complete under the current scoped-test
instructions in `AGENTS.md`.
Created: 2026-11-01. Owner: this backlog, indexed by [docs/README](../README.md).

## Outcome and boundaries

Evaluate exactly 30 contenders: the 10 currently published strategic profiles
and 20 new profiles. Round 1 rejects five; round 2 rejects another five. The
final game roster must contain the 20 surviving published strategic profiles
plus the five hand-authored strategic profiles. Retain the three optional
legacy profiles: 25 strategic profiles and 28 catalog entries overall.

Existing publications have no automatic entitlement to survive. Preserve their
immutable resources and provenance even when removing them from active play.
Unchanged survivors retain their public names. Freeze all 30 parameter vectors
before round 1; mutation between rounds would create additional candidates.
Count original candidate identities, not publication-version aliases, once.
Historical candidates outside this campaign do not count toward the 30.

Use the current `street_response_v3` policy and freeze executable provenance
for the campaign. Do not reuse pre-policy performance scores. No game-rule,
GUI, interactive CLI, or strategic-capacity changes are planned.

References: [product specification](../ProjectDescription.md),
[architecture](../ARCHITECTURE.md), [simulation contract](../Simulation_And_Evolutionary_Bot_Strategy.md),
[experiment preparation](../../devdocs/how-to/preparing-bot-experiments.md), and
[publication workflow](../../devdocs/how-to/replacing-in-game-bot-profiles.md).

## Fairness contract

Here, a participant is an immutable bot profile, including profiles sharing a
decision model. Apply identical scheduling rules to every model family.
Each elimination round includes every remaining contender and all five
hand-authored strategic profiles: 35 participants in round 1 and 30 in round
2. The five hand-authored profiles are protected, non-eliminating controls:
they receive the same exposure as contenders, never enter the elimination
ranking, and remain in the final game roster regardless of simulation results.
Legacy-model bots are excluded from every campaign table, including pilots,
baselines and confirmation; their three optional game profiles remain available
outside this campaign.

Every simulated tournament in this campaign must **start with nine distinct
players**, including pilots, elimination rounds, additional seed blocks,
confirmation and before/after roster baselines. Normal elimination within a
tournament still reduces the table until one winner remains; reaching two
players naturally is allowed. Never initialize a heads-up or six-player match.

For each round, require:

- Exactly equal completed tournament appearances for every participant.
- Equal observations in each of the nine starting seats for every profile.
- Exactly one competitive manifest per elimination round: two competitive
  manifests total. Round one has 35 participants and 35 matchups; round two
  has 30 participants and 30 matchups. Each matchup starts nine distinct bots.
- Every participant meets every other participant at least once. Validate the
  complete unordered opponent-pair matrix, not just total appearances.
- Use cyclic shifts for both rounds. For 35 participants, use the user's
  seed `0, 1, 4, 6, 11, 17, 23, 31, 32`; table t adds t modulo 35.
  Every pair meets in one, two or three matchups, so the maximum-minus-minimum
  difference is two. For 30 participants, validate a distinct nine-index seed
  modulo 30; the implemented generic method achieves two or three meetings.
  The permitted maximum-minus-minimum spread is TWO in both rounds; a smaller
  achieved spread does not make one a required limit. Audit matchup counts separately from repeated tournament counts.
- Identical 100bb starting stacks, blinds 5/10, normal blind progression,
  scoring and sample budgets; no model-specific or incumbent exemption.
- Frozen schedules and seeds before results, disjoint effective seeds across
  rounds and confirmation, and no seed selection based on favorable outcomes.
- Independent validation of both planned schedules and completed raw reports.
  Missing/duplicate tournaments, shards, participants, seats or opponent pairs
  block ranking. Failures are resumed, never silently omitted.

Build N nine-player matchups by cyclically translating a validated seed of
nine distinct indices modulo N. Every participant appears in nine matchups.
The user's 35-player seed covers all 595 pairs: 35 pairs once, 455 twice and
105 three times. This supersedes the prior variance-one requirement. The
30-player method uses the same shift operation with a separately validated
seed; do not reuse the 35-player indices unchanged modulo 30. A generic
30-player construction is tested in advance, without selecting actual survivors.
Independently audit equal participation, starting-seat coverage, pair coverage
and the permitted matchup-frequency range. Earlier schedules with a larger
opponent-frequency range remain superseded and must not run.

Only the generic round-two scheduling method may be tested in advance. The
actual round-two manifest must be generated after round one's complete,
validated results determine the 25 survivors. Add the five protected bots,
shuffle all 30 participants using the recorded round-two seed and a dedicated
ordering stream, then produce the 30-participant/30-matchup manifest and request
approval of that exact file before running round two. Test fixtures are not actual round-two
competition manifests.

The user reduced budgets to approximately one third: 297 tournaments per
scheduled table in round 1 and 594 in round 2, both complete nine-seat rotations. With N translated tables,
total tournaments are N * repetitions and appearances per profile are
9 * repetitions: 10,395 tournaments / 2,673 appearances per profile in round
1 and 17,820 / 5,346 in round 2. Confirmation adds 11,880 tournaments, for
40,095 total before optional extensions. Values round down to complete
nine-seat rotations from the one-third targets of 300/600/300. BRE-03 runs a strategic-only nine-player
throughput pilot, excluded from selection evidence, then confirms counts,
resource limits and bounded extensions before competitive runs. Report
measured runtime/disk estimates.

## Selection, confirmation, and names

**Authorized amendment, 2026-11-01:** after reviewing both rounds and the
confirmation findings, the user explicitly approved publication of the revised
20-profile selection. Amber Horizon replaces Copper-Blaze Venture because of
Venture's low win rate; all other selections and names are retained. The
separate `campaign_human_selection_publication_v1` policy records this decision
and exact frozen profiles. The original ranking and strict confirmation
results remain unchanged. This explicit amendment supersedes the automatic
cut and mandatory strict-performance eligibility requirements below for this
campaign's final publication only. It authorizes no additional simulations.


Rank only the 30/25 contenders, using fresh evidence from their current round.
Compute the existing six-component composite and finite-sample penalty from
the single nine-player regime. No heads-up/mixed weighting is needed. Record component scores, uncertainty,
seat/opponent exposure, measured VPIP/PFR/action splits and failure counts.
Round-2 ranking uses round-2 evidence, not pooled historical rankings.

Define a deterministic cutoff rule and a bounded full-round extension rule
before execution. An uncertain cutoff can recommend equal additional exposure
for all participants, never extra samples for only selected contenders. No
extension may run without explicit approval of its revised manifest and
budget; a recommendation alone does not authorize additional games.
Use stable candidate ID for a remaining numerical tie and explicitly report
unresolved uncertainty. A rank is not proof of statistical superiority.
Invalid/ineligible contenders rank below valid contenders with explicit
reasons; if fewer than 25/20 valid contenders remain, stop rather than force
the requested count. Automated elimination is distinct from human promotion.

Independent confirmation remains mandatory for all 20 finalists, including
incumbents. The implemented `promotion_evidence_v1` requires heads-up mirrored
evidence, so it cannot satisfy this campaign. BRE-03A must implement and test
an explicit, versioned nine-player confirmation policy before execution; do
not relabel nine-player reports as mirrored evidence or bypass validation.
Keep the existing policy available for other workflows and historical records.

Use one common, predeclared cohort of eight distinct benchmark profiles,
disjoint from the 30 contenders and comprising the five hand-authored strategic profiles and three
historical champions with valid lineage. All eight use the strategic model. Each confirmation tournament contains exactly
one finalist and those eight benchmarks. Resolve benchmark feasibility before
expensive runs; do not invent champion history, duplicate profiles to fill
seats, compare a candidate against itself, or select easier benchmarks after
results. Every finalist plays the same complete nine-seat rotations in two
independent confirmation batches, with disjoint seeds from each other and all
selection evidence. Each batch requires at least 297 tournaments per finalist
and 33 observations in every starting seat, zero invalid-action fallbacks,
and a positive lower normal-95 bound on paired composite advantage against
every benchmark. Retain genetic diversity and measured-behavior review checks.
This is a separately identified policy, not a claim of equivalence to heads-up
confirmation. The policy identifier must survive confirmation, review and
publication provenance, and unsupported policies must fail closed.

Confirmation is a separate publication gate, not a third elimination round.
Finalists receive equal budgets; benchmark appearances there need not equal
finalist appearances. Both elimination rounds satisfy the full fairness
contract above. Baseline exports must also explicitly use nine-player starts;
validate actual manifests rather than trusting exporter defaults.

Twenty finalists are a target, not a guarantee that all pass confirmation.
If any fail, preserve evidence and stop without activating a partial roster,
silently replacing finalists, adding candidate 31, or weakening gates.

Continue evocative display names such as River Velvet and Phantom Blaze, and
ancestry-inspired compounds such as Copper-Blaze Drift for descendants.
Automatically propose unique names with lineage/style explanations, retain
incumbent names, and keep the ID/name/parent/genes mapping in the review pack.
Names never replace immutable IDs or affect behavior. Final names can be
edited in the single promotion review.

## Tasks and acceptance criteria

Task status is recorded below. Complete in dependency order and record evidence
before checking a task. New tooling requires focused failure-path tests and
the existing relevant tests before and after any refactoring.

- [x] **BRE-00 — Preflight and immutable inputs.** Audit current membership,
  exact source/provenance, available incumbent lineage and historical champion
  evidence. Run existing evolution tests. Export the current roster and
  establish valid, disjoint confirmation benchmarks. Report incompatible or
  missing historical evidence explicitly; never rewrite it as fresh evidence.
  Acceptance: machine-validated 10 + 5 + 3 inventory and feasible confirmation
  inputs with eight distinct disjoint strategic benchmarks, or a precise blocker before
  expensive execution.
- [x] **BRE-01 — Campaign contract and ledger.** Implement versioned frozen
  configuration, candidate identity/alias mapping, seed allocation, statuses,
  checksums, scoring and cutoff/extension rules. Preserve original lineage
  across generations. Separate eliminated, finalist, confirmation-eligible,
  reviewed, published and active states. Controls must remain separate from
  contenders; validation must reject any attempt to mark a hand-authored
  control as rejected or to add it to either elimination ranking. Acceptance: duplicates, changed genes,
  overlapping seeds and incompatible provenance fail; exactly 30 unique
  contenders can be accounted for throughout the campaign.
- [x] **BRE-02 — Generate candidates and names.** Create 10 broadly sampled
  profiles and 10 recorded descendants of incumbents, using existing evolution
  operations where possible. Add explicit provenance-preserving support if
  their selection/parent contracts cannot represent this input. Validate
  genetic uniqueness and broad parameter coverage before simulations; do not
  fabricate selection artifacts. Freeze the 20 new candidates and incumbent
  snapshots, plus proposed display names. Acceptance: reconstructible lineage,
  30 distinct contender parameter vectors, unique names and immutable inputs.
- [x] **BRE-03 — Fair schedule generator and validator.** Implement complete
  nine-player schedules described above. Validate 35- and
  30-participant cases, deterministic output, seat balance and full pair
  coverage; test missing pairs, duplicate profiles and incomplete rotations.
  Reject any campaign tournament starting with a count other than nine.
  Pilot throughput, choose and freeze repetitions, bounded extensions
  and resource limits, then emit counts and estimated duration/disk use.
  Acceptance: fairness certificate for every regime and round configuration.
  The current implementation uses the user's exact 35-player seed and verifies
  opponent-pair matchup counts of one to three. The generic 30-player method
  achieves two to three meetings. The actual round-two manifest waits for the
  first cut; neither round may run without explicit manifest approval.
- [x] **BRE-03A — Nine-player confirmation policy.** Specify and implement the
  versioned policy above in preparation, confirmation, review and publication
  consumers. Preserve existing policy behavior; document the new contract in
  the simulation specification and developer guides when implemented. Test
  exact nine-player tables, two independent batches, seat/sample thresholds,
  every benchmark comparison, diversity, provenance, unsupported policy IDs
  and rejection of reused seeds or incomplete evidence. Acceptance: valid
  nine-player evidence can reach review/publication without heads-up matches;
  malformed evidence cannot. Complete before BRE-06; the two competitive
  manifest approvals and consolidated promotion review remain required.
- [x] **BRE-04 — Automated runner and recovery.** Add a campaign coordinator
  around existing CLI validation, sharding, checkpoint/resume and inspection.
  Bound concurrent processes; emit progress, stage status and remaining-work
  estimates. Run consumers only after producers succeed and verify readiness
  markers/output checksums. Acceptance: interrupted/resumed runs match complete
  runs; failed/missing output and mixed executable provenance block advancement.
- [x] **BRE-05 — Fair comparison and automatic elimination.** Extend comparison
  with an explicit campaign contract; current `prepare-experiment` only covers
  candidate-versus-benchmark evaluation and cannot establish this round robin.
  Preserve the existing experiment workflow. Reuse strict raw-report fitness
  validation; implement the single-regime score, independent exposure audit,
  cutoff handling and exactly-five elimination artifacts. Do not misuse
  `select`'s 10–20% elite fraction for 30-to-25 or 25-to-20 selection.
  Acceptance: fixture-based ranking, fairness failures, ties, extensions and
  insufficient eligible candidates tested from a fresh checkout.
- [x] **BRE-06 — Execute round 1.** Run all 35 participants, validate completed
  exposure, rank 30 contenders and automatically record five eliminations.
  Before execution, show the user the complete round-one manifest, checksum,
  matchup list, participation/seat counts, opponent matrix and tournament
  budget. Wait for explicit approval of that exact manifest.
  Acceptance: approved manifest, 25 survivors, five explicit reasons/evidence
  links, and zero missing coverage.
- [x] **BRE-07 — Execute round 2.** Run the frozen 25 survivors plus five protected
  controls on fresh seeds with larger budgets. Prepare and show the complete
  round-two manifest and fairness report after the first cut, then wait for
  explicit approval of that exact manifest before running. Audit completed
  fairness and record the next five eliminations. Acceptance: 20 finalists, 10 distinct rejected
  contenders total, and complete accounting of every initial contender.
- [x] **BRE-08 — Independent confirmation and review pack.** Automatically run
  two independent nine-player confirmation batches for every finalist and
  validate the BRE-03A policy. Prepare one pending consolidated review, including all
  candidate-pair genetic and measured behavior comparisons, names, both cuts,
  and the exact proposed active roster. Acceptance: all 20 eligible or an
  explicit unmet gate; no automatic human approval or partial activation.
- [x] **BRE-09 — One human promotion review.** The independent human reviewer
  inspects the pack and records the 20 approve/reject decisions in one review
  file (names/notes optional). The authorized amendment records the user's
  explicit revised selection and policy approval in a separate checksummed
  human-selection review bound to the original campaign and round results.
  Acceptance: all required decisions explicit and valid under the identified
  policy; no invented strict confirmation eligibility or human decisions.
- [x] **BRE-10 — Publish and activate the winners in the game.** Following
  approved review, publish new/versioned resources with provenance through
  the policy-specific publisher. The strict `publish-profile` path retains its
  existing confirmation requirements. Retain unchanged incumbent resources with linked fresh campaign
  evidence. Set `PlayableBotRoster.DEFAULT_PROFILE_PATHS` to exactly the 20
  approved survivors plus the five hand-authored strategic and three legacy
  profiles. Remove unsuccessful incumbents from active membership, preserving
  historical files. Increment `ROSTER_VERSION` once. Acceptance: the actual
  GUI/CLI catalog contains 25 strategic profiles and 28 total entries, with
  exact approved identities and display names; no merely published-but-unused
  winners and no rejected contenders in active selection.
- [x] **BRE-11 — Verify and document completion.** Test membership, provenance,
  unique names, cap enforcement, deterministic selection, family exhaustion,
  deep-copy isolation and GUI/CLI composition. Check long-name rendering using
  existing fixtures. Export a new baseline; run evolution tests, changed-code
  checks and documentation validation under the current `AGENTS.md` test scope.
  Run GUI/CLI suites only when their production layers change. Update current README/docs/devdocs guidance and
  preserve reproducible configuration, lineage, final ledger, reviews and
  required publication evidence in a tracked campaign evidence location.
  Verify that all campaign manifests started nine-player tournaments.
  Session logs/large transient outputs belong in `localtmp/`; tests generate
  their own temporary data and keep reusable fixtures in `tests/fixtures/`.
  Acceptance: passing full checks, evidence-backed task status and a final
  report listing all 30 outcomes, the active 20, names and roster version.

## Human action and automation boundaries

The normal execution path has **three human approval/review checkpoints**:
round-one manifest approval before BRE-06, round-two manifest approval before
BRE-07, and the consolidated promotion review at BRE-09. Manifest approval
binds the exact checksum, matchup schedule and tournament budget; changed
inputs require new approval. A continuation instruction is not approval of a
manifest the user has not yet reviewed. The
[existing publication workflow](../../devdocs/how-to/replacing-in-game-bot-profiles.md#step-3-conduct-one-consolidated-human-promotion-review)
requires explicit independent human approve/reject decisions; the execution
agent must not fill those decisions itself. Present one combined review pack,
not 20 separate interruptions. Review includes names and game roster activation
so publication/integration can proceed after approval without a second prompt.

Implementation was resumed on 2026-11-01. The user explicitly requires seeing
and approving each competitive manifest before its round runs. No additional
routine prompts are planned for candidate naming proposals, tests or resuming
an interrupted run of the same approved manifest. The user has resolved the
fairness rule: fixed 35/30 matchup counts, equal participation and cyclic shifts
with the user-provided 35-player seed (pair-count spread two).
Manual GUI play is optional supplemental feedback, not a new completion gate.
Committing, pushing and deployment are outside this task unless requested.

Human intervention is exceptional if valid lineage/benchmarks are unavailable,
the frozen compute budget is exhausted, fewer than 20 pass the required gates,
or review rejects a finalist. Automatically retry recoverable interruptions
within the budget; otherwise provide the exact evidence and options requiring
a scope/budget/policy decision. Never silently relax fairness, promotion gates
or the 30/10/20 accounting to avoid asking about a real blocker.

## Execution evidence

These entries preserve the chronological history, including superseded inputs.
Paths marked **local-only** identify session files excluded from Git; they are
historical references, not portable evidence links. The tracked
[campaign record](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/README.md)
contains the final frozen campaign, both original round comparisons, human
selection, publication provenance and verification. Use those records from a
fresh checkout; reproducing documentation checks requires no session files.

### BRE-00 — verified 2026-11-01

The existing evolution suite passes 114 tests. The Godot 4.7.2 simulation CLI
exported and validated a nine-player baseline. All ten incumbent parameter
snapshots match original lineage; the catalog contains exactly 10 published,
five hand-authored strategic and three legacy profiles. See the
preflight inventory (local-only `artifacts/bot_roster_expansion_20261101/preflight/README.md`).

Eight disjoint confirmation benchmarks are frozen there, including one
actually selected Milestone 5 smoke champion. Its small historical sample is
not evidence of current strength. Both historical registries lack fields now
required by strict evaluation validation; BRE-01 must provide a versioned
archival importer before any preparation or simulation. Preserve original
artifacts and the absence of historical publication sidecars; use fresh
campaign evidence for all ranking and confirmation.

### BRE-01 — verified 2026-11-01

`tools/roster-campaign prepare` and `validate` create and verify an immutable
campaign ledger using the existing artifact/no-clobber infrastructure.
Prepared inputs (local-only `artifacts/bot_roster_expansion_20261101/prepared/campaign.json`)
bind the actual incumbent ancestry, aliases, fixed benchmark snapshots, seed
reservations and cutoff/resource configuration. Later campaign stages fail
closed until their evidence validators are implemented.

`historical_lineage_v1` embeds original artifacts and reconstructs the old
registry, parent/gene records and actual elite selections. Old evaluations
remain archival-only with unavailable execution provenance; the strict current
lineage validator is unchanged. Six importer tests and twelve campaign tests
pass, including missing/altered history, forged selection, duplicate identities,
changed incumbent genes/origin, stage tampering, mismatched shared benchmarks
and seed allocation errors. The full evolution suite passed 131 tests before
the last additional shared-benchmark test; the final focused twelve pass.

### BRE-02 — verified 2026-11-01

The original, superseded 30-contender ledger (local-only `artifacts/bot_roster_expansion_20261101/candidates/campaign.json`)
preserves all ten incumbents and adds ten broadly initialized profiles and ten
incumbent descendants. `tools/roster-campaign generate-candidates` reuses
`initialize_generation`; an explicit `campaign_mutation_v1` binds each archival
parent, seeded delta, bounds and resulting genes without fabricating an old
selection artifact. All creation attempts and name/parent/parameter labels are
retained in the generation artifact (local-only `artifacts/bot_roster_expansion_20261101/candidates/candidate_generation.json`).

All 30 contender vectors and names are unique; new vectors meet the L1 >=10
strategic-benchmark gate and the initialized set covers both low and high
values of each gene. Deterministic replay rejects edited genes, names, ancestry
or creation bindings. Seven focused generation tests pass; the complete
existing-plus-new evolution suite passes after integration. No competitive
simulations have run.

### Strategic-only correction — 2026-11-01

Before any campaign simulation ran, the user excluded legacy models and
confirmed that the five hand-authored strategic bots must never be eliminated.
The corrected inventory (local-only `artifacts/bot_roster_expansion_20261101/strategic_preflight/README.md`),
prepared ledger (local-only `artifacts/bot_roster_expansion_20261101/strategic_prepared/campaign.json`)
and frozen contenders (local-only `artifacts/bot_roster_expansion_20261101/strategic_candidates/campaign.json`)
supersede the earlier unrun inputs. The earlier full-catalog export is an
inventory snapshot, not a runnable campaign baseline. Tests and execution must
use the corrected strategic-only inputs. There are still exactly 30 contenders
for 20 published slots; the five protected controls remain additional.

### BRE-03 — verified 2026-11-01 (original budget, superseded below)

The scheduler ports the existing roster exporter's difference-cover/cyclic
translation algorithm to SplitMix64 without changing the product roster cap or
Godot runner. Its independently audited round-one manifest (local-only `artifacts/bot_roster_expansion_20261101/round1/manifest.json`)
and fairness certificate (local-only `artifacts/bot_roster_expansion_20261101/round1/fairness.json`)
give all 35 strategic profiles exactly 8,100 appearances and 900 in each
starting seat. All 595 opponent pairs occur, with 900–4,500 shared tournaments
per pair. The round-two 30-participant construction is fixture-verified with
54,000 tournaments, 16,200 appearances/profile and 1,800/profile/seat; actual
round-two membership must come from the verified first cut.

Eleven focused schedule tests pass, including missing pair coverage, unequal
seats, missing/duplicate participants and tables, illegal starting counts,
legacy exclusion and seed overflow. The actual 36-tournament nine-player pilot
completed with winner termination throughout; its measured
throughput and provenance (local-only `artifacts/bot_roster_expansion_20261101/round1/pilot_metrics.json`)
are separate from selection evidence. It took 10.98 seconds (~3.28 tournaments/s)
and wrote ~11 KB/report tournament. Serial estimates are 2.67 hours for round
one, 4.58 for round two and 3.05 for base confirmation, before optional full-round
extensions. Four workers are allowed; parallel speedup is not assumed measured.
Reports are estimated at ~347 MB and ~595 MB for the two base rounds, with
additional checkpoint disk use. Those original budgets were subsequently
reduced at the user's request; do not execute those superseded manifests. BRE-04 must report progress
and retain checkpoints instead of losing this work on interruption.

### Reduced budgets — verified 2026-11-01

The user requested one third as many tournaments before either competition
round ran. New prepared inputs (local-only `artifacts/bot_roster_expansion_20261101/reduced_prepared/campaign.json`),
frozen contenders (local-only `artifacts/bot_roster_expansion_20261101/reduced_candidates/campaign.json`)
and round-one manifest (local-only `artifacts/bot_roster_expansion_20261101/reduced_round1/manifest.json`)
replace all earlier unrun preparation. All genes and intended names are
unchanged; descendant identities bind the corrected frozen configuration.

The new fairness certificate (local-only `artifacts/bot_roster_expansion_20261101/reduced_round1/fairness.json`)
records 10,395 tournaments, 2,673 appearances/profile, 297/profile/seat and all
595 pairs covered (297–1,485 shared tournaments per pair). Round two uses
17,820 tournaments and 5,346 appearances/profile. Independent confirmation
uses two 297-tournament batches per finalist (33 observations/seat), requiring
an explicitly identified reduced-sample nine-player policy. All remaining
performance, provenance, diversity and human review checks remain required.
The measured pilot projects ~3.4 hours serially for the 40,095 base tournaments;
four workers are permitted, with actual parallel throughput still to measure.

### Matchup-count correction and approval gates — 2026-11-01

The user confirmed that matchup count follows participant count: 35 in round
one and 30 in round two. There are exactly two competitive round manifests;
matchups are rows inside each manifest, not separate manifest files. The
scheduler already emits those counts, but its prior opponent-pair frequencies
are unequal. BRE-03 is reopened because exact equal pair frequency is a new
requirement and mathematically conflicts with those counts at nine seats.
The user has been asked which requirement should take precedence. No existing
manifest is approved for competitive execution. The earlier pilot remains the
only simulation run. Existing optional publication-confirmation work has not
been executed and must not be described as extra competitive round manifests.

### Accepted matchup fairness — 2026-11-01

The user prioritizes exactly as many matchups as participants and equal games
per participant; opponent-pair matchup counts may vary by one. BRE-03 now
requires exactly 35/30 nine-player matchups, nine appearances per profile and
every unordered pair in two or three matchups. Repeated tournaments preserve
equal game counts and nine-seat exposure. Prior difference-cover schedules
with pair ranges of 1–5 are superseded; generate and independently audit a
replacement before showing the complete manifest for approval. No competitive
run is authorized by this clarification alone.

### User cyclic-shift seed — verified 2026-11-01

The user supplied `0, 1, 4, 6, 11, 17, 23, 31, 32` for 35 players,
accepting pair-matchup counts from one to three. This supersedes the earlier
variance-one target. Independent enumeration confirms all 35 matchups, exactly
nine appearances per player and all 595 pairs (35 once, 455 twice, 105 thrice).
The same cyclic-shift method is retained for 30 participants with a validated
30-player seed; no actual round-two campaign manifest has been generated.

The complete round-one review package (local-only `localtmp/bot_roster_expansion_20261101/round1_review/REVIEW.md`)
contains the CLI manifest, full 0–34 identity mapping, all 35 numeric tables,
counts and independent fairness certificate. Its manifest checksum is
`d6a3520a07a83dad456dd1a2f14656e801639f6bd95009ed3c9ed28b10588d7b`.
The existing Godot CLI validates this schema-2 manifest; no competitive run has
started. It specifies 297 tournaments per matchup, 10,395 total and 2,673
appearances/profile. Explicit user approval remains pending.

Reusable inventory and original incumbent-history fixtures are now under
`tests/fixtures/`, so tests no longer depend on ignored local campaign inputs.
The OR-Tools/search environment was session-only under `localtmp/`; it is not
a product or test dependency. The user's direct cyclic construction replaces
that exploratory search. Session review outputs remain local-only evidence.

### BRE-03A and round-two ordering — verified 2026-11-01

The explicit `nine_player_promotion_v1` policy validates two independent
297-tournament nine-player batches per candidate, 33 observations per starting
seat, paired confidence bounds, zero fallbacks, genetic diversity and exact
provenance. Original report documents are embedded and strictly re-evaluated;
old heads-up policy behavior is retained. Consolidated review version 3 and
new publication sidecars bind the policy explicitly. No promotion decision or
publication has occurred. The full evolution suite passes 174 tests in an
isolated source copy with no `artifacts/` or pre-existing `localtmp/` directory.

Round two now shuffles all 30 surviving/protected participants before numeric
assignment. Its portable ordering stream derives from the recorded round-two
schedule seed, campaign ID and `round2_profile_order_v1`; it does not consume
the base-pattern or game RNG streams. Fourteen focused scheduling tests pass,
including deterministic shuffling, input-order independence, preservation of
protected controls and cyclic table generation. The actual round-two manifest
still waits for round-one results and separate user approval.

### BRE-04 — verified 2026-11-01

`tools/roster-campaign run-round` requires explicit user approval bound to the
exact manifest checksum before launching the unchanged Godot CLI. It limits
execution to four shards, freezes inputs, validates checkpoint ownership and
provenance immediately, and preserves successful-producer receipts for safe
resume. Readiness is written only after complete report/index/seat coverage and
provenance checks. Missing output after success fails validation. SIGINT and
SIGTERM stop and reap workers; progress reads bounded existing CLI log tails
for counts, throughput and ETA.

Fifteen fake-executable runner tests and sixteen scheduler tests pass, including
missing opponents, permitted spread two for both cohort sizes, approval refusal,
worker bounds, missing/changed outputs, provenance mismatch, interruption and
resume. These tests do not play poker. No actual approval record or competitive
run has been created. Comparison/selection remains BRE-05 before execution.

### BRE-05 — verified and round one approved, 2026-11-01

`compare-round` verifies producer receipts, exact report bytes, complete shards,
provenance and actual appearances/seats/opponents before evaluating the whole
contender cohort once. It excludes protected controls, ranks eligible fitness
then original candidate ID and rejects exactly five, preserving creation
checksums, behavioral rates, uncertainty and sample counts. Seven focused
comparison tests pass, including forged results, missing/changed producer data
and protected-control handling. Extra sampling is recommendation-only and
requires renewed user approval.

The complete `make check` passes: 956 Godot tests, 343 Python tests (203 in the
evolution/campaign suite), and all 17 layout-characterization tests including
the GUI invariant gates. The initial sandboxed attempt could not bind existing
LAN test ports; the permitted full run succeeded. See session log
`localtmp/bot_roster_expansion_20261101/preflight/make_check_full.log`.

The user explicitly approved starting the displayed round-one manifest and
requested its results plus preparation of round two. Approval is recorded in
the user approval record (local-only `localtmp/bot_roster_expansion_20261101/round1_review/user_approval.json`)
for checksum `d6a3520a07a83dad456dd1a2f14656e801639f6bd95009ed3c9ed28b10588d7b`.
Round-two execution still requires separate explicit approval after review.

### BRE-06 — completed and verified 2026-11-01

All 10,395 approved tournaments completed through four existing Godot CLI
shards and passed readiness validation. The [verified comparison](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/round1_comparison.json)
confirms equal 2,673 appearances/profile, 297 observations/seat, all 595 pairs
covered and zero invalid-action fallbacks. Exactly five contenders were
rejected: Crimson Surge, Golden Veil, Silver Compass, Saffron Echo and Phantom
Blaze. The five hand-authored strategic controls remain protected; twenty-five
contenders advance. Phantom-Copper Ripple ranks first at fitness 0.402763.

The marginal intervals at the cutoff overlap. Selection follows the approved
fixed-budget fitness/ID rule; no extension was run and no additional sampling
is authorized automatically. The actual second manifest will now be generated
from this verified first-round result, with a recorded participant shuffle,
and shown for separate approval before any round-two execution.

### Actual round-two manifest — prepared 2026-11-01; subsequently approved and executed

The [round-one results](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/round1_comparison.json)
show all thirty rankings and the five rejections. The
round-two review (local-only `localtmp/bot_roster_expansion_20261101/round2_review/REVIEW.md`)
was generated only after revalidating the actual first-round comparison
`b78a5cf393456f18b976a77a238e69bc7e75b1e16961aabf67fb24ea52514b1a`.
Its complete manifest checksum is
`1f39ca6c46439b3cc547aac03964982db6a99df158b4f3340f6b9352c4084e7c`.

All thirty surviving/protected identities were shuffled using recorded seed
2026110112 and the dedicated ordering stream before cyclic modulo-30 table
construction. There are thirty nine-player matchups, each repeated 594 times:
17,820 tournaments, 5,346 appearances per profile and 594 starts/profile/seat.
All 435 pairs meet: 225 pairs share two matchups and 210 share three. The
achieved spread is one; the permitted maximum remains two. The existing Godot
simulation CLI validates the manifest. The user subsequently approved this exact
manifest; the approval record and completed execution are preserved in the
round-two review and execution directories. See BRE-07 below.

### BRE-07 — completed and verified 2026-11-01

All 17,820 approved round-two tournaments completed and passed successful
producer, shard, source-provenance and fairness checks. Each of thirty
participants received 5,346 games and 594 starts in each seat; all 435 pairs
meet and invalid-action fallbacks are zero. The five additional rejections and
all twenty finalists are recorded in the
[round-two results](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/round2_comparison.json).
Exactly ten distinct contenders have been rejected across the two rounds;
protected hand-authored bots remain outside elimination. No extension games
were run. Independent publication eligibility is recorded under BRE-08 below.

### BRE-08 — execution verified; publication blocked, 2026-11-01

All 40 independent confirmation batches completed and passed producer,
provenance, seat/sample and report-integrity validation: 297 tournaments per
batch, two batches per finalist, 11,880 tournaments total. The same eight
strategic benchmarks were used for every finalist. The full campaign completed
40,095 tournaments excluding its throughput pilot.

The [archived confirmation assessments](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/strict_confirmation_assessments.json)
summarize the original immutable evidence: one eligible finalist, Jade Undertow,
and 19 failures of `performance_not_demonstrated` under
`nine_player_promotion_v1`. Ten have a negative estimated advantage against at
least one benchmark; nine fail solely because positive estimates lack positive
lower confidence bounds. Three have a negative upper bound in at least one
comparison, including two against the same benchmark in both batches. More
sampling cannot be assumed to cure these failures.

The pending consolidated review preserves all twenty proposed names, ancestry,
parameter vectors, measured behavior, 190 pairwise comparisons and proposed
strategic membership. Both cuts remain linked. All human decisions remain
pending. No publication or roster activation occurred. BRE-08 meets its
explicit-unmet-gate acceptance condition; BRE-09–11 are blocked by the agreed
stop condition. Human approval alone cannot override the current eligibility
validator. Keeping the 20-winner target requires an explicitly authorized policy
change or revised campaign scope; neither extra games nor weakened gates have
been applied.

Verification: the complete evolution/campaign suite passes 218 tests after
confirmation orchestration and review-pack changes. The earlier full
`make check` passes 956 Godot tests, 343 Python tests and 17 layout tests;
subsequent changes affect external Python tooling and documentation only.

### Human selection and policy amendment — authorized 2026-11-01

The user explicitly selected Amber Horizon instead of Copper-Blaze Venture,
retained the other nineteen finalists, and approved using that revised
selection for official publication in place of the strict benchmark-performance
gate. There remain exactly twenty selected contenders and ten rejections.
Six incumbent resources are retained; fourteen new profiles preserve their
frozen parameters and proposed names. The five hand-authored strategic bots
remain protected and the three legacy profiles remain optional game entries.

The revised set has one strict confirmation pass, eighteen strict confirmation
failures, and Amber Horizon with no independent confirmation batches. These
facts remain attached to the publication evidence. The separate human-selection
policy must never rewrite those results as passing confirmation or change the
existing strict validators. Publication and activation require validated,
checksummed records of the exact selection and explicit user authorization.

The [revised selection](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/selection.json)
contains all twenty identities, names, parameters and original round-two ranks.
Resource previews remain local-only session files. Final
publication evidence belongs under
`resources/bot_profiles/campaigns/bot_roster_expansion_20261101/`; temporary
reports and previews remain in `localtmp/`. No additional games are needed
for the authorized policy amendment.

### BRE-09–10 — reviewed, published and activated, 2026-11-01

The [human publication review](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/human_publication_review.json)
records the user's exact twenty-profile selection and explicit replacement of
the strict performance gate under `campaign_human_selection_publication_v1`.
Its checksum is
`d902bc10752c11ea880d28eea70695c7f2069af436859fe3c88fce2cfd632c99`.
Raw round-one and round-two evidence was independently revalidated before
publication. The original comparison and confirmation results remain intact.

The [publication result](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/publication_result.json)
binds fourteen new immutable Resources, six retained incumbent Resources and
all twenty policy-specific provenance sidecars. The shared GUI/CLI roster is
`curated_v3`, containing exactly these twenty, the five protected hand-authored
strategic profiles and three optional legacy profiles: 25 strategic profiles,
28 entries total. Copper-Blaze Venture is absent; Amber Horizon is active.
Removed incumbent Resources remain historical files.

Roster, manifest and GUI/CLI composition checks pass 49 tests and 1,566
assertions; see `localtmp/roster_activation_post.log`. Full verification and
the post-activation baseline remain BRE-11 work. The
[tracked campaign record](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/README.md)
describes evidence boundaries and replay inputs.

### BRE-11 — completed and verified 2026-11-01

The [final roster](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/FINAL_ROSTER.md),
[thirty-contender ledger](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/final_outcomes.json)
and [verification record](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/verification.json)
preserve exact membership, names, lineage, all ten rejections and publication
hashes. Every published resource matches its approved snapshot; six incumbent
resources remain unchanged. The strategic-only baseline contains 25 profiles,
25 nine-player matchups and 2,250 planned tournaments. Manifest validation
passes; no additional simulations were run.

Final checks pass 424 core/simulation tests across 65 scripts with 108,613
assertions, plus 225 evolution/campaign Python tests. Explicit publication
approval, immutable writes, rollback, retained-resource consistency and exact
membership have focused coverage. All nine integration tests covering corrected
roster-size expectations pass (15,317 assertions). Earlier focused membership
and GUI/CLI composition checks passed 49 tests before the scoped-test instruction
was updated.

The initial full `make check` exposed four stale roster-dependent tests; those
expectations and export budgets were corrected. The user's updated `AGENTS.md`
then required testing changed code without rerunning unchanged GUI/CLI layers,
so the full rerun was stopped and the final scoped core/simulation suite was
used. This record does not claim the initial full run passed. Logs are under
`localtmp/bot_roster_expansion_20261101/revised_selection/`. Documentation and
tracked campaign links were checked; temporary evidence is not a test dependency.

### Documentation portability — corrected 2026-11-01

Historical session artifacts are identified as local-only paths rather than
repository links. Current evidence links target the tracked campaign record.
The documentation regression suite builds a snapshot from Git-tracked paths
using current Markdown contents, without ignored or untracked files, and checks
all current documentation links there. Missing `artifacts/` targets remain
errors; the checker has not been weakened to ignore them.

### Web release packaging — corrected 2026-11-01

Campaign evidence JSON was included by the Web preset's `all_resources`
export. Embedded local report paths then triggered the existing release-pack
check. The preset now excludes the campaign evidence directory and publication
provenance JSON while retaining every playable `.tres` profile. These evidence
files remain tracked for review. The release-content check is unchanged.

A fresh Web release export passes `make verify-web-release-output`; all 28
playable profile entries are present, with no campaign evidence, provenance
JSON or forbidden development-path strings. Five focused export/release tests
and ten LAN build tests pass. Reproduction logs and exports are local-only
under `localtmp/web-release-pack-fix/`; runtime bot behavior is unchanged.
