# In-game tournament rules tasks

Status: Planned — implementation has not started.
Requested: 2026-10-29. Owner: presentation/adapter implementation with QA review.
First implementation task: RIG-00. All implementation checkboxes remain open.

Provide a short **Pokahdot tournament rules** reference from a **Rules** action
on the GUI Start screen and an interactive CLI **`rules`** command. Explain
Pokahdot's selected tournament, sizing and blind-progression rules. Do not teach
No Limit Texas Hold'em: omit hand rankings, dealing, betting-round tutorials,
strategy and a general glossary.

This is an independent workstream requested by the user. Creating this plan
does not start its implementation, reorder the GUI restructuring backlog or
accept that work's pending visual previews. Integrate with the running Start
screen; do not wait for the GUI rewrite. Later GUI cutover must preserve this
entry point and its navigation/state contracts.

## Authority and inspected implementation

- [ProjectDescription.md](ProjectDescription.md) is the rule authority;
  [ARCHITECTURE.md](ARCHITECTURE.md) owns adapter and presentation boundaries.
  This reference must describe those rules without changing them.
- `StartupConfigController` in `scripts/gui/startup_config_controller.gd` owns
  the existing form in `scenes/main.tscn`. It creates a match only on Start.
  Its tournament-return path resets defaults, so it must not be reused for
  returning from Rules.
- `StartupConfigPrompt` has separate setup-choice and numeric-field reads.
  `CommandParser` / `CliCommand` / `CliCommandLoop` own shell, human-turn and
  between-hand commands. There is currently no rules command or GUI rules page.
- The CLI exits on tournament completion. Keep that behavior: no new post-game
  prompt, simulation command or `--rules` option is required.

## Content contract

Use one shared, presentation-neutral English content source outside
`scripts/core/`, `scripts/gui/` and `scripts/cli/`. Proposed implementation:
typed document/section Resources under `scripts/presentation/`, with the single
authored document under `resources/presentation/`. GUI and CLI render the same
section titles and bodies, without duplicated adapter-specific rule paragraphs,
GUI markup, scene references or terminal I/O in that source. These locations
and types are proposed; record their final ownership in the architecture when
implementing RIG-00. No new presentation framework is needed.

The document is a fixed product reference, not a live tournament snapshot or
rule calculator. Existing `GameView` bounds and core validation remain
authoritative during play. Keep the main copy around 250–350 words and use
short sections. The following is a proposed editorial draft, not implemented
or user-accepted copy:

> **Tournament.** One human plays bots in a single-table tournament. Choose
> 2–9 players (2–7 on phone layouts). Defaults are 6 players, 1000 chips each
> and blinds 5/10. Everyone starts equally; player count and starting stack
> stay fixed. Starting stacks and blinds are positive whole numbers up to
> 1,000,000; the small blind cannot exceed the big blind.
>
> **Bet and raise sizes.** Amounts are totals for the current street. A full
> opening bet is at least one big blind; the first full preflop raise reaches
> at least twice the nominal big blind, even if that blind was posted short.
> Later full raises increase the current wager by at least the previous full
> bet/raise increment. Reset the increment each street; a full opening bet
> sets it. The maximum is all-in.
>
> **Short all-ins.** A smaller all-in increase is allowed but does not change
> that increment or reopen closed raise rights, even cumulatively. Checking
> before a short opening all-in also leaves raising closed. A short opening
> all-in keeps the minimum increment at one big blind.
>
> **Pot shortcut.** With pot P and your existing street wager H, Pot adds P
> chips and submits total H + P. Any call is already included. This No Limit
> convenience is available only when that exact total is legal; it is not a
> Pot Limit calculation.
>
> **Blinds.** Levels count completed hands, not time. A level starting with
> at least five active players lasts twice that player count in hands;
> otherwise it lasts ten. Its length stays fixed despite eliminations.
> After a level ends, the next hand uses big blind × 1.25, rounded up to an even
> integer, and small blind half of that. The cap is 500,000/1,000,000;
> level counters continue there.
>
> **Ending.** Zero chips means permanent elimination, with no rebuys.
> Last player with chips wins. Quitting ends the tournament immediately
> without settling the current pot or declaring a winner. Chips have no
> monetary value.

### Editorial accuracy checks

| Topic | Required meaning / source |
| --- | --- |
| Setup and ending | Specification §§2, 4.1, 4.4: exactly one human; equal positive integer starting stacks, defaults and limits; immutable count/starting stack; permanent elimination, no rebuy, last survivor; voluntary quit has no settlement/winner. The phone limit is a presentation limit, never a count clamp on resize. |
| Full sizing | §4.5: street-total amounts; increment is new total minus previous current wager, not chips added by a player; initialize/reset to one BB, opening full bet sets it, each full raise replaces it. Nominal preflop BB applies even when posted short. |
| Short all-ins | §4.5: short increases update the call target, retain the full increment and never cumulatively restore closed rights. Unacted players retain their core-authorized choices. With BB 10 and opening all-in 5, the next full raise reaches 15; checking before that opening does not restore raising. |
| Pot shortcut | §4.5: visible contribution P, distinct target H + P, call included once, exact inclusive legal range only; unavailable rather than clamped to Minimum/All-in. Do not substitute the conventional Pot Limit H + P + 2C formula. |
| Blind schedule | §4.1: capture active count at level start; ≥5 means 2N completed hands, otherwise 10; interval remains fixed through eliminations. Advance after settlement/elimination and before next hand. BB rounds 125% upward to even, SB becomes half; 5/10 → 7/14 → 9/18; saturate at 500,000/1,000,000 while level counting continues. |

