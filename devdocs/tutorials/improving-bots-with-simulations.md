# Tutorial: Improving Bot Behavior Through Simulation and Promotion

In this tutorial, you will learn how to formulate a candidate bot hypothesis, benchmark its performance against existing in-game bots using the headless simulation engine, analyze statistical metrics to verify promotion eligibility, publish the approved profile, and integrate it into the playable game roster.

---

## 1. Overview & Learning Goals

By the end of this tutorial, you will be able to:
1. Understand the 4 strategy parameters of [`StrategyDecisionModel`](../../scripts/core/agents/strategy_decision_model.gd).
2. Export a schema-2 snapshot of the active roster, then author a separate candidate-inclusive manifest.
3. Run the simulation CLI and inspect the generated schema-4 report and executable provenance.
4. Interpret the 6-component fitness score, style metrics, and 95% confidence intervals.
5. Use the external promotion tools to verify eligibility, review approvals, and publish the `.tres` Resource.
6. Safely integrate the new profile into [`PlayableBotRoster`](../../scripts/core/agents/playable_bot_roster.gd) and verify your changes with automated tests.

---

## 2. The Mental Model: Bot Personalities & Parameters

In Pokahdot, bot decisions are cleanly separated from personality tuning. The algorithm ([`StrategyDecisionModel`](../../scripts/core/agents/strategy_decision_model.gd)) evaluates board textures, hand rank percentiles, and pot odds. Its personality is governed by **four integer percentage parameters (0–100)**:

| Parameter | Range | What it controls |
| :--- | :--- | :--- |
| `tight_vs_loose` | 0–100 | How loose the bot plays preflop and continues postflop (higher = plays more hands, higher VPIP). |
| `passive_vs_aggressive` | 0–100 | Propensity to open-bet when check and bet are both legal. |
| `call_vs_raise` | 0–100 | Propensity to raise instead of call when facing a bet. |
| `bluff_rate` | 0–100 | Percentage of eligible weak-hand opportunities converted into bluff bets/raises. |

Existing baseline profiles include:
- `nit_caller`: Overly tight (60), extremely passive (4/4), rarely bluffs (2). Easily pushed around.
- `tight_aggressive`: Selective hand range (65), assertive betting and raising (53/53), disciplined bluffs (8).
- `loose_passive`: Plays almost every hand (100), calls down passively (4/4), rarely bluffs (5). "Calling station".
- `loose_aggressive`: Plays every hand (100), bets and raises constantly (72/72), bluffs heavily (22). "Maniac".
- `balanced`: Well-rounded continuation (70), moderate aggression (28/28), selective bluffs (12).

---

## 3. Step 1: Formulating a Candidate Hypothesis

Suppose we observe that `nit_caller` is too easily exploited—it folds too often and never fights for pots. We want to evaluate a **"Solid Tag"** (Tight-Aggressive) candidate:
- `tight_vs_loose`: `68` (slightly looser than nit, plays playable broadways and pairs).
- `passive_vs_aggressive`: `45` (frequently bets when checked to).
- `call_vs_raise`: `40` (defends against bets by raising strong holdings).
- `bluff_rate`: `10` (bluffs selectively when weakness is shown).

Our hypothesis: *The Solid Tag candidate will achieve a higher composite fitness score and positive chip differential against incumbent baselines without committing invalid actions.*

---

## 4. Step 2: Creating the Simulation Manifest

When benchmarking a candidate, first snapshot the complete currently playable
field. This avoids hand-copying incumbent parameters and preserves the exact
pre-change roster for later comparison:

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  export-roster-manifest --output artifacts/curated_roster_baseline.json \
  --batch-id before_solid_tag --seed 71001 --tournament-count 2520
```

The exported manifest contains every active roster profile in a roster-sized
100bb 5/10 table, with cyclic seat rotation. Its profiles are deep copies, so
editing a `.tres` later cannot alter this baseline. Validate and run it before
making the code change, and retain both artifacts:

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  validate --config artifacts/curated_roster_baseline.json

godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  run --config artifacts/curated_roster_baseline.json \
  --output artifacts/curated_roster_baseline_report.json
```

This baseline is not, by itself, promotion evidence: it has no candidate.
Keep it unchanged. For the candidate experiment, create a new manifest that
includes the candidate and only the incumbents relevant to the hypothesis (as
in the example below), or copy the export and add the candidate while changing
the regime to the new profile count. In either case, make the tournament count
a multiple of the table size and keep cyclic rotation.

Simulations are configured using a JSON manifest file conforming to schema 2.

Create a manifest file named `solid_tag_manifest.json`:

