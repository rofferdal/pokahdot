# How-To Guide: Replacing In-Game Bot Profiles

This guide provides the complete, authoritative procedure for updating or replacing bot profiles in Pokahdot's playable GUI and CLI tournaments using the evidence-based promotion workflow.

---

The [experiment preparation guide](preparing-bot-experiments.md) generates
common-cohort evaluation and independent per-candidate confirmation manifests,
then prepares commands for the consolidated pending review below. It does not
make reviewer decisions, publish Resources or alter roster membership.

## 1. Understanding Playable Rosters and `PlayableBotRoster`

Pokahdot manages all playable in-game bots through a centralized, source-controlled catalog class: [`PlayableBotRoster`](../../scripts/core/agents/playable_bot_roster.gd).

### Key Architectural Invariants of `PlayableBotRoster`:
1. **Centralized Composition**: Both [`GuiMatchFactory`](../../scripts/gui/gui_match_factory.gd) and [`CliMatchFactory`](../../scripts/cli/cli_match_factory.gd) delegate bot selection and creation exclusively to `PlayableBotRoster`.
2. **Deep-Copy Isolation**: The catalog loads profiles once, but `select()` and `create_bot()` return deep copies. Matches cannot mutate shared profile resources.
3. **Deterministic Positional Selection**: Given a tournament seed, seats are assigned profiles deterministically. Selection exhausts each requested model family before reusing a profile.
4. **Legacy Availability**: The default catalog retains the three hand-authored legacy archetypes (`random_default`, `tight_passive_default`, `loose_aggressive_default`). Validation requires at least one legacy profile when legacy selection is enabled, but does not enforce those three IDs individually.
5. **Roster Version Tracking**: The constant `ROSTER_VERSION` (`curated_v2`) provides source-controlled identity for the catalog. Interactive diagnostics log this version alongside every seat's assigned profile.

---

## 2. The Evidence-Based Promotion Workflow

Never edit or replace in-game bot profiles ad-hoc. All candidate promotions follow a strict, multi-stage gate:

```text
[Simulation Runs (Mirrored & Mixed Reports)]
                 │
                 ▼
[tools/profile-evolution confirm-candidate]
                 │ (Verifies sample sizes, diversity L1 >= 10, zero fallbacks)
                 ▼
 [confirmation_*.json] (Eligible, review_required)
                 │
                 ▼
[tools/profile-evolution prepare-promotion-review]
                 │ (One editable plan lists every candidate)
                 ▼
       [promotion_review_plan.json]
                 │ (Human sets one approve/reject decision per candidate)
                 ▼
[tools/profile-evolution finalize-promotion-review]
                 │ (Verifies every exact confirmation binding)
                 ▼
     [promotion_review_batch.json]
                 │
                 ▼
[tools/profile-evolution publish-profile]
                 │ (Writes no-clobber .tres to resources/bot_profiles/published/)
                 ▼
[Source Change: Update PlayableBotRoster & Increment ROSTER_VERSION]
                 │
                 ▼
[Run GUT & Python Tests: make check]
```

---

## 3. Step-by-Step Procedure

### Step 1: Snapshot the Current Roster
Before changing a profile Resource or `DEFAULT_PROFILE_PATHS`, export the
active catalog. The generator calls `get_catalog_profiles()` and deep-copies
each profile (including nested parameter Resources), so the resulting schema-2
manifest remains a trustworthy before-state even after the catalog changes.

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  export-roster-manifest --output artifacts/curated_v2_before.json \
  --batch-id curated_v2_before --seed 71001 --tournament-count 2520

godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  validate --config artifacts/curated_v2_before.json
```

Run and retain a report from this exact manifest if it will be used as a
baseline. Do not add the candidate to this artifact: create a separate,
candidate-inclusive manifest for mirrored and mixed promotion evidence.

### Step 2: Confirm Candidate Evidence
Run `confirm-candidate` to verify that your candidate meets all mathematical and behavioral promotion gates:

```bash
tools/profile-evolution confirm-candidate \
  --registry artifacts/lineage_registry.json \
  --candidate-id candidate_id \
  --legacy-id random_default \
  --legacy-id tight_passive_default \
  --legacy-id loose_aggressive_default \
  --historical-champion-id champion_id \
  --mirrored-report artifacts/mirrored_report.json \
  --mixed-report artifacts/mixed_report.json \
  --output artifacts/confirmation.json
```

The tool verifies:
- Independent mirrored and mixed reports with non-overlapping seeds.
- At least 300 tournaments per matchup and 100 candidate observations in every
  seat; caller-selected plan minimums are exploratory only.
- A strictly positive lower normal-95 bound on paired composite advantage over
  every declared benchmark in each matchup.
- Zero invalid-action fallbacks.
- Genetic diversity: L1 distance across the four strategy genes must be $\ge 10$ from every comparable declared legacy and champion profile.
- Measured behavior: confirmation records count-weighted VPIP, PFR,
  bet/raise frequency, bet frequency, and raise share for roster review.
- If successful, it writes `artifacts/confirmation.json` with `"promotion_eligible": true`.

---

### Step 3: Conduct One Consolidated Human Promotion Review

Collect every proposed candidate in one editable plan. Repeat
`--confirmation` for each candidate; do not generate a review file per
candidate.

```bash
tools/profile-evolution prepare-promotion-review \
  --confirmation artifacts/confirmation_01.json \
  --confirmation artifacts/confirmation_02.json \
  --reviewer-id reviewer_username \
  --output artifacts/promotion_review_plan.json
```

The reviewer opens `promotion_review_plan.json` and changes each candidate's
single `"decision": "pending"` value to exactly `"approve"` or `"reject"`.
The optional `display_name` and `review_note` fields may also be filled in.
Candidate snapshots, confirmation checksums, and eligibility fields must not
be edited. Review the generated `roster_diversity.pairwise_comparisons` for
every proposed-candidate pair: it keeps genetic parameter distance separate
from differences in measured VPIP, PFR, and action splits. These comparisons
inform the decision but never replace explicit human approval.

Finalize the entire plan once, supplying the same complete confirmation set:

```bash
tools/profile-evolution finalize-promotion-review \
  --plan artifacts/promotion_review_plan.json \
  --confirmation artifacts/confirmation_01.json \
  --confirmation artifacts/confirmation_02.json \
  --output artifacts/promotion_review_batch.json
```

Finalization rejects pending or invalid decisions, missing or duplicate
candidates, altered snapshots or checksums, and approval of ineligible
evidence. The output is one immutable checksummed review artifact.

---

### Step 4: Publish the Profile Resource
Use `publish-profile` to generate the new Godot `.tres` Resource:

```bash
tools/profile-evolution publish-profile \
  --confirmation artifacts/confirmation_01.json \
  --review artifacts/promotion_review_batch.json \
  --version v1 \
  --project-root .
