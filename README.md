# Pokahdot

Pokahdot er et poker-spill laget i [Godot](https://godotengine.org/) 4. Spillreglene ligger i en felles kjerne (`scripts/core/`), slik at det samme spillet kan vises både grafisk og i terminalen.

Prosjektet er tidlig i utviklingen. Grafisk UI og terminal-UI er under oppbygging.

## Krav

- Godot **4.7** (GDScript, Compatibility-renderer)
- Godot-binæren tilgjengelig som `godot` i `PATH`, eller full sti til editoren

## Start grafisk (GUI)

1. Åpne mappen `pokahdot` i Godot-editoren (**Import** / **Open**).
2. Trykk **Play** (F5).

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

Terminalgrensesnittet er foreløpig bare et startpunkt. Når det er implementert, leser det kommandoer fra stdin og skriver spilltilstand til stdout. Spillogikk skal fortsatt ligge i `scripts/core/`, ikke i CLI-laget.

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
