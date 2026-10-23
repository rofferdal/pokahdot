# How-To Guide: Replacing In-Game Bot Profiles

This guide provides the complete procedure for updating or replacing bot profiles in Pokahdot's playable GUI and CLI tournaments.

---

## 1. Understanding the Playable Rosters

Pokahdot maintains two bot roster configurations:

1. **Standard (Production) Roster**:
   - The default out-of-the-box configuration when the game starts.
   - Assigned in `scripts/core/config/tournament_config.gd` under `seat_agents`.
   - Uses basic archetypes: `random`, `tight_passive`, and `loose_aggressive`.
2. **Experimental (Strategy) Roster**:
   - Activated when **"Allow Experimental Models"** is enabled in the startup GUI or via CLI flag `--allow-experimental-models`.
   - Populated by `EXPERIMENTAL_BOT_AGENT_IDS` in `GuiMatchFactory` and `CliMatchFactory`.
   - Currently includes:
     - `nit_caller`
     - `tight_aggressive`
     - `loose_passive`
     - `strategy_loose_aggressive`
     - `balanced`

---

## 2. Step-by-Step Replacement Procedure

### Step 1: Create the New `.tres` Profile Resource

Save the verified profile as a Godot `Resource` inside `resources/bot_profiles/`. 

For example, to introduce a new profile named `disciplined_tag`:
Create `resources/bot_profiles/disciplined_tag.tres`:

```text
[gd_resource type="Resource" script_class="BotProfile" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/core/agents/bot_profile.gd" id="1_profile"]
[ext_resource type="Script" path="res://scripts/core/agents/strategy_decision_model_parameters.gd" id="2_parameters"]

[sub_resource type="Resource" id="StrategyParameters_disciplined_tag"]
script = ExtResource("2_parameters")
tight_vs_loose = 68
passive_vs_aggressive = 46
call_vs_raise = 42
bluff_rate = 9

[resource]
script = ExtResource("1_profile")
profile_id = &"disciplined_tag"
model_id = &"strategy_parameterized"
display_name = "Disciplined Tag"
parameters = SubResource("StrategyParameters_disciplined_tag")
```

> [!IMPORTANT]
> Never mutate an existing `.tres` file in place if it represents a published benchmark. Always create a new file or increment a version suffix (e.g. `balanced_v2.tres`).

---

### Step 2: Update the GUI Match Factory

Open `scripts/gui/gui_match_factory.gd`:

1. Update `EXPERIMENTAL_BOT_AGENT_IDS` (replace the old ID with your new one):
   ```gdscript
   const EXPERIMENTAL_BOT_AGENT_IDS: Array[StringName] = [
   	&"disciplined_tag",   # Replaces nit_caller
   	&"tight_aggressive",
   	&"loose_passive",
   	&"strategy_loose_aggressive",
   	&"balanced",
   ]
   ```
2. Ensure the ID is mapped in `_create_bot()`:
   ```gdscript
   &"disciplined_tag", &"tight_aggressive", &"loose_passive", &"balanced":
   	return _create_strategy_bot(agent_id, rng)
   ```

---

### Step 3: Update the CLI Match Factory

Open `scripts/cli/cli_match_factory.gd`:

1. Update `EXPERIMENTAL_BOT_AGENT_IDS`:
   ```gdscript
   const EXPERIMENTAL_BOT_AGENT_IDS: Array[StringName] = [
   	&"disciplined_tag",
   	&"tight_aggressive",
   	&"loose_passive",
   	&"strategy_loose_aggressive",
   	&"balanced",
   ]
   ```
2. Update `_create_bot()`:
   ```gdscript
   &"disciplined_tag", &"tight_aggressive", &"loose_passive", &"balanced":
   	return _create_strategy_bot(agent_id, rng)
   ```

---

### Step 4 (Optional): Update the Standard Production Roster

If you are replacing one of the standard non-experimental seats (e.g. upgrading the baseline tight bot):

1. Open `scripts/core/config/tournament_config.gd`.
2. Update the default `seat_agents` dictionary:
   ```gdscript
   @export var seat_agents: Dictionary[int, StringName] = {
   	0: &"human",
   	1: &"random",
   	2: &"disciplined_tag", # Updated seat 2
   	3: &"loose_aggressive",
   	# ...
   }
   ```
3. Update `resources/default_tournament_config.tres` if necessary.

---

### Step 5: Update Test Assertions

Update the unit tests in `tests/unit/test_strategy_profiles.gd` to reflect the new profile:

```gdscript
var expected_profiles := {
	&"disciplined_tag": [68, 46, 42, 9],
	&"tight_aggressive": [65, 53, 53, 8],
	&"loose_passive": [100, 4, 4, 5],
	&"loose_aggressive": [100, 72, 72, 22],
	&"balanced": [70, 28, 28, 12],
}
```

Run GUT to verify:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_strategy_profiles.gd
```

---

### Step 6: Verify in Game

1. **Verify via CLI**:
   Run the CLI with experimental bots enabled and observe the startup diagnostic seating output:
   ```bash
   godot --headless --path . --script res://scripts/cli/cli_app.gd -- --allow-experimental-models
   ```
   Check that Seat 1 outputs: `Seat 1: model=strategy_parameterized profile=disciplined_tag`.

2. **Verify via GUI**:
   Launch the game, check **Allow experimental models**, and start a match:
   ```bash
   godot --path . scenes/main.tscn
   ```

---

## 3. Best Practice: Preserving Archetype Diversity

When improving bots, resist the temptation to make all opponents identical "optimal" clones. A compelling poker game requires **stylistic variety**:

- **The Maniac** (`loose_aggressive`): Applies constant pressure, creates big pots, and tests the player's willingness to call down light.
- **The Calling Station** (`loose_passive`): Rarely folds, rarely raises. Teaches value betting and punishes over-bluffing.
- **The Nit** (`nit_caller` / tight-passive): Plays very few hands. Teaches blind stealing.
- **The TAG / Balanced** (`tight_aggressive` / `balanced`): Solid, aggressive poker. Teaches pot control and position.

When replacing a profile, aim to **eliminate strategic blunders** (e.g. folding when receiving 20:1 pot odds, bleeding blinds without defending, or making invalid actions) while **preserving the archetype's distinct personality**.
