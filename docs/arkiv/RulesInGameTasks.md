# In-game tournament rules tasks

Status: Complete — RIG-00–05 implemented and verified; GUI previews accepted.
Requested: 2026-10-29. Owner: presentation/adapter implementation with QA review.
Completed: 2026-10-31. No remaining tasks in this workstream.

Provide a short **Pokahdot tournament rules** reference from a **Rules** action
on the GUI Start screen and an interactive CLI **`rules`** command. Explain
Pokahdot's selected tournament, sizing and blind-progression rules. Do not teach
No Limit Texas Hold'em: omit hand rankings, dealing, betting-round tutorials,
strategy and a general glossary.

This is an independent workstream requested by the user. Implementation began
on 2026-10-31 against the running Start screen; it does not reopen the accepted
GUI restructuring baseline. Later GUI cutover must preserve this entry point
and its navigation/state contracts.

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
  between-hand commands. RIG-02 implements the GUI Rules page; RIG-03 implements
  the CLI rules command, including both startup prompt types.
- The CLI exits on tournament completion. Keep that behavior: no new post-game
  prompt, simulation command or `--rules` option is required.

## Content contract

The finalized title is **Pokahdot tournament rules**. One presentation-neutral
English document lives at `resources/presentation/tournament_rules.tres`,
using typed `TournamentRulesDocument` and `TournamentRulesSection` Resources in
`scripts/presentation/`. RIG-01 implements and verifies these files.
The source contains only the title and ordered sections (`id`, `title`, `body`),
without adapter-specific paragraphs, markup, scene references, I/O or game state.

Stable section order and IDs are `tournament`, `sizing`, `short_all_ins`,
`pot_shortcut`, `blinds`, `ending`. Section titles and bodies below are the
finalized RIG-00 copy. Both adapters must render them verbatim, allowing wrapping
and GUI styling only. Plain-text rendering is the document title, one blank
line, then each section title and body on separate lines, with one blank line
between sections and no trailing blank lines. Invalid content returns explicit
validation errors and no partial rendered document. `validate()` returns
`PackedStringArray` errors; `render_plain_text()` returns a typed `RenderResult`
with `text`, `errors` and `is_valid()`. Invalid results have empty text.

This fixed reference is not a live snapshot or rule calculator. Existing
`GameView` bounds and core validation remain authoritative. The following
copy is finalized for implementation; it does not imply visual/user acceptance.

> **Tournament.** One human plays bots at one table. Choose 2–9 players
> (2–7 on small-phone layouts). Defaults: 6 players, 1000 chips each, blinds
> 5/10. Everyone starts equally; participant count and starting stack stay fixed.
> Starting stacks and blinds are positive whole numbers up to 1,000,000;
> small blind cannot exceed big blind.
>
> **Bet and raise sizes.** Amounts are street totals. A full opening bet is
> at least one big blind. The first full preflop raise reaches at least twice the nominal
> big blind, even when posted short. Later full raises increase the current
> wager by at least the previous full bet/raise increment. Each full raise
> replaces that increment; reset it to one big blind each street. A full opening
> bet sets it. Maximum: all-in.
>
> **Short all-ins.** Smaller all-in increases change the call target, retain
> the increment and never reopen closed raise rights, even cumulatively.
> A short opening all-in retains the one-big-blind increment. Checking before
> it leaves raising closed. Unacted players retain their choices. With big blind 10 and opening all-in 5, a full raise
> reaches at least 15.
>
> **Pot shortcut.** With pot P and your existing street wager H, Pot adds P
> chips and submits H + P. Any call is included once. Available only when
> that exact total is legal and affordable; never clamped. This is a No Limit
> convenience, not Pot Limit sizing.
>
> **Blinds.** Levels count completed hands, not time. Starting with at least
> five active players means twice that count in hands; otherwise ten. The
> interval stays fixed despite eliminations. After settlement, the next level's
> first hand uses big blind × 1.25, rounded upward to even, with small blind
> half: 5/10 → 7/14 → 9/18. Blinds saturate at 500,000/1,000,000;
> level counters continue.
>
> **Ending.** Zero chips means permanent elimination; no rebuys. Last player
> with chips wins. Quitting ends immediately without settling the pot or
> declaring a winner. Chips have no monetary value.

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

- [x] **RIG-00 — Finalize the concise copy and shared content contract.**
  Status: Complete (2026-10-31). Mode: Tech Lead / Documentation.
  Evidence: copy checked against specification §§2, 4.1, 4.4–4.5 and current
  `TournamentConfig`/`ConfigResolver`; shared ownership and navigation contract
  recorded in `ARCHITECTURE.md`. `make docs-check` and `git diff --check` pass.
  Compare the proposed draft with the authority and accuracy table; finalize
  short sections and record the proposed shared-source/navigation decision as
  implemented guidance only when it lands. Check current startup defaults and
  limits without changing core rules. Define a stable title, ordered sections
  and plain-text rendering contract.
  Done: concise English copy covers every required topic, excludes Hold'em
  teaching, and the architecture records ownership without claiming future
  adapters are already implemented.

