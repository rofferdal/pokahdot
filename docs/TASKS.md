# Pokahdot Tasks

This backlog follows `docs/ARCHITECTURE.md` and is ordered as vertical, runnable increments. Complete tasks in order unless a dependency explicitly allows parallel work.

The CLI is the first acceptance surface. Add CLI behavior as soon as a core capability can be exercised by a person. Do not start GUI implementation until the CLI supports a complete, playable single-table tournament and the CLI completion gate is checked.

Status markers:

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked

Task labels:

- **App increment:** the application gains new behavior that can be run by a person.
- **Human test:** manually exercise the app after automated tests pass and record/fix any issue before continuing.
- **Gate:** later work must not begin until every item in the gate is complete.

Human tests complement automated tests; they do not replace them. If a human test finds a defect, add or update an automated regression test before marking the human-test task complete.

## Milestone 0 — Development foundation and CLI shell

- [x] Vendor and pin GUT 9.7.1, retain its license, add `.gutconfig.json`, and verify a headless test run.
- [x] Pin GDScript Toolkit 4.x for development and configure `gdlint` plus `gdformat --check`.
- [x] Add shared GUT test support utilities without a custom test runner.
- [x] Implement typed configuration defaults, independent optional overrides, and authoritative validation for player count 2–9, positive integer starting stack, positive integer blinds with small blind no greater than big blind, and immutability after match start; add omission, partial-override, boundary, and rejection tests.
- [x] Implement deterministic RNG stream creation from the validated configuration.
- [x] Implement a CLI startup flow that displays all defaults and can start immediately without supplied values, plus optional independent overrides for participant count, starting stack, small blind, and big blind, invalid-input retry, and a final resolved-configuration summary.
- [x] Add CLI startup-flow tests for complete omission, partial overrides, full valid overrides, invalid-value retry, and prevention of match construction before validation succeeds.
- [x] Implement the CLI command loop and basic parsing for `help` and `quit` without adding poker rules to the adapter.
- [x] **App increment:** `cli_app.gd` starts headlessly, can start with no values supplied or with optional tournament overrides, reports configuration errors clearly, displays help, accepts `quit`, and exits cleanly.
- [x] **Human test:** launch the CLI from the documented command and start immediately without specifying values; verify the 6-player, 1000-chip, 5/10 summary. Restart with only one overridden field and verify all omitted defaults, then restart with all non-default valid values. Restart again and verify that non-integer, out-of-range, non-positive, and small-blind-greater-than-big-blind input is rejected and re-prompted. Finally verify help, unknown-command recovery, and clean `quit`.

## Milestone 1 — First interactive preflop hand