```json
{
  "schema_version": 2,
  "batch_id": "solid_tag_experiment_01",
  "seed_start": 500000,
  "profiles": [
    {
      "profile_id": "candidate_solid_tag",
      "model_id": "strategy_parameterized",
      "parameters": {
        "tight_vs_loose": 68,
        "passive_vs_aggressive": 45,
        "call_vs_raise": 40,
        "bluff_rate": 10
      }
    },
    {
      "profile_id": "nit_caller",
      "model_id": "strategy_parameterized",
      "parameters": {
        "tight_vs_loose": 60,
        "passive_vs_aggressive": 4,
        "call_vs_raise": 4,
        "bluff_rate": 2
      }
    },
    {
      "profile_id": "balanced",
      "model_id": "strategy_parameterized",
      "parameters": {
        "tight_vs_loose": 70,
        "passive_vs_aggressive": 28,
        "call_vs_raise": 28,
        "bluff_rate": 12
      }
    }
  ],
  "regimes": [
    {
      "regime_id": "regime_3max_100bb",
      "player_count": 3,
      "starting_stack": 1000,
      "starting_small_blind": 5,
      "starting_big_blind": 10,
      "blind_progression": "normative_hand_based_v1"
    }
  ],
  "matchups": [
    {
      "matchup_id": "candidate_vs_incumbents",
      "profile_ids": ["candidate_solid_tag", "nit_caller", "balanced"]
    }
  ],
  "evaluation_plans": [
    {
      "plan_id": "eval_3max_benchmark",
      "regime_id": "regime_3max_100bb",
      "matchup_ids": ["candidate_vs_incumbents"],
      "tournament_count": 300,
      "seat_rotation": "cyclic",
      "minimum_profile_samples": 100,
      "uncertainty_estimator": "normal_95"
    }
  ]
}
```

### Key Details:
- **`tournament_count: 300`**: Cycles each bot through seats 0, 1, and 2 exactly 100 times under cyclic rotation, eliminating positional bias.
- **`seed_start: 500000`**: Provides reproducible pseudo-random streams.
- **`normal_95` only**: Both the Godot manifest/runtime path and Python
  evaluator reject `bootstrap_95`; no component silently relabels normal
  intervals as bootstrap output.
- **Separate artifacts**: `curated_roster_baseline.json` captures the whole
  product field before a change; `solid_tag_manifest.json` answers the focused
  candidate question. Do not overwrite or silently edit either after its run.

---

## 5. Step 3: Validating and Running the Simulation

### 1. Validate the Plan
Check manifest syntax and plan inputs without playing:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  validate --config solid_tag_manifest.json --format json
```

### 2. Run the Batch
Execute the tournaments and write the output report atomically:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  run --config solid_tag_manifest.json --output artifacts/solid_tag_report.json \
  --trace sampled --trace-sample 5 --format json
```

---

## 6. Step 4: Inspecting and Interpreting Results

Inspect the generated report summary:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  inspect --report artifacts/solid_tag_report.json --format text
```

You will see the aggregate metrics grouped by profile:

```text
Profile Aggregates:
Profile: candidate_solid_tag (N = 300)
  Fitness: 0.584 ± 0.021
  Win Rate: 41.3% (± 5.5%)
  Avg Finish Position: 1.81
  Chip Differential: +182.4
  bnc_per_100: +6.82
  VPIP: 24.1% | PFR: 14.8%
  Invalid Actions: 0

Profile: balanced (N = 300)
  Fitness: 0.531 ± 0.022
  Win Rate: 33.7% (± 5.3%)
  Avg Finish Position: 1.99
  Chip Differential: +34.2
  bnc_per_100: +1.15
  VPIP: 26.5% | PFR: 9.2%
  Invalid Actions: 0

Profile: nit_caller (N = 300)
  Fitness: 0.385 ± 0.023
  Win Rate: 25.0% (± 4.9%)
  Avg Finish Position: 2.20
  Chip Differential: -216.6
  bnc_per_100: -7.97
  VPIP: 12.3% | PFR: 2.1%
  Invalid Actions: 0
```

### Making the Decision:
1. **Statistical Significance**: The difference in fitness between `candidate_solid_tag` ($0.584$) and `nit_caller` ($0.385$) is $\Delta = 0.199$, far exceeding the uncertainty half-width ($0.021$).
2. **Chip Differential**: The candidate earns $+182.4$ chips on average, while `nit_caller` bleeds $-216.6$ chips.
3. **Behavioral Integrity**: `Invalid Actions` is `0`.
4. **Genetic Diversity**: Comparing genes `[68, 45, 40, 10]` to `nit_caller` `[60, 4, 4, 2]` yields an L1 distance of $|68-60| + |45-4| + |40-4| + |10-2| = 8 + 41 + 36 + 8 = 93 \ge 10$.

Conclusion: **The candidate is a statistically sound, behaviorally diverse upgrade.**

---

## 7. Step 5: Evidence-Based Promotion and Publication

Rather than editing source code directly, promotion requires verified artifact gates:

### 1. Confirm Promotion Eligibility
Run the confirmation gate against mirrored and mixed benchmark reports:
```bash
tools/profile-evolution confirm-candidate \
  --registry artifacts/lineage_registry.json \
  --candidate-id candidate_solid_tag \
  --legacy-id random_default \
  --legacy-id tight_passive_default \
  --legacy-id loose_aggressive_default \
  --historical-champion-id balanced \
  --mirrored-report artifacts/mirrored_report.json \
  --mixed-report artifacts/mixed_report.json \
  --output artifacts/confirmation.json