- [x] **RIG-01 — Implement the single content source and unit coverage.**
  Status: Complete (2026-10-31). Mode: Senior / QA.
  Evidence: typed Resources and authored document added; nine unit tests pass
  (139 assertions), including malformed documents and editorial boundaries.
  Existing betting-round, generated betting, Pot-target and blind-progression
  tests pass. Focused logs: `localtmp/rules-in-game/rig01-*.log`.
  GDScript lint/format, `make docs-check` and `git diff --check` pass.
  Add typed Resources and one authored document in the agreed presentation
  locations. Validate nonempty title/bodies, stable order, unique section IDs
  and an explicit invalid-document result. Do not introduce core UI/I/O,
  hidden-state access, duplicated rule calculations or another font.
  Done: GUI/CLI can consume identical plain content; tests cover malformed
  content and the chosen sizing/Pot/blind details, including the documented
  short-all-in and saturation boundaries. Existing core rule tests remain.

### Phase 2 — User-facing entry points

- [x] **RIG-02 — Add the separate GUI Rules page and Start navigation.**
  Status: Complete; user accepted Start/Rules previews on 2026-10-31.
  Mode: Senior / QA. Acceptance: “Accept and continue to RIG-03”.
  Evidence: existing startup tests pass 10/10 before and after integration;
  `test_gui_tournament_rules.gd` passes 8/8 tests (123 assertions), including
  real pointer/touch/keyboard navigation, reader scrolling, exact drafts/errors,
  focus, numeric transactions, hidden-signal guards, safe areas, rotation and
  platform-Back ownership/restoration. Tested native fixture sizes include
  360×720, 390×744/844, 780×360, 844×390, 1080×1920 and 1920×1080;
  smaller widths and browser/physical-device acceptance are not established.
  Twelve native Compatibility previews and their manifest are saved under
  `localtmp/gui-elements/rig02-review/`, covering Start, Rules and scrolled
  Ending at four portrait/landscape sizes. Focused logs are under
  `localtmp/rules-in-game/rig02-*`. `make docs-check`, scoped lint/format checks
  and `git diff --check` pass. Full `make check` passes before GUI integration
  (872 Godot tests, including RIG-01) and after it (880 Godot tests), with all
  Python suites, lint and format checks. All four `gui-current-invariant-gate`
  matrices pass before and after integration. Evidence:
  `localtmp/rules-in-game/{baseline,post}-{check,invariants}.log`.
  Independent content/code review found no actionable defects. User visual
  acceptance is recorded above; automated checks do not certify a browser or device.
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

- [x] **RIG-03 — Add the interactive CLI `rules` command and discovery.**
  Status: Complete (2026-10-31). Mode: Senior / QA.
  Evidence: typed informational command and shared `CliRulesReference` rendering
  work at startup choice/numeric, shell, human-turn and between-hand prompts.
  All 41 existing CLI unit tests pass before changes; all 50 existing/new CLI
  unit tests and five existing real-process tests pass afterward. New tests
  verify exact parsing, shared content/error handling, prompt/config retention,
  completion without reading, and no rules-triggered match view/action/advance.
  Lint/format, docs-check and diff-check pass. Evidence:
  `localtmp/rules-in-game/rig03-{before,after,rules,process}-tests.log`.
  Broader same-seed/transcript and cross-surface verification follows in RIG-04.
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

- [x] **RIG-04 — Verify both surfaces and state-preservation boundaries.**
  Status: Complete (2026-10-31). Mode: QA.
  Evidence: `tests/cli/test_rules_process.py` passes 8 tests across sixteen real
  process transcripts covering setup, numeric fields, partially edited/invalid
  configuration, repeated trimmed/case-insensitive requests, extra arguments,
  human turns, between hands, EOF/quit and natural completion with unread
  trailing input. Same-seed control/inspection transcripts preserve every
  state/action/card/configuration/history line after removing only exact
  shared-reference blocks and known repeated prompts; the two-hand fixture
  exercises both full history reads and incremental updates. A GUI assertion
  also proves the page and CLI helper reference the identical Resource.
  Existing GUI navigation/state tests and shared-document/parser/CLI unit
  coverage remain in place. Process inputs/options/stdout/stderr and logs are
  under `localtmp/rules-in-game/cli-rules-transcripts/`; focused results are in
  `localtmp/rules-in-game/rig04-process-tests.log` and
  `localtmp/rules-in-game/rig04-gui-shared-source.log`.
  Full `make check` passes (889 Godot tests and 227 Python tests, plus layout
  characterization, lint and format checks); all four GUI invariant matrices
  pass. Logs: `localtmp/rules-in-game/rig04-{check,invariants}.log`.
  Pre-refactoring checks are recorded in RIG-02; independent review found no
  actionable defects. Verification is native macOS/headless, with no new
  browser or physical-device claim.
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

- [x] **RIG-05 — Reconcile current documentation and close the workstream.**
  Status: Complete (2026-10-31). Mode: Documentation / QA with user.
  Evidence: root README, documentation index, product specification, architecture,
  GUI visual-testing guidance, running/testing guide and current developer
  references agree on the delivered GUI route and CLI command. User acceptance
  of the native previews is recorded in RIG-02; smaller widths and browser/device
  verification remain explicitly unclaimed. Archived records are preserved.
  `make docs-check` and `git diff --check` pass; final documentation evidence:
  `localtmp/rules-in-game/rig05-docs-check.log` and `rig05-final-docs.log`.
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

The original backlog was a planning artifact. RIG-00–01 provide the finalized
copy, architectural contract and tested shared Resources; RIG-02 implements the
GUI route with user-accepted native previews. RIG-03–04 deliver and verify the
CLI command and shared-state boundaries; RIG-05 reconciles current guidance.
All tasks are complete. Validation evidence is kept under ignored
`localtmp/rules-in-game/`; native visual acceptance does not certify browsers
or physical devices.