- [x] Implement `CardData` and `Deck` with uniqueness, exhaustion, and deterministic-shuffle tests.
- [x] Implement `ChipStack` and `Player` with non-negative chip and reset-state tests.
- [x] Implement `Table` seat traversal, initial button, blinds, and heads-up order tests.
- [x] Implement `PlayerAction` and typed action-validation results.
- [x] Implement `BettingRound` with legal actions, minimum raises, calls, folds, short all-ins, and action-reopening tests.
- [x] Implement the `PotManager` contribution ledger and single-winner fold-to-one award tests.
- [x] Implement the initial recipient-specific `GameView` for preflop state, public action history, and hidden-card tests.
- [x] Implement the `Agent` contract, `HumanAgent`, and scripted test agent.
- [x] Implement `BotAgent`, `DecisionModel`, typed `DecisionModelParameters`, `BotProfile`, `DecisionModelRegistry`, and `AgentFactory` with configuration-validation tests.
- [x] Implement `RandomDecisionModel`, its parameter Resource and default profile, plus deterministic and legal-action tests; expose `RandomAgent` as a thin preset constructor.
- [x] Implement the first `HandController` slice: setup, blinds, hole cards, preflop betting, human wait/resume, bot fallback, fold-to-one settlement, and domain events.
- [x] Implement the first `TournamentMatch` slice: validate configuration, start one hand, expose views/events, accept human actions, and handle `player_quit`.
- [x] Extend CLI parsing and rendering for preflop state plus `fold`, `check`, `call`, `bet`, `raise`, `allin`, `quit`, and `exit`.
- [x] Add an integration test that completes a hand preflop when all opponents fold.
- [x] Wire `cli_app.gd` and the CLI command loop to construct `TournamentMatch` from the resolved startup configuration, start its seeded hand, render each human-facing `GameView`, submit parsed actions only while waiting for the human, let bots advance without reading stdin, and route `quit`/`exit` through `request_quit()`.
- [x] Complete the Milestone 1 preflop renderer so every human-facing snapshot shows the hand number and street; button, small-blind, big-blind, and acting seats; every seat's name, stack, current-round contribution, folded status, and all-in status; total pot; ordered public action history including blind postings; only the human recipient's hole cards; and legal actions with call amount plus minimum and maximum bet/raise totals where applicable.
- [x] Add CLI adapter regression tests proving that starting with resolved default and non-default configurations renders the initial preflop snapshot before the first prompt, re-renders state after accepted human and bot actions, never exposes bot hole cards, reports invalid commands and rejected amounts without losing the human turn, and renders fold-to-one settlement or `player_quit` termination.
- [x] **App increment:** a human can use the startup-selected participant count, starting stack, and blinds to start one seeded hand against bots, inspect private/public state, make legal preflop actions, win or lose by folds, and quit.
- [x] Implement a CLI-only card formatter compliant with `docs/POKERCARDS_IN_CLI.md`: ranks `2`–`10`, `J`, `Q`, `K`, and `A`; suits `♠`, `♥`, `♦`, and `♣`; single-card output with no separator; and collections formatted as `[ Card1 | Card2 | CardN ]`. Replace internal numeric card codes in the preflop renderer without moving presentation rules into `CardData` or `scripts/core/`.
- [x] Add CLI formatter and renderer regression tests covering every rank and suit, rank `10`, collection delimiters and brackets, UTF-8 suit output, hero-card rendering, absence of internal numeric card codes, and continued absence of opponent hole cards.
- [x] Add the authoritative human flag to `PlayerView` snapshots and update every CLI player row to append `(you)` immediately after the human player's display name. Do not infer human identity from seat number, acting state, recipient cards, or name, and never mark a bot.
- [x] Add CLI renderer regression tests proving that exactly one player is marked `(you)` for default and non-default table sizes, that the marker follows the human flag across repeated snapshots, and that no bot receives it.
- [x] Update `BettingRound` to use a fixed big-blind minimum full-raise increment instead of the previous full raise size: minimum raise total is always `current_bet + big_blind`; preserve short all-ins below that minimum and action-reopening behavior; replace the old escalating-minimum tests with regression coverage for first and subsequent raises, including a raise following a larger full raise.
- [x] **Human test:** run the CLI hand with non-default startup values and verify, before entering a poker command, the hand number and preflop street; button, blind, and acting seats; all configured players with correct stacks, contributions, folded/all-in status; exactly the human player marked `(you)` after the display name; pot and public blind/action history; only the human's hole cards formatted like `[ A♠ | 10♥ ]` with no internal numeric codes; and legal actions with relevant call and wager limits. Try an invalid command and illegal amount and verify the same human turn remains available, complete one fold-to-one hand and verify the result, and quit both before and during human action.

## Milestone 2 — Complete single hand through the CLI