These checks guide editing and tests; they are not extra tutorial text to
append to the player-facing page. If concision makes a statement ambiguous,
rewrite it rather than silently changing the rule.

## Ordered implementation backlog

Complete and verify one task before the next. Do not mark implementation or
visual acceptance complete merely because this plan exists.

### Phase 1 — Shared reference content

- [ ] **RIG-00 — Finalize the concise copy and shared content contract.**
  Status: Not started. Mode: Tech Lead / Documentation.
  Compare the proposed draft with the authority and accuracy table; finalize
  short sections and record the proposed shared-source/navigation decision as
  implemented guidance only when it lands. Check current startup defaults and
  limits without changing core rules. Define a stable title, ordered sections
  and plain-text rendering contract.
  Done: concise English copy covers every required topic, excludes Hold'em
  teaching, and the architecture records ownership without claiming future
  adapters are already implemented.

- [ ] **RIG-01 — Implement the single content source and unit coverage.**
  Status: Not started. Mode: Senior / QA.
  Add typed Resources and one authored document in the agreed presentation
  locations. Validate nonempty title/bodies, stable order, unique section IDs
  and an explicit invalid-document result. Do not introduce core UI/I/O,
  hidden-state access, duplicated rule calculations or another font.
  Done: GUI/CLI can consume identical plain content; tests cover malformed
  content and the chosen sizing/Pot/blind details, including the documented
  short-all-in and saturation boundaries. Existing core rule tests remain.

### Phase 2 — User-facing entry points

- [ ] **RIG-02 — Add the separate GUI Rules page and Start navigation.**
  Status: Not started. Mode: Senior / QA.
  Add a reachable Rules action to the running Start form and an authored
  in-app Control page with Back. Keep it outside the disposable table layout
  subtree so later cutover can preserve it. Render the shared content using
  the existing viewport adapter, containers and theme. Rules body text is
  at least 20 logical/CSS px; actions have ≥48×48 allocations; use only the
  built-in default font. A scrollable rules body is allowed, with Back always
  reachable outside it; the Start form retains its no-scroll contract.
  Preserve exact form drafts, legacy-bot choice, validation display and return
  focus. Opening/closing Rules must not validate/start/reset a tournament,
  consume RNG or advance play. Keyboard cancel/back returns to Start. Keep
  the numeric keypad modal: Rules must not bypass it or alter accepted
  Cancel/Done draft semantics.
  Done: pointer, touch and keyboard navigation work across measured small/
  large portrait/landscape space and safe-area changes, with unchanged drafts,
  no match construction and restored focus. New Start/Rules design captures
  are saved under `localtmp/gui-elements/` and shown for user acceptance before
  continuing beyond that visual checkpoint; automated fit is not device acceptance.

- [ ] **RIG-03 — Add the interactive CLI `rules` command and discovery.**
  Status: Not started. Mode: Senior / QA.
  Add a typed informational command through `CliCommand` / `CommandParser`
  and handle it in shell-only, human-turn and between-hand loops. Also support
  it at startup choice and numeric configuration prompts, printing the shared
  content before repeating the same prompt with prior edits intact. Advertise
  it in relevant prompts, command help and startup usage; do not add a flag
  or a new post-completion input loop. Match existing trimmed, case-insensitive
  exact-command parsing; extra arguments remain recoverable invalid input.
  Done: `rules` prints readable shared plain text without constructing a match,
  submitting an action, advancing a hand, consuming RNG, mutating configuration,
  or consuming the incremental-history cursor. Completion/EOF/quit exit
  behavior and existing invalid-command recovery remain intact.

### Phase 3 — Integration, current docs and acceptance

- [ ] **RIG-04 — Verify both surfaces and state-preservation boundaries.**
  Status: Not started. Mode: QA.
  Add unit/parser tests and real CLI process transcripts covering `rules` before
  creation, during partially edited/invalid configuration, during a human turn,
  between hands, repeated requests, whitespace/case, extra arguments and EOF/quit
  after reading. Compare same-seed actions with/without inspection to prove no
  advancement/RNG changes. Preserve all existing command contracts. GUI tests
  cover actual Rules/Back activation, unchanged valid/invalid draft strings,
  modal blocking, scroll reachability, focus restoration, resize/rotation and
  backing out before starting normally. Assert that both surfaces use the same
  document rather than duplicated prose.
  Done: focused tests pass; full `make check` and
  `make gui-current-invariant-gate` pass before/after adapter refactoring. Use
  `GODOT=/Applications/Godot.app/Contents/MacOS/Godot` locally where needed.
  Capture logs/transcripts under `localtmp/`; claim only tested environments.

- [ ] **RIG-05 — Reconcile current documentation and close the workstream.**
  Status: Not started. Mode: Documentation / QA with user.
  Update repository-root `README.md`, `docs/README.md`, current product/UI and
  architecture guidance, `docs/GUI_VISUAL_TESTING.md` and
  `devdocs/how-to/running-and-testing.md` for the delivered Rules route/command.
  Review other affected current `docs/`/`devdocs/` documents; preserve archived
  records. Keep general poker rules authoritative in the product specification,
  and document commands only after they work. Record GUI acceptance and any
  untested device limitations separately from automated checks.
  Done: `make docs-check` and `git diff --check` pass; commands/links agree,
  implementation evidence exists for every checked task, and requested visual
  acceptance is recorded. Do not imply acceptance of unrelated GUI work.

## Planning record

This backlog and its index link are the requested planning artifact only.
No rules content source, page, command, tests or architecture change has been
implemented by creating this document. Documentation validation evidence is
kept under ignored `localtmp/rules-in-game-plan/`.