```

Promotion uses the fixed `promotion_evidence_v1` policy, regardless of each
plan's exploratory minimum: at least 300 tournaments per matchup, at least 100
candidate observations in every seat, and a positive lower normal-95 bound on
paired composite advantage over every declared benchmark.

### 2. Record the Consolidated Reviewer Decisions

Collect all proposed candidates in one plan (repeat `--confirmation` for each):

```bash
tools/profile-evolution prepare-promotion-review \
  --confirmation artifacts/confirmation.json \
  --reviewer-id reviewer_name \
  --output artifacts/promotion_review_plan.json
```

An independent reviewer opens that one file, changes each candidate's single
`decision` from `pending` to `approve` or `reject`, and may fill in
`display_name` and `review_note`. Before deciding, inspect the complete
`roster_diversity` pair list: gene distance and measured VPIP/PFR/action-rate
differences are separate so genetically different candidates are not assumed
to play differently. Finalize all decisions once:

```bash
tools/profile-evolution finalize-promotion-review \
  --plan artifacts/promotion_review_plan.json \
  --confirmation artifacts/confirmation.json \
  --output artifacts/promotion_review_batch.json
```

The finalizer refuses incomplete decisions or any change to the confirmation
bindings and produces one immutable review artifact for the whole set.

### 3. Publish the Profile Resource
Publish the new `.tres` file under `resources/bot_profiles/published/`:
```bash
tools/profile-evolution publish-profile \
  --confirmation artifacts/confirmation.json \
  --review artifacts/promotion_review_batch.json \
  --version v1 \
  --project-root .
```
This generates `resources/bot_profiles/published/candidate_solid_tag__v1.tres`.
It uses the review plan's display name unless `--display-name` overrides it.
It also creates `candidate_solid_tag__v1.provenance.json`, binding the exact
Resource hash to the confirmation and review checksums. Neither file may exist
before publication.

---

## 8. Step 6: Integrating into `PlayableBotRoster`

Now bring the published profile into the playable game catalog:

1. Open [`scripts/core/agents/playable_bot_roster.gd`](../../scripts/core/agents/playable_bot_roster.gd).
2. Increment `ROSTER_VERSION` (for example, from `&"curated_v2"` to `&"curated_v3"`).
3. Add the published resource path to `DEFAULT_PROFILE_PATHS`:
   ```gdscript
   const DEFAULT_PROFILE_PATHS: PackedStringArray = [
   	"res://resources/bot_profiles/random_default.tres",
   	"res://resources/bot_profiles/tight_passive_default.tres",
   	"res://resources/bot_profiles/loose_aggressive_default.tres",
   	"res://resources/bot_profiles/published/candidate_solid_tag__v1.tres",
   	"res://resources/bot_profiles/tight_aggressive.tres",
   	"res://resources/bot_profiles/loose_passive.tres",
   	"res://resources/bot_profiles/loose_aggressive.tres",
   	"res://resources/bot_profiles/balanced.tres",
   ]
   ```
4. Verify that legacy profiles (`random_default`, `tight_passive_default`, `loose_aggressive_default`) are preserved.

After this reviewed source change, export `curated_v2` (or the new roster
version) as a new baseline. Comparing its report with the retained pre-change
baseline shows the product-level effect without losing the candidate-specific
promotion evidence.

---

## 9. Step 7: Verifying with Tests and Running

1. Run the roster unit test:
   ```bash
   godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_playable_bot_roster.gd
   ```
2. Run full quality checks:
   ```bash
   make check
   ```
3. Test in the interactive CLI:
   ```bash
   godot --headless --path . --script res://scripts/cli/cli_app.gd
   ```
   Check that your promoted bot profile appears in the startup seating diagnostics!

---

## 10. Exploring the Automated Evolution Loop

Beyond testing one-off candidates manually, `tools/profile-evolution` provides a complete evolutionary workflow:
- `init-generation`: Initializes a bounded random population of strategy genes.
- `evaluate-fitness`: Ingests simulation reports and ranks candidates by composite fitness.
- `select`: Performs truncation selection with elitism.
- `crossover`: Generates offspring by mixing parent parameter genes.
- `mutate`: Applies policy-bounded mutations with recorded deltas.
- `build-lineage`: Tracks parentage, seeds, and mutations in an immutable registry.

Refer to the [Architecture Reference](../reference/architecture.md) and [Running Simulations Guide](../how-to/running-simulations.md) for full pipeline specifications.