- [x] Implement `HandEvaluator` with all categories, wheel handling, kickers, ties, and parameterized tests.
- [x] Extend `PotManager` with main-pot and side-pot derivation, eligibility, split pots, and odd-chip tests. Correct the discovered contribution-threshold behavior so unmatched excess is returned rather than represented and awarded as a one-player pot, and merge adjacent contribution layers when they have identical eligible winners.
- [x] Extend `HandController` through flop, turn, river, automatic all-in runout, showdown, pot awards, and normal hand completion.
- [x] Complete `GameView` street, board, pot, showdown reveal, and legal-action snapshots. Add a recipient-safe showdown result per revealed seat containing the evaluated category, ordered tie-break values, and exact selected five cards; do not expose folded or otherwise unrevealed hands.
- [x] Extend CLI rendering for community cards, canonical pot layers, street changes, showdown hands, awards, best five-card combinations, and final stacks; format every visible board, hole-card, and selected-hand collection according to `docs/POKERCARDS_IN_CLI.md`. During live betting, do not label ordinary contribution thresholds from blinds or unequal wagers as separate side pots.
- [x] Add a regression test for the reported showdown: on board `[ A♦ | K♦ | 2♦ | 3♣ | K♠ ]`, verify that `[ 7♣ | Q♦ ]` wins over `[ J♥ | 6♣ ]` and `[ 9♠ | J♦ ]` by the queen kicker, and verify the category, complete ordered kickers, selected five cards, and CLI output for every revealed player.
- [x] Add pot regressions proving that unequal blinds alone display one total pot, a called wager without an all-in does not create a side pot, folded contributions do not create duplicate pots with identical eligibility, unmatched all-in excess is returned, and genuine differently eligible main/side pots remain separate.
- [x] Add deterministic integration tests for a checked-down showdown, fold after the flop, split pot, and multi-way all-in with a side pot. Update the side-pot expectations to canonical poker pots and assert the selected five-card showdown output.
- [x] **App increment:** a complete No Limit Texas Hold'em hand can be played from blinds through showdown or an earlier fold using only the CLI. Re-verify after the showdown-result and canonical-pot defects are fixed.
- [x] **Human test:** play at least one CLI hand to showdown and one hand ending by fold; verify board progression, pot and stack updates, opponent-card privacy, winner output, and clean handling of invalid input on multiple streets.

## Milestone 3 — Complete CLI tournament

- [x] Extend `TournamentMatch` with the hand-to-hand lifecycle, button movement, elimination, winner detection, and quitting between hands.
- [x] Implement `TightPassiveDecisionModel` and `LooseAggressiveDecisionModel`, typed parameters, default profiles, and thin `TightPassiveAgent`/`LooseAggressiveAgent` preset constructors.
- [x] Add parameter-boundary tests and prove that the same model can run at multiple seats with different profiles and independent RNG streams.
- [x] Configure at least two decision model classes at the standard table and report model/profile IDs in startup diagnostics without exposing private model state.
- [x] Extend the CLI loop across hands and render hand numbers, eliminated players, remaining players, tournament winner, and `player_quit` termination; preserve the `(you)` marker on the human in every player summary.
- [x] Add deterministic integration tests for button/blind movement, skipped busted seats, heads-up transition, tournament winner, and quit before/during/between hands.
- [x] Add a deterministic short-stack startup selection for manual testing and verify that the values chosen by the existing CLI setup flow remain fixed across every hand without changing production defaults.
- [x] Add a full seeded tournament smoke test and assert chip conservation after every completed hand.
- [x] **App increment:** one human and at least two bots can play a complete single-table tournament through the CLI until one winner remains, or the human can quit without a winner.
- [x] Add a CLI dealer-button indicator to the player summary for the current button seat, with regression coverage proving it follows button movement and never marks another seat.
- [x] **Human-test handoff:** a person must execute and record the following Milestone 3 CLI scenarios before the human-test tasks can be marked complete. An automated agent may prepare commands and regression coverage, but must not mark this task complete on the person's behalf.
- [x] **Human test:** use the short-stack configuration to finish a CLI tournament; verify hand transitions, button/blind movement, elimination, heads-up behavior, final winner, and total chips.
- [x] **Human test:** start a second CLI tournament and verify `quit`/`exit` produces `player_quit`, no winner, and a clean process exit.

## CLI completion gate — required before GUI work

- [x] **Gate:** all GUT unit and integration tests pass headlessly.
- [x] **Gate:** `gdlint` and `gdformat --check` pass for project GDScript.
- [x] **Gate:** every Milestone 0–3 human-test task is complete with discovered defects covered by regression tests.
- [x] **Gate:** the complete CLI tournament satisfies the applicable acceptance criteria in `docs/ProjectDescription.md`.
- [x] **Gate:** CLI code contains presentation/parsing only; poker rules remain exclusively in `scripts/core/`.
- [x] **Gate:** CLI startup can omit every value, override any subset, or override all participant/stack/blind values; it resolves omitted fields to defaults, rejects invalid explicit values before match creation, and uses the resolved values for the complete tournament.
- [x] **Gate:** every card visible in the CLI uses the rank-plus-Unicode-suit and bracketed collection format from `docs/POKERCARDS_IN_CLI.md`; internal card IDs and numeric rank/suit pairs never appear in player-facing output.
- [x] **Gate:** every CLI player list marks exactly the human player with `(you)` immediately after the display name, and no bot is marked as human.
- [x] **Gate:** adding a test decision model and profile requires registry/configuration changes only and no edits to poker-rule modules.
- [x] **Gate:** `README.md`, `docs/ProjectDescription.md`, and `docs/ARCHITECTURE.md` describe the working CLI accurately.