```

This writes a versioned `.tres` file and adjacent `.provenance.json` under
`resources/bot_profiles/published/`. The sidecar binds the profile ID and exact
Resource SHA-256 to the confirmation and consolidated-review checksums.
- Repeat publication only for candidates approved in the single batch review.
- The plan's `display_name` is used by default; `--display-name` can override it.
- It uses no-clobber writes and refuses to overwrite either file.
- It does **not** modify `PlayableBotRoster`; activating the profile is a deliberate, reviewed source code change.

---

### Step 5: Update `PlayableBotRoster`

Open [`scripts/core/agents/playable_bot_roster.gd`](../../scripts/core/agents/playable_bot_roster.gd):

1. **Increment `ROSTER_VERSION`**:
   ```gdscript
   const ROSTER_VERSION: StringName = &"curated_v3"
   ```

2. **Add or Replace Profile in `DEFAULT_PROFILE_PATHS`**:
   ```gdscript
   const DEFAULT_PROFILE_PATHS: PackedStringArray = [
   	"res://resources/bot_profiles/random_default.tres",
   	"res://resources/bot_profiles/tight_passive_default.tres",
   	"res://resources/bot_profiles/loose_aggressive_default.tres",
   	"res://resources/bot_profiles/published/candidate_id__v1.tres", # Promoted profile
   	"res://resources/bot_profiles/tight_aggressive.tres",
   	"res://resources/bot_profiles/loose_passive.tres",
   	"res://resources/bot_profiles/loose_aggressive.tres",
   	"res://resources/bot_profiles/balanced.tres",
   ]
   ```

> [!IMPORTANT]
> Product validation requires at least one strategic profile: a profile whose
> registered implementation is `StrategyDecisionModel`. Every other registered
> decision model is classified as a legacy heuristic. If the user enables
> legacy models, selection also requires at least one legacy profile.
>
> `PlayableBotRoster` also allows at most 25 profiles backed by
> `StrategyDecisionModel`. When promoting another strategic profile beyond
> that capacity, replace or remove an existing strategic product profile.
> This limit does not apply to simulation manifests used for evaluation.

---

### Step 6: Update Test Suites

Update the roster unit tests in [`tests/unit/test_playable_bot_roster.gd`](../../tests/unit/test_playable_bot_roster.gd) to assert the new roster version:

```gdscript
assert_eq(roster.get_roster_version(), &"curated_v3")
```

If replacing a legacy test expectation in [`tests/unit/test_strategy_profiles.gd`](../../tests/unit/test_strategy_profiles.gd), update the parameter dictionary accordingly.

Run the test suite:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_playable_bot_roster.gd
```

After publishing the new roster version, export a second baseline and compare
the two reports; do not overwrite the original manifest. The new default batch
ID derives from the incremented `ROSTER_VERSION`, which makes the two
artifacts easy to distinguish.

### Step 7: Verify in CLI and GUI

1. **Verify via Interactive CLI**:
   Run the CLI and check the startup diagnostics:
   ```bash
   godot --headless --path . --script res://scripts/cli/cli_app.gd
   ```
   The diagnostic output prints:
   ```text
   Bot roster: production
   Bot roster version: curated_v2
   Selected bot profile IDs: candidate_id__v1,tight_aggressive,balanced,...
   Seat 1: model=strategy_parameterized profile=candidate_id__v1
   ```

2. **Verify via Graphical UI**:
   Launch the game:
   ```bash
   godot --path . scenes/main.tscn
   ```
   Start a tournament and verify smooth execution.

3. **Run Full Verification**:
   ```bash
   make check
   ```

---

## 4. Best Practice: Preserving Archetype Diversity

When improving bots, resist the temptation to make all opponents identical "optimal" clones. A compelling poker game requires **stylistic variety**:

- **The Maniac** (`loose_aggressive`): Constant aggression, high variance, tests light call-downs.
- **The Calling Station** (`loose_passive`): Rarely folds, rarely raises. Teaches value betting and punishes over-bluffing.
- **The Nit** (`nit_caller` / tight-passive): Plays few hands. Teaches blind stealing.
- **The TAG / Balanced** (`tight_aggressive` / `balanced`): Solid, aggressive poker. Teaches pot control and position.

When replacing a profile, aim to **eliminate strategic blunders** (e.g. folding when receiving 20:1 pot odds, bleeding blinds without defending, or making invalid actions) while **preserving the archetype's distinct personality**.

The [simulation contract](../../docs/Simulation_And_Evolutionary_Bot_Strategy.md#5-external-profile-evolution-tool)
owns confirmation policy: mirrored tables are heads-up against each declared
benchmark; each mixed matchup includes both opponent classes. Review labels
and checksums bind content but do not authenticate reviewer identity.
