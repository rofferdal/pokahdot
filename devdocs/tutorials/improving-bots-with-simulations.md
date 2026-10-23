# Tutorial: Improving Bot Behavior Through Simulation and Promotion

In this tutorial, you will learn how to design a new bot profile, test its performance against existing in-game bots using the headless simulation engine, analyze statistical metrics to decide if it is ready for promotion, and replace an in-game bot profile.

---

## 1. Overview & Learning Goals

By the end of this tutorial, you will be able to:
1. Understand the 4 strategy parameters of `StrategyDecisionModel`.
2. Write a simulation manifest comparing a candidate bot against incumbent baselines.
3. Run the simulation CLI and inspect the generated report.
4. Interpret the 6-component fitness score and 95% confidence intervals.
5. Safely replace or promote a bot profile in the playable game rosters.
6. Verify your changes with automated tests.

---

## 2. The Mental Model: Bot Evolution & Roster Management

In Pokahdot, bots are parameterized agents. The algorithm (`StrategyDecisionModel`) does not change; instead, bot personalities are governed by **four integer percentage parameters (0–100)**:

| Parameter | Range | What it controls |
| :--- | :--- | :--- |
| `tight_vs_loose` | 0–100 | How loose the bot plays preflop and continues postflop (higher = plays more hands, higher VPIP). |
| `passive_vs_aggressive` | 0–100 | Propensity to open-bet when check and bet are both legal. |
| `call_vs_raise` | 0–100 | Propensity to raise instead of call when facing a bet. |
| `bluff_rate` | 0–100 | Percentage of eligible weak-hand opportunities converted into bluff bets/raises. |

Existing in-game baselines include:
- `nit_caller`: Overly tight (60), extremely passive (4/4), rarely bluffs (2). Easily pushed around.
- `tight_aggressive`: Selective hand range (65), assertive betting and raising (53/53), disciplined bluffs (8).
- `loose_passive`: Plays almost every hand (100), calls down passively (4/4), rarely bluffs (5). "Calling station".
- `loose_aggressive`: Plays every hand (100), bets and raises constantly (72/72), bluffs heavily (22). "Maniac".
- `balanced`: Well-rounded continuation (70), moderate aggression (28/28), selective bluffs (12).

---

## 3. Step 1: Formulating a Candidate Hypothesis

Suppose we observe that `nit_caller` is too easily exploited—it folds too often and never fights for pots. We want to test a **"Solid Tag"** (Tight-Aggressive) candidate:
- `tight_vs_loose`: `68` (slightly looser than nit, plays playable broadways and pairs).
- `passive_vs_aggressive`: `45` (frequently bets when checked to).
- `call_vs_raise`: `40` (defends against bets by raising strong holdings).
- `bluff_rate`: `10` (bluffs selectively when weakness is shown).

Our hypothesis: *The Solid Tag candidate will achieve a higher composite fitness score and higher chip differential than `nit_caller` when facing mixed table competition.*

---

## 4. Step 2: Creating the Simulation Manifest

Simulations are configured using a JSON manifest file conforming to schema 2.

Create a temporary manifest file named `test_candidate_manifest.json`:

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
      "uncertainty_estimator": "bootstrap_95"
    }
  ]
}
```

### Key Manifest Details:
- **`tournament_count: 300`**: Because player count is 3, cyclic seat rotation cycles each bot through seats 0, 1, and 2 exactly 100 times each. This eliminates dealer button and positional bias.
- **`seed_start: 500000`**: Sets a reproducible sequence of pseudo-random seeds ($500000$ to $500299$).

---

## 5. Step 3: Validating and Running the Simulation

### 1. Validate the Plan
Before running 300 tournaments, verify the manifest syntax and planning logic:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- validate --config test_candidate_manifest.json
```
If valid, it will output the planned execution parameters and exit with code `0`.

### 2. Run the Batch
Execute the tournaments and write the output report:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- run --config test_candidate_manifest.json --out test_report.json
```

---

## 6. Step 4: Inspecting and Interpreting the Results

Inspect the generated report summary:
```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- inspect --report test_report.json
```

You will see an aggregate table grouped by profile:

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
1. **Statistical Significance**: The difference in fitness between `candidate_solid_tag` ($0.584$) and `nit_caller` ($0.385$) is $\Delta = 0.199$. The combined uncertainty half-width is only $\sim 0.022$. The candidate's superiority over `nit_caller` is statistically conclusive.
2. **Chip Economy**: `nit_caller` bled $-216.6$ chips on average, while our candidate generated $+182.4$ chips.
3. **Behavioral Integrity**: `Invalid Actions` is 0. If a candidate ever attempts an illegal move (e.g. betting when check is not legal), it is disqualified.

Conclusion: **The candidate is a clear upgrade over `nit_caller`.**

---

## 7. Step 5: Replacing the In-Game Profile

Now that the candidate has proven itself, we can promote it into the playable game.

### 1. Save the New Profile Resource
Create a new profile resource file: `resources/bot_profiles/solid_tag.tres`:

```text
[gd_resource type="Resource" script_class="BotProfile" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/core/agents/bot_profile.gd" id="1_profile"]
[ext_resource type="Script" path="res://scripts/core/agents/strategy_decision_model_parameters.gd" id="2_parameters"]

[sub_resource type="Resource" id="StrategyParameters_solid_tag"]
script = ExtResource("2_parameters")
tight_vs_loose = 68
passive_vs_aggressive = 45
call_vs_raise = 40
bluff_rate = 10

[resource]
script = ExtResource("1_profile")
profile_id = &"solid_tag"
model_id = &"strategy_parameterized"
display_name = "Solid Tag"
parameters = SubResource("StrategyParameters_solid_tag")
```

### 2. Update the Composition Roots
Both `scripts/gui/gui_match_factory.gd` and `scripts/cli/cli_match_factory.gd` define the active bot roster.

In `scripts/gui/gui_match_factory.gd`:
```gdscript
const EXPERIMENTAL_BOT_AGENT_IDS: Array[StringName] = [
	&"solid_tag",            # Replaced nit_caller with our new profile!
	&"tight_aggressive",
	&"loose_passive",
	&"strategy_loose_aggressive",
	&"balanced",
]
```
And add `&"solid_tag"` to the factory method `_create_bot()`:
```gdscript
&"solid_tag", &"tight_aggressive", &"loose_passive", &"balanced":
	return _create_strategy_bot(agent_id, rng)
```

Apply the identical change in `scripts/cli/cli_match_factory.gd`.

---

## 8. Step 6: Verifying with Tests

Whenever you change or replace a bot profile:
1. Update `tests/unit/test_strategy_profiles.gd` to include the new profile ID and expected parameters in `expected_profiles`.
2. Run the test suite:
   ```bash
   godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_strategy_profiles.gd
   ```
3. Run the full project check:
   ```bash
   make check
   ```

Congratulations! You have successfully evaluated a bot strategy using simulations and safely promoted it into the Pokahdot tournament roster.