## Milestone 4 — GUI for the functionally complete game

Complete each GUI phase in order. Each human test is a gate for the next phase: record the outcome and add a regression test for any discovered defect before proceeding.

### Milestone 4.1 — GUI startup flow

- [x] Build the startup configuration panel for participant count, starting stack, small blind, and big blind, prefilled with defaults and able to start without any user edits before `TournamentMatch` construction.
- [x] Add inline startup validation, prevent starting with invalid values, and map a valid selection into a fresh immutable tournament configuration.
- [x] Add GUI adapter tests for default startup, independent partial overrides, full valid overrides, invalid-value rejection, and prevention of match construction before validation succeeds.
- [x] Fill into README.md a section on how to start the application with GUI
- [x] **App increment:** a person can launch the GUI, start a tournament with defaults, or choose a validated custom configuration before a match is created.
- [x] **Human test:** launch the GUI with no edits and confirm the default configuration starts. Restart and verify one partial override, all overrides, and clear inline feedback for invalid values without starting a match.

### Milestone 4.2 — Visual table foundation

- [x] Generate and add a catalog of 16 distinct small avatar assets for GUI player seats, suitable for 32 by 32 pixel display and compatible with the Godot Compatibility renderer.
- [x] Add a GUI-owned avatar catalog and a seeded, non-repeating seat-to-avatar assignment service for each tournament; use distinct small avatar assets targeting 32 by 32 pixels, reject insufficient catalogs clearly, and keep avatar state and RNG outside `scripts/core/`.
- [x] Build the main scalable `Control`-based table scene with a green felt surface, seat positions, and explicit visual zones for community cards, player wagers, and the pot.
- [x] Add visible face-down community-card placeholders, responsive central-zone constraints, and non-wrapping player-seat presentation so the table remains legible at desktop and mobile aspect ratios.
- [x] Add GUI adapter tests for deterministic unique avatar assignment, insufficient avatar catalogs, and the table scene's board/wager/pot-zone bindings.
- [x] Add a regression test proving that default and 9-player seat widgets receive distinct, visible, non-overlapping, in-bounds positions after the initially hidden table is shown at desktop and mobile aspect ratios.
- [x] Set the explicit game-screen startup size default to 1920 by 1080 pixels, and protect the configured dimensions with an automated regression test.
- [x] The text/font size in the GUI in both startup screen and in the boards is too small. Make it 1.8x larger.
- [x] **App increment:** after valid startup, the GUI opens a responsive green table with all seats and distinct assigned avatars around the table.
- [x] **Human test:** start default and 9-player tables; verify that all visible avatars are distinct, seats remain readable, and the community-card, wager, and pot zones are clearly separated at representative desktop and mobile aspect ratios.

### Milestone 4.3 — Read-only live table rendering

