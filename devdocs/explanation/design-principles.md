# Explanation: Architecture Decisions and Design Principles

This document explains the motivations, design philosophies, and architectural trade-offs behind Pokahdot. Understanding these principles will help you make design decisions that align with the project's vision.

---

## 1. Complete Decoupling of Game Core from UI and I/O

### The Rule
Code in `scripts/core/` must never reference `Control`, `SceneTree`, scenes (`.tscn`), UI nodes, `print()`, `stdin`, or `stdout`.

### Why?
1. **Shared Single Source of Truth**: The exact same poker rules, pot calculations, hand rankings, and blind progressions must power the graphical interface, the terminal CLI, and headless simulations. If poker logic were embedded in Godot scene scripts or UI signals, we would have to duplicate rules or write awkward UI-harness tests.
2. **Blazing Fast Headless Testing**: Core unit tests can run thousands of hands per second using GUT in headless mode without initializing Godot display servers, windows, or textures.
3. **Platform Independence**: The core engine compiles and runs cleanly across Web (HTML5/Wasm), macOS, iOS, Android, and headless Linux servers without modification.

---

## 2. Synchronous Stepping State Machine vs. Async / Threads

### The Challenge
A poker game involves sequential steps: dealer shuffles, blinds post, bot 1 bets, bot 2 calls, human considers options for 30 seconds, flop is dealt, etc.
In Godot, two common temptations exist:
- **Blocking loops**: `while waiting_for_human: sleep(100)` -> Freezes the Godot main thread, locking the UI window and triggering OS "not responding" errors.
- **Async Coroutines (`await`)**: Scattering `await signal` across game logic creates difficult-to-cancel state, hidden memory leaks, and tricky race conditions when a user clicks "Quit" mid-hand.

### The Solution: The Step Machine
Pokahdot models the match as an explicit state machine with synchronous stepping:
- `match.advance_until_blocked()` advances the game as far as possible without blocking.
- When it encounters a human turn, it yields with `StepResult.Status.WAITING_FOR_HUMAN`.
- When a human action arrives, the caller invokes `match.submit_human_action(action)` and execution resumes.
- For the GUI, `match.advance_one_action()` allows the UI to step a single bot action at a time, displaying visual delays and animations at its own pace using `GuiActionPacer`, without putting any timers into the core poker rules.

---

## 3. Defense-in-Depth Information Security via `GameView`

### The Problem
In poker, knowing an opponent's hole cards ruins the game. In a game with AI bots and user interfaces, developers often make the mistake of passing full player objects to the UI or agents and expecting them "not to peek" at private fields.

### The Solution: Boundary-Enforced Masking
Pokahdot enforces a strict information barrier:
- The game core generates a custom, read-only `GameView` snapshot for each recipient seat:
  - Seat 0's view contains Seat 0's hole cards.
  - Opponents' hole cards are omitted entirely from the view until `SHOWDOWN`.
- Neither bot algorithms nor GUI rendering code have physical access to opponent card data in memory. This eliminates accidental card leakage bugs and prevents bot logic from ever relying on hidden information.

---

## 4. Determinism via Named Independent RNG Streams

### The Problem
If a game uses a single global `RandomNumberGenerator`:
1. Changing a bot's strategy to make one extra random roll causes all subsequent community cards (Flop, Turn, River) to change!
2. Running a game in the GUI (which rolls random names/avatars) produces different cards than running the same seed in the CLI.

### The Solution: Split RNG Streams
Pokahdot creates multiple isolated RNG streams derived deterministically from the master tournament seed (`RngStreamFactory`):
- `deck`: Dedicated solely to shuffling and dealing cards.
- `initial_button`: Dedicated to initial button seat selection.
- `bot_seat_<n>`: Dedicated to Bot $n$'s stochastic strategy choices.
- `gui_avatars`, `gui_names`: Dedicated to visual cosmetic assignments.

Because the streams are isolated, a bot taking an extra random branch never alters the card deal. Any match can be replayed bit-for-bit.

---

## 5. Composition Roots and the Product Invariant

### The Invariant
A standard Pokahdot tournament requires **exactly one human player** and 1–8 bots. Conversely, batch simulations require **zero human players** (all bots).

### The Solution: `TournamentConstructionContract`
Rather than having boolean flags (`is_simulation = true`) floating around the configuration, Pokahdot enforces this invariant via an explicit contract:
- `TournamentConstructionContract.product()` validates that exactly one `HumanAgent` exists.
- `TournamentConstructionContract.simulation()` validates that zero `HumanAgent` instances exist.

`TournamentMatch` checks this contract at construction time, preventing illegal game compositions from ever starting.

---

## 6. Target-Total Wager Semantics

### The Convention
In Pokahdot, all bets and raises represent the **target total street wager**, not incremental chips:
- If current bet is 10 and player raises to 30, the action is `PlayerAction.raise_to(30)`.
- If a player calls, their street wager matches `current_bet`.

### Why?
Incremental betting ("raise by 20") creates ambiguity in No-Limit poker, especially when players have already posted blinds or made prior partial wagers on that street. Using target totals makes side-pot division, all-in thresholds, and minimum-raise validation mathematically clean and unambiguous.
