# Core Tasks

This backlog contains unfinished shared work that is neither adapter-specific
nor owned by the simulation backlog. Simulation and profile-evolution work is
in [`SimCoreTasks.md`](SimCoreTasks.md). Task status is preserved from the
source backlogs.

## GUI/CLI player-name presentation foundation

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

## Milestone — Strategic default roster and optional legacy heuristics

This milestone replaces the obsolete experimental-mode switch with the
product-roster policy in `ProjectDescription.md`. It owns the typed shared
configuration and roster-selection contract. The CLI and GUI task sections
below are coordinated gates: do not begin their implementation until the
corresponding core gate is complete.

- [ ] Remove `allow_experimental_models` from `TournamentConfig`,
  `StartupOverrides`, `ResolvedTournamentConfig`, configuration resolution,
  diagnostics contracts, and all product/simulation construction paths. Add
  the immutable, default-false `use_legacy_models` setting with equivalent
  explicit-override and defensive-copy semantics. It must not alter poker
  rules, card privacy, or simulation manifest semantics.
- [ ] Define and implement a `PlayableBotRoster` model-family classification
  contract: profiles whose registered implementation is `StrategyDecisionModel`
  are strategic; every other registered decision model is a legacy heuristic.
  Do not maintain a separate list of legacy profile IDs. Validate that the
  standard strategic pool is non-empty and that enabling legacy models has a
  non-empty legacy pool, with actionable diagnostics for invalid rosters.
- [ ] Implement deterministic family-aware product selection. With legacy
  models disabled, fill every bot seat from strategic profiles only. With the
  setting enabled, assign `ceil(bot_count / 2)` legacy seats and the remainder
  strategic seats; randomly map the selected profiles to bot seats using the
  existing named seat/profile RNG stream. Within a family, exhaust distinct
  profiles before deterministic repeat selection when its assigned seat count
  exceeds its profile count.
- [ ] Unit-test classification and selection for every 1–8 bot-seat count:
  default mode excludes every non-`StrategyDecisionModel` profile; legacy mode
  has the exact defined family counts; selection is deterministic for a seed;
  profile IDs are unique until a family is exhausted; and invalid/missing
  family pools fail without constructing a match.
- [ ] After the configuration and selection unit contracts pass, implement the
  CLI tasks in `CliTasks.md` and GUI tasks in `GuiTasks.md` in parallel. Keep
  both adapters restricted to collecting and displaying the setting; roster
  classification and selection remain shared code.
- [ ] After both adapter task groups pass, add cross-interface integration
  coverage for equivalent fixed-seed configuration, selected profile families,
  diagnostics, and normal exactly-one-human construction. Update all affected
  documentation and remove every user-facing reference to experimental mode.

## Milestone — Product strategic roster capacity

This core-only milestone caps the product roster's
`StrategyDecisionModel`-based profile family at 25. It does not change any
CLI or GUI contract and must not impose a profile-count limit on simulation
manifests, matchups, candidate batches, or profile evolution.

- [x] Add a named product-roster capacity contract of 25 strategic profiles to
  `PlayableBotRoster`. Count profiles by the same model-family classification
  used for product selection; legacy heuristic profiles do not consume this
  strategic capacity.
- [x] Validate the limit during product roster construction with a diagnostic
  that identifies the 25-profile strategic maximum. Preserve existing
  validation for IDs, model resolution, and required legacy profiles, and do
  not silently discard or reclassify profiles.
- [x] Prove through unit tests that rosters with 25 strategic profiles are
  valid, 26 are rejected, legacy profiles do not affect the strategic count,
  and normal deterministic product selection continues to work at every 1–8
  bot-seat count.
- [x] Add regression coverage proving that simulation manifest parsing,
  planning, execution, and profile-evolution inputs accept more than 25
  strategic profiles when otherwise valid. Do not route simulation validation
  through the product-roster capacity check.
- [x] Run the relevant headless unit and integration suites, then align
  `ProjectDescription.md` and `ARCHITECTURE.md` with the implemented
  product-only boundary. Do not add CLI or GUI tasks for this milestone.

## Shared release verification

- [ ] Run all headless tests and resolve warnings or invariant failures.
- [ ] Review all user-facing text and documentation for consistency with the
  implemented game.