- [x] Connect the table controller to recipient-safe `TournamentMatch` views and render stacks, blinds, dealer, acting player, board, pots, private hero cards, active/eliminated seats, and hidden opponent cards without action controls.
- [x] Add GUI adapter tests for recipient-safe card visibility, initial preflop rendering, board and pot updates, player-position markers, and elimination rendering.
- [x] **App increment:** a person can start a GUI tournament and inspect the complete current table state before acting, without seeing opponent hole cards.
- [x] Keep every seat name and its position marker visibly readable at supported desktop and mobile table sizes.
- [x] Map the human recipient to the bottom visual seat without changing core seat identities or poker positions; move the human stack/status and private cards into that seat panel, rendering each hole card as a card face.
- [x] Add GUI layout regressions for full seat names, bottom-anchored human seating, private hero card faces, and non-overlapping seats at default and 9-player sizes.
- [x] Render every player stack, dealer/small-blind/big-blind/acting markers, and two face-down opponent cards directly in the live seat panels; add a regression test for the human-test omission.
- [x] Replace clipped position text and unsupported hidden-card glyphs with readable position badges and visible card-back controls; enlarge opponent seat typography and preserve non-overlap at default and 9-player layouts.
- [x] Increase bot chip-stack text for readability, render avatars at twice their previous display size, and use one shared card dimension for hidden and showdown-revealed bot hole cards.
- [x] Add GUI layout regressions for enlarged bot chip text and avatars, plus equal hidden/revealed bot-card dimensions.
- [x] Widen nine-player desktop seat panels so every player name remains readable alongside the enlarged avatar and position badge, while preserving in-bounds non-overlapping layout.
- [x] Add a nine-player desktop layout regression for the widened panel and readable name area.
- [x] Apply the same wide desktop player-panel dimensions to every supported player count, including the human seat, while preserving the compact mobile layout.
- [x] Add desktop layout regression coverage proving that player panels have equal wide dimensions for 2–9 players.
- [x] With 3, 5, 6 and 7 players, the distribution of player positions around the table is not symmetric on left vs right side. Distribute players symmetric regardless the number of players.
- [x] Add GUI layout regression coverage proving mirrored left/right player-seat placement for 3–7 player tables.
- [x] **Human test:** inspect initial and automatically advanced bot snapshots at 2, 6, and 9 players; verify equally wide desktop player panels, readable bot chip-stack text, blinds, dealer, acting marker, private/public cards, doubled-size avatars, hidden opponent cards, and fully readable player names. At showdown, verify that each visible bot hole card has the same dimensions as its hidden card back.

### Milestone 4.4 — Human actions and hand completion

- [x] Connect Fold, Check/Call, Bet/Raise presets, free amount input, all-in, and legal-action enabled states.
- [x] Present ordered domain events without duplicating settlement, winner, or legality rules in GUI code.
- [x] Add GUI adapter tests for legal-action enabled states, action mapping, rejected amounts, event ordering, fold-to-one settlement, and showdown rendering.
- [x] **App increment:** a person can use the GUI to play one hand from preflop through fold or showdown, with accurate state updates after every action.
- [x] Reposition the human action controls to the bottom-right table area immediately right of the human seat, without obscuring any seat at supported desktop sizes.
- [x] Reposition the ordered event feed to the left of the human seat without obscuring any seat, using concise event text.
- [x] Render each player's latest public action directly below that player's seat using compact poker abbreviations.
- [x] Add GUI layout and adapter regressions for non-overlapping action/event panels and per-seat compact action labels at 6 and 9 players.
- [x] Replace the tall human-action panel with a compact single-row strip using action text larger than the human-seat detail text.
- [x] Widen the ordered event feed, give it a fixed scrollable viewport, and preserve access to earlier events without obscuring seats.
- [x] Add GUI regressions for the compact action-strip height and typography, plus the event-feed width and scrolling configuration.
- [x] Replace abbreviated and ambiguous action labels with explicit controls arranged across two compact rows; show `All-in` in full and distinguish minimum and preset raise controls.
- [x] Widen and restyle the scrollable event feed with black text on a light-grey surface.
- [x] Render each player's latest public action as a separate line directly below the seat rather than inside its seat panel.
- [x] Render folded/outbid players in grayscale while keeping their seats visible and hiding their hole cards.
- [x] Add GUI regressions for explicit two-row action controls, high-contrast event history, external action labels, and folded-seat privacy/grayscale treatment.
- [x] Give every human action control a compact framed treatment so adjacent actions are visually distinct.
- [x] Center the complete community-card, pot, and wager zone from its resolved bounds at supported viewport sizes.
- [x] Render face-up community-card suits in their standard red or dark colours rather than a shared yellow colour.
- [x] Enforce a 20 px minimum for all player-facing GUI text, including compact layouts, matching the desktop opponent-name baseline.
- [x] Add GUI regressions for center-zone alignment, suit-aware community cards, and the GUI text-size floor.
- [x] Render dealt community cards with a light, high-contrast face background matching exposed hole cards, while retaining dark face-down placeholders.
- [x] At showdown, render each revealed player's best evaluated hand above that seat using the recipient-safe `ShowdownResult` category and rank data.
- [x] Add GUI regression coverage for showdown hand-summary wording and placement above the corresponding seat.
- [x] Reflow every seat so its chip stack appears directly below the player name, keeping wagers and all-in actions outside the seat panel.
- [x] Narrow the dealer and blind marker area while preserving legible position labels.
- [x] Add GUI regression coverage for the separate name/stack rows and compact position-marker width.
- [x] At showdown, mark the player with the best hand, winning the main pot With a yellow star next to the player seat area, but overlapping nothing. Make the star half the size of the avatar.
- [x] Fix the GUI seat-layout mapping so dealer, small blind, and big blind markers always appear in consecutive clockwise order around the visual table, while preserving the human recipient at the bottom and core seat identities; add layout regressions for 2–9 players.
- [x] **Human test:** complete one fold-to-one hand and one showdown hand; verify enabled actions, wager presets and free input, rejected amounts, board progression, pot awards, and opponent-card privacy.

