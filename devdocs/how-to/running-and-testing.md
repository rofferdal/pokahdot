# How-To Guide: Running and Testing Pokahdot

This guide provides step-by-step commands for running the game in GUI or CLI mode, executing tests with GUT, and running code quality linters.

---

## 1. Prerequisites

- **Godot 4.7+**: Download from [godotengine.org](https://godotengine.org) or ensure the `godot` binary is in your `PATH` (on macOS, `/Applications/Godot.app/Contents/MacOS/Godot`).
- **Python 3 with `gdlint` and `gdformat`** (optional, for code formatting and linting):
  ```bash
  python3 -m venv .venv
  source .venv/bin/activate
  pip install gdtoolkit
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

#### In-Game CLI Commands:
When it is your turn, enter any of the following commands:
- `check` or `call`
- `fold`
- `bet <total>` (e.g. `bet 20` to make your street bet 20 chips)
- `raise <total>` (e.g. `raise 60` to raise the wager to 60 chips)
- `allin` (push all remaining chips)
- `help` (list available commands)
- `quit` or `exit` (conclude and exit the tournament)

---

## 3. Running Automated Tests

Pokahdot uses **GUT (Grand Unified Test)** for GDScript testing. All tests can be run headless from the terminal.

### Run the Complete Test Suite
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

### Run a Specific Test File
Use `-gtest=` with the resource path:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_hand_evaluator.gd
```

### Run Tests Matching a Pattern
Use `-gselect=` to filter by filename prefix or pattern:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_strategy
```

---

## 4. Code Quality & Linting

Before submitting pull requests, ensure your GDScript passes code formatting and linting rules.

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

### Run the Complete Pre-Commit Check (`Makefile`)
The project includes a Makefile target that imports assets, lints, format-checks, and runs all GUT tests:
```bash
make check
```

---

## 5. Building the Web Release

To export the web release target to `build/web/index.html`:
```bash
make web-release
```
*(Requires a clean git working tree and the Godot HTML5 export template installed).*
