# Core Tasks

This backlog contains unfinished shared work that is neither adapter-specific
nor owned by the simulation backlog. Simulation and profile-evolution work is
in [`SimCoreTasks.md`](SimCoreTasks.md). Task status is preserved from the
source backlogs.

## GUI player-name presentation foundation

- [ ] Define a stored, presentation-only catalog of exactly 50 generated first
  names. Each name must consist only of Unicode letters, contain at most eight
  Unicode code points (not bytes or grapheme clusters), be unique within the
  catalog, and represent a deliberately broad range of world regions and
  cultures without using stereotypes or player data.
- [ ] Define and test the name-assignment contract: every bot receives one
  catalog name without replacement for the duration of a tournament; the human
  label is the literal `Human`; and assignment is deterministic from an
  injectable presentation-local `gui_names` RNG stream, distinct from the
  `gui_avatars` stream. The catalog, mappings, and RNG
  must not affect `Player`, `GameView`, rules, agent decisions, tournament RNG
  streams, or CLI player labels.
- [ ] Add validation and tests for catalog cardinality, uniqueness, maximum
  Unicode-code-point length, bot-seat coverage for 2–9 player tables, no duplicate
  assigned bot names, stable mapping throughout a tournament, and unchanged
  deterministic avatar assignments and core outcomes for fixed presentation
  and tournament seeds.

## Shared release verification

- [ ] Run all headless tests and resolve warnings or invariant failures.
- [ ] Review all user-facing text and documentation for consistency with the
  implemented game.