### PR — Code quality and structure gate before Milestone 4.5

- [x] **PR gate:** review every changed GDScript file for precise, domain-oriented names. Classes, methods, variables, constants, signals, scene nodes, and Resource IDs must describe their responsibility; remove misleading abbreviations, stale names, and ambiguous generic names.
- [x] **PR gate:** verify each file has one clear responsibility and is located in the owning layer. Keep poker rules and mutable match state in `scripts/core/`; keep GUI layout, styling, and input adaptation in `scripts/gui/` and `scenes/`; keep terminal parsing and rendering in `scripts/cli/`.
- [x] **PR gate:** verify dependency direction and interfaces: presentation uses recipient-safe views and typed core commands/results; `scripts/core/` imports no `Control`, scene, or standard-I/O API; presentation code does not calculate betting, settlement, visibility, or tournament rules.
- [x] **PR gate:** require strong types, named constants instead of unexplained literals, explicit validation/error paths, and focused automated regression coverage for any refactoring. Run the full headless test suite, `gdlint`, and `gdformat --check` before approving the PR.

### Milestone 4.5 — Tournament progression and quit

- [x] In GUI mode, highlight the acting player's seat with a white frame three times thicker than the normal seat-frame line; retain the existing frame styling for every non-acting seat, and add adapter/layout regression coverage.
- [x] In GUI mode, after rendering an active player's action, wait two seconds before advancing to the next player who must act; keep the UI responsive throughout the delay and add deterministic adapter coverage for the timing behavior.  The length of this pause should be configurable in some way in accordance with best godot code practice for configurability and documented in ARCHITECTURE.md. Update README.md with explanation about how to configure the timing pause for each bot player.
- [x] At showdown, also show hole cards of losing players in GUI.
- [x] Continue the GUI controller across hand boundaries and render button movement, eliminated seats, heads-up behavior, final stacks, and the tournament winner.
- [x] Add the always-available `Quit` control with confirmation and `player_quit` handling.
- [x] Add GUI adapter tests for next-hand progression, eliminated-seat skipping, winner rendering, quit-confirmation cancel/accept behavior, and clean `player_quit` termination.
- [x] Eliminated players (0 chips when a new hand starts) in tournament should be greyed out.
- [x] Add a 5 second pause when showdown is shown before progressing to next hand.
- [x] Add a pause after community cards are turned (flop, turn, river) equal to bot player pause length.
- [x] There is no need to pause for action from players that are all in (they should not have any action until showdown).
- [x] **App increment:** the human can start with defaults or optional valid overrides and play the same complete tournament available in the CLI through the GUI, until one winner remains or the human quits, without duplicated rules.
- [x] Quit after finishing Tournament should bring game screen back to startup. Startup screen should also have a quit button, which ends the program.
- [x] **Human test:** use the short-stack configuration to finish a GUI tournament; verify hand transitions, button and blind movement, eliminations, heads-up behavior, final winner, total chips, distinct avatars, and the green table zones.
- [x] **Human test:** start another GUI tournament; verify quit confirmation cancels safely, then confirm quitting produces `player_quit`, no winner, and a clean return from the active table.

### Milestone 4.6a — GUI information and visual polish

