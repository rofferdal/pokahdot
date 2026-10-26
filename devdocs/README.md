# Pokahdot Developer Documentation

Welcome to the developer documentation for **Pokahdot**, a deterministic, single-table No Limit Texas Hold'em tournament engine built with **Godot 4** and **GDScript**.

Whether you are a developer writing your first feature, a contributor adding a new bot strategy, or an engineer integrating simulation and evolutionary workflows, this documentation will help you understand the architecture, get your hands dirty, and navigate the codebase with confidence.

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
- **[Understanding Pokahdot](tutorials/understanding-pokahdot.md)**: A hands-on walkthrough for developers explaining the mental model, execution flow, card security, and how to step through a live poker hand in code.
- **[Improving Bot Behavior Through Simulation](tutorials/improving-bots-with-simulations.md)**: A step-by-step tutorial on exporting an immutable snapshot of the active roster, running comparable candidate benchmarks, interpreting fitness metrics, and using the evidence-based promotion pipeline to update the playable roster.

### 2. How-To Guides (Problem-Oriented)
Practical step-by-step instructions to get everyday development tasks done.
- **[Running and Testing](how-to/running-and-testing.md)**: How to launch the
  GUI and interactive CLI, run headless GUT and Python test suites, execute
  simulations, run GUI invariant/capture workflows, and run linters. The
  authoritative visual evidence contract is in
  **[GUI Visual Testing](../docs/GUI_VISUAL_TESTING.md)**, with the standard
  **[GUI Defect Record](../docs/templates/GUI_DEFECT.md)**.
- **[Build and Serve over Local Wi-Fi](how-to/local-wifi-web-testing.md)**:
  How to serve the latest saved game code over HTTPS to the Mac, iPad and
  Android, rebuild while serving, trust the local certificate, and recover
  from an already-running server or an outdated browser build.
- **[Switching GitHub Pages to Manual Deployment](how-to/switching-github-pages-to-manual-deployment.md)**:
  How to replace the default automatic `main` deployment with an explicitly
  requested manual workflow that always deploys the latest commit on `main`,
  and how to restore automatic deployment.
- **[Adding a Bot Strategy](how-to/adding-a-bot-strategy.md)**: How to create a new `DecisionModel`, define validated parameter resources, register models with `PlayableBotRoster`, and write unit tests.
- **[Running Simulations](how-to/running-simulations.md)**: How to execute non-interactive batch simulations, validate manifests, run parallel shards, inspect reports, and replay runs.
- **[Evaluating Bot Performance & Statistical Decisions](how-to/evaluating-bot-performance.md)**: How to analyze simulation metrics, interpret 95% confidence intervals, evaluate behavioral style leaks, and verify the automated promotion criteria.
- **[Replacing In-Game Bot Profiles](how-to/replacing-in-game-bot-profiles.md)**: The exact workflow and checklist for candidate confirmation, consolidated human promotion review, profile publishing, and updating `PlayableBotRoster`.

### 3. Reference (Information-Oriented)
Instructive, authoritative descriptions of the system machinery, architecture, and APIs.
- **[Architecture Reference](reference/architecture.md)**: An instructive guide to Pokahdot's layered architecture, module boundaries, composition roots, and the external profile-evolution subsystem.
- **[Core Domain Reference](reference/core-domain.md)**: Reference guide to key domain classes (`TournamentMatch`, `HandController`, `BettingRound`, `PotManager`, `GameView`, `PlayerAction`, `PlayableBotRoster`).

### 4. Explanation (Understanding-Oriented)
Background context, architectural motivations, and design rationales.
- **[Design Principles & Architecture Rationale](explanation/design-principles.md)**: Why the core has no UI or I/O dependencies, why we use a non-blocking step loop instead of async coroutines, why cards are masked in `GameView`, how independent RNG streams ensure determinism, and why evolutionary algorithms are decoupled from the engine.

---

## 5-Minute Quick Start

Want to see Pokahdot in action immediately?

1. **Run the interactive CLI game**:
   ```bash
   godot --headless --path . --script res://scripts/cli/cli_app.gd
   ```
2. **Run all tests (GUT + Python)**:
   ```bash
   make check
   ```
3. **Run the graphical interface**:
   ```bash
   godot --path . scenes/main.tscn
   ```
4. **Run the simulation harness**:
   ```bash
   godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- help
   ```
5. **Capture the current roster as a simulation baseline**:
   ```bash
   godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
     export-roster-manifest --output artifacts/curated_roster_baseline.json
   ```
6. **Inspect the profile evolution CLI**:
   ```bash
   tools/profile-evolution --help
   ```

Ready to dive in? Head over to **[Understanding Pokahdot](tutorials/understanding-pokahdot.md)**!

Current task ownership is indexed in [docs/README.md](../docs/README.md).
The [simulation contract](../docs/Simulation_And_Evolutionary_Bot_Strategy.md)
is authoritative for versions, statistical eligibility, streams, and replay.
