# Pokahdot

Pokahdot er et poker-spill laget i [Godot](https://godotengine.org/) 4. Spillreglene ligger i en felles kjerne (`scripts/core/`), slik at det samme spillet kan vises både grafisk og i terminalen.

Prosjektet er tidlig i utviklingen. Grafisk UI og terminal-UI er under oppbygging.

## Krav

- Godot **4.7** (GDScript, Compatibility-renderer)
- Godot-binæren tilgjengelig som `godot` i `PATH`, eller full sti til editoren

## Start the graphical application (GUI)

1. Open the `pokahdot` folder in the Godot editor (**Import** / **Open**).
2. Press **Play** (F6). The startup screen is prefilled with 6 participants,
   1000 chips, and 5/10 blinds. Select **Start tournament** without editing to
   use those defaults, or change any value before starting.
3. The form validates whole-number input and the tournament constraints inline.
   A match is created only after all values are valid.
4. **Allow experimental models** is unchecked by default. Select it to use the
   evaluated mixed roster of parameterized bot profiles; leave it unchecked to
   retain the production roster. The choice resets to unchecked when returning
   to the startup screen.

Fra terminal, med prosjektroten som arbeidsmappe:

```bash
godot --path .
```

På macOS, hvis Godot ikke ligger i `PATH`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Start headless (terminal)

Kjør CLI-inngangen uten vindu:

```bash
godot --headless --path . --script res://scripts/cli/cli_app.gd
```

På macOS uten `godot` i `PATH`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/cli/cli_app.gd
```

The terminal interface supports a complete tournament with optional startup
overrides, poker actions, `help`, `quit`, and `exit`. Game rules remain in
`scripts/core/`, not in either presentation layer.

### Experimental bot roster

The production roster remains the default. To opt into the evaluated,
non-production parameterized roster, pass the flag after Godot's `--`
argument separator:

```bash
godot --headless --path . --script res://scripts/cli/cli_app.gd -- --allow-experimental-models
```

Startup diagnostics identify the selected production or experimental roster
and every bot's model and profile ID. The experimental mixed roster uses the
`nit_caller`, `tight_aggressive`, `loose_passive`, `loose_aggressive`, and
`balanced` profiles. It is deterministic for a fixed tournament seed and does
not expose opponent hole cards.

## Development checks

Install the pinned development tools in a local virtual environment:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
```

Run the GDScript linter and verify formatting without modifying files:

```bash
.venv/bin/gdlint scripts tests my_test_node.gd
.venv/bin/gdformat --check scripts tests my_test_node.gd
```

Run the Godot tests headlessly:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

## GUI action pace

The GUI waits two seconds after rendering each player action before advancing to the next automatic action. It uses the same configured pause after each flop, turn, and river reveal, then waits five seconds after showdown before starting the next hand. Edit `resources/gui_action_timing_config.tres` in Godot to change `default_pause_seconds`, add a `pause_seconds_by_seat` entry for an individual bot seat (for example, seat `1`), or change `showdown_pause_seconds`. Set a value to `0.0` for immediate progression during development.

## Mappestruktur

```
pokahdot/
├── scenes/                 # Grafisk UI (.tscn)
├── scripts/
│   ├── core/               # Spilllogikk uten UI
│   ├── gui/                # Scripts til Control-noder
│   └── cli/                # Terminal-UI (headless)
├── resources/              # Custom Resources, f.eks. kortdata (.tres)
└── assets/                 # Sprites, fonter og lyder
```