- [x] Verify that layout is good for different screen sizes, including Ipad, in browsers, on desktop, in mobile phone.
- [x] Audit every GUI game state (startup, live action, street transitions, all-in runout, showdown, hand settlement, elimination, tournament winner, and `player_quit`) to ensure all player-facing information is present, unambiguous, and readable without relying on CLI output.
- [x] Improve the presentation-only table and action UI as needed for visual hierarchy, spacing, alignment, color contrast, card and avatar treatment, and consistent state feedback; do not duplicate poker rules or move game state out of `scripts/core/`.
- [x] Add or update GUI layout and adapter regressions for every corrected information or visual defect, including supported desktop and mobile aspect ratios and 2–9 player counts where applicable.
- [x] **App increment:** the complete GUI tournament presents all required poker, action, and tournament information clearly throughout play, with a coherent and polished visual design.
- [x] The event log field is not consistently aligned with the human player seat. The bottom of the human player seat and the bottom of the event field should be aligned.

### Milestone 4.6b — Web publishing and pre-human test runbook

Use `docs/WEB_SETUP.md` as the authoritative procedure. An **Agent task** may
be completed by a coding agent with repository access. A **Human task** is
written for an inexperienced developer and requires a person because it uses a
hosting account, makes a release/publication decision, or needs a real browser
or physical device. Agents may prepare commands, configuration, templates, and
regression coverage, but must never mark a Human task complete or invent test
evidence on a person's behalf.

- [x] **Agent task — export configuration:** add and commit the Godot 4.7.2
  `Web` release preset in `export_presets.cfg`. Keep Web threads disabled for
  the baseline release, keep credentials out of version control, and ignore
  reproducible `build/` output. Add a regression or release check proving the
  preset is present and named exactly `Web`.
- [x] **Human task — install export prerequisites:** install Godot 4.7.2 and
  its matching export templates using the instructions in `docs/WEB_SETUP.md`.
  Open **Project > Export** and confirm that the committed `Web` preset is
  visible without a missing-template warning. Record the Godot version used.
- [x] **Agent task — reproducible release build:** add the repository-local
  commands or automation needed to run lint, formatting, all GUT tests, and
  `--export-release "Web" build/web/index.html` from a clean commit. Verify
  that `index.html` and every file it references are in `build/web`, and that
  development addons and tests are not included in the release output.
- [x] **Agent task — deployment configuration:** add a reviewed GitHub Pages
  deployment workflow which installs pinned Godot 4.7.2 plus matching export
  templates, runs the release checks, exports only `build/web`, creates
  `.nojekyll`, uploads the artifact, and deploys it with the least required
  Pages permissions. The workflow must expose the exact deployed URL and fail
  on an export or test failure.
- [x] **Human task — approve hosting and enable Pages:** confirm that GitHub
  Pages is an approved host and that the chosen repository visibility/audience
  is acceptable. In **Settings > Pages**, select **GitHub Actions**, commit and
  push the reviewed workflow to the approved release branch, and retain the
  successful deployment run URL. Do not publish a build containing
  uncommitted changes.
- [x] **Agent task - found error after deploy to Github pages** card suites and
  star for winning player are not displayed correctly in web browser
- [x] **Agent task — deployment review:** inspect the successful workflow
  artifact and deployment metadata. Confirm that the generated site is served
  from the release artifact at the expected stable `https://` URL, that the
  exported Web build is single-threaded, and that the evidence-record template
  in `docs/WEB_SETUP.md` is ready for the published commit. Report any issue
  without marking a browser/device test complete.
- [ ] **Human task — hosted-build readiness evidence:** on the intended test
  device, open the stable URL in a private/incognito window. Wait for the
  startup screen, inspect the browser console for errors, and save screenshots.
  Record the URL, full commit SHA, deployment-run URL, device model, OS
  version, browser version, orientation, viewport size, and console result in
  the evidence record.
- [ ] **Human task — desktop Chrome or Edge matrix:** on current Windows or
  macOS Chrome/Edge, execute the representative flow in both 2-player and
  9-player default tournaments at 1920×1080 and 1280×720. Capture every
  required state and readability/bounds result specified in `docs/WEB_SETUP.md`.
- [ ] **Human task — desktop Firefox matrix:** repeat the desktop matrix in
  current Firefox at both sizes. Explicitly record font rendering, suit
  colours, scrollable event history, and the event-log/human-seat bottom
  alignment compared with the approved reference screenshots.
