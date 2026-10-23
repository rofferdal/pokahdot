# Pokahdot Developer Documentation

Welcome to the developer documentation for **Pokahdot**, a deterministic, single-table No Limit Texas Hold'em tournament engine built with **Godot 4** and **GDScript**.

Whether you are a junior developer writing your first feature, a contributor adding a new bot strategy, or an engineer integrating simulation workflows, this documentation will help you understand the architecture, get your hands dirty, and navigate the codebase with confidence.

---

## Documentation Structure (Diátaxis Framework)

This documentation is organized according to the [Diátaxis framework](https://diataxis.fr/), separating information into four distinct needs and quadrants:

```text
               PRACTICAL                   THEORETICAL
        +--------------------------+--------------------------+
        |                          |                          |
LEARNING|        TUTORIALS         |       EXPLANATION        |
        |  Learning-oriented       |  Understanding-oriented  |
        |  Hands-on onboarding     |  Architecture rationale  |
        |                          |                          |
        +--------------------------+--------------------------+
        |                          |                          |
PROBLEM |      HOW-TO GUIDES       |        REFERENCE         |
-SOLVING|  Task-oriented           |  Information-oriented    |
        |  Recipes for real work   |  APIs, models & design   |
        |                          |                          |
        +--------------------------+--------------------------+
```

### 1. Tutorials (Learning-Oriented)
Start here if you are new to the codebase.
- **[Understanding Pokahdot](tutorials/understanding-pokahdot.md)**: A hands-on walkthrough for junior developers explaining the mental model, execution flow, card security, and how to step through a live poker hand in code.
- **[Improving Bot Behavior Through Simulation](tutorials/improving-bots-with-simulations.md)**: A step-by-step tutorial on formulating a candidate bot hypothesis, running benchmark simulations, interpreting fitness metrics, and promoting a new profile to the playable game.

### 2. How-To Guides (Problem-Oriented)
Practical step-by-step instructions to get everyday development tasks done.
- **[Running and Testing](how-to/running-and-testing.md)**: How to launch the GUI and interactive CLI, run headless GUT tests, filter test suites, and execute code formatters and linters.
- **[Adding a Bot Strategy](how-to/adding-a-bot-strategy.md)**: How to create a new `DecisionModel`, define validated parameter resources, create a `.tres` profile, and wire it up.
- **[Running Simulations](how-to/running-simulations.md)**: How to execute non-interactive batch simulations, validate manifests, inspect reports, and replay runs.
- **[Evaluating Bot Performance & Statistical Decisions](how-to/evaluating-bot-performance.md)**: How to gather enough statistical information, calculate sample sizes, interpret 95% confidence intervals, and diagnose behavioral leaks.
- **[Replacing In-Game Bot Profiles](how-to/replacing-in-game-bot-profiles.md)**: The exact workflow and checklist for safely promoting and replacing in-game bot profiles across GUI, CLI, and test suites.

### 3. Reference (Information-Oriented)
Instructive, authoritative descriptions of the system machinery, architecture, and APIs.
- **[Architecture Reference](reference/architecture.md)**: An instructive guide to Pokahdot's layered architecture, module boundaries, composition roots, and state machines.
- **[Core Domain Reference](reference/core-domain.md)**: Reference guide to key domain classes (`TournamentMatch`, `HandController`, `BettingRound`, `PotManager`, `GameView`, `PlayerAction`).

### 4. Explanation (Understanding-Oriented)
Background context, architectural motivations, and design rationales.
- **[Design Principles & Architecture Rationale](explanation/design-principles.md)**: Why the core has no UI or I/O dependencies, why we use a non-blocking step loop instead of async coroutines, why cards are masked in `GameView`, and how independent RNG streams ensure determinism.

---

## 5-Minute Quick Start

Want to see Pokahdot in action immediately?

1. **Run the interactive CLI game**:
   ```bash
   godot --headless --path . --script res://scripts/cli/cli_app.gd
   ```
2. **Run the unit tests**:
   ```bash
   godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit
   ```
3. **Run the graphical interface**:
   ```bash
   godot --path . scenes/main.tscn
   ```

Ready to dive in? Head over to **[Understanding Pokahdot](tutorials/understanding-pokahdot.md)**!