- [ ] **Human task — physical iPad Safari matrix:** use a physical supported
  iPad in Safari in portrait and landscape, testing 2-player and 9-player
  games. Rotate during startup and live play; record screenshots and any
  scrolling, clipping, overlap, readability, stale-layout, or touch defect.
- [ ] **Human task — physical iPhone Safari matrix:** use a physical supported
  iPhone in Safari in both orientations with a 9-player game. Verify wrapped
  controls, event-history scrolling, Fold/Call/Raise/All-in taps, and one
  mid-play rotation; save before/after screenshots.
- [ ] **Human task — physical Android Chrome matrix:** use a physical supported
  Android phone in current Chrome and repeat the iPhone flow with the browser
  address bar both expanded and collapsed. Record every touch, clipping,
  contrast, text-size, and orientation result with screenshots.
- [ ] **Agent task — defect remediation:** for each human-reported defect,
  reproduce it from the supplied evidence where possible, fix only the
  appropriate presentation/deployment layer, add or update a regression test,
  run the full automated suite, and prepare a new deployment candidate.
- [ ] **Human task — evidence sign-off:** verify that every required browser
  and physical-device record is attached to one immutable commit and stable
  HTTPS URL. Confirm reruns after every defect fix, then mark the corresponding
  Milestone 4.6c pre-human checks complete.

Milestone 4.6c Human testing with preparations

- [x] Pre-human testing: document hosted-build checks by browser and device so testers do not need local repository access.
  - [ ] **Pre-human test — hosted build readiness:** publish the Web export at a stable HTTPS URL. On the test device, open that URL in a private/incognito window, wait for the startup screen without browser-console errors, and record the URL, build version/commit, device model, OS version, browser version, orientation, and viewport size with screenshots.
  - [ ] **Pre-human test — desktop Chrome/Edge:** on a current Windows or macOS desktop browser at 1920×1080 and a resized 1280×720 window, start both 2-player and 9-player default tournaments. Confirm all seats, event history, action controls, cards, board, pot, markers, and Quit confirmation are visible, readable, in bounds, and non-overlapping. Play through a fold, normal betting, all-in runout, showdown, elimination, tournament winner, and player quit; attach screenshots for each state.
  - [ ] **Pre-human test — desktop Firefox:** on a current Windows or macOS Firefox browser at 1920×1080 and 1280×720, repeat the desktop Chrome/Edge flow. Specifically confirm font rendering, card-suit colours, scrollable event history, and the event-log bottom alignment with the human seat match the reference screenshots.
  - [ ] **Pre-human test — iPad Safari:** on a physical iPad running a supported iPadOS version, open the hosted URL in Safari in both portrait and landscape. Test 2-player and 9-player games, rotate during startup and live play, and complete the representative flow. Confirm no horizontal page scroll, clipped controls, overlap, unreadable text, stale layout, or lost touch input after rotation; capture a screenshot per orientation and state defect.
  - [ ] **Pre-human test — iPhone Safari:** on a physical supported iPhone, open the hosted URL in Safari in portrait and landscape. Start a 9-player game, verify wrapped action controls remain fully tappable, scroll event history, submit Fold/Call/Raise/All-in, rotate once during play, and verify all required table states remain legible without zooming. Capture screenshots before and after rotation.
  - [ ] **Pre-human test — Android Chrome:** on a physical supported Android phone, repeat the iPhone Safari flow in current Chrome. Include browser address-bar expanded and collapsed states, because both change the effective viewport height. Record any touch, clipping, contrast, text-size, or orientation issue with a screenshot and the device/browser details.
- [ ] **Human test:** play representative GUI hands through normal betting, all-in runout, showdown, elimination, tournament completion, and `player_quit`; record and correct any missing, ambiguous, clipped, overlapping, low-contrast, or aesthetically inconsistent information before release verification.

## Release verification

- [ ] Run all headless tests and resolve warnings or invariant failures.
- [ ] Verify GUI and CLI produce equivalent core outcomes for the same seed and scripted actions.
- [ ] Verify both GUI and CLI expose the optional startup overrides and produce identical validated core configuration from equivalent omissions and selections.
- [ ] Verify development addons and tests are excluded from release exports.
- [ ] Verify Compatibility rendering on target desktop platforms and basic mobile resizing.
- [ ] Review all user-facing text and documentation for consistency with the implemented game.
