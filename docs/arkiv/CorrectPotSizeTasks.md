# Correct Pot-Sized Bet and Raise Targets

Status: Automated work complete — awaiting physical/browser acceptance
Started: 2026-10-26

## Scope

Pokahdot is No Limit Texas Hold'em. `Pot bet` and `Pot raise` are product-defined
convenience presets, not a Pot Limit game mode. They must double the displayed
pre-action pot while continuing to submit the core's existing **total wager for
the street**. This work must not change betting legality, the fixed-big-blind
minimum full-raise rule, action reopening, stack accounting, or side-pot rules.

The calculation must use only recipient-safe public state and remain outside
GUI node geometry. GUI, CLI, and simulation adapters must continue to submit
ordinary `PlayerAction` values through `BettingRound` validation.

## Previously implemented contract (superseded)

The first correction used the conventional Pot Limit raise calculation: call
first, then raise by the size of the post-call pot. That interpretation is now
superseded by the product requirement below because it makes the final pot more
than twice the displayed pre-action pot when a call is due.

Define:

- `P`: pot before the player acts, including chips already committed;
- `H`: the player's existing wager on the current street;
- `C`: the additional call amount;
- `T`: the total wager target submitted to the core.

The superseded target is:

```text
pot after call = P + C
T = H + C + pot after call
T = H + P + 2C
```

Examples:

| Situation | P | H | C | Superseded total T | Pot after action |
| --- | ---: | ---: | ---: | ---: | ---: |
| Unopened pot bet | 20 | 0 | 0 | 20 | 40 |
| Raise facing 10 | 30 | 0 | 10 | 50 | 80 |
| Raise after already committing 5 | 30 | 5 | 5 | 45 | 70 |

Under that implementation, the shortcut was available only when `T` was within
the existing `minimum_wager_total` and `maximum_wager_total` bounds. If it was
outside those bounds, the Pot control remained unavailable; it did not silently
call a smaller wager “Pot.” The existing minimum and All-in controls remained
the explicit alternatives.

## Revised product contract: double the displayed pot

After either a Pot bet or a Pot raise, the pot must be exactly twice its
displayed pre-action value. The player's additional contribution must therefore
equal `P`, regardless of how that contribution is divided between calling and
raising. Because the core accepts a total wager for the street, the required
target is:

```text
additional contribution = T - H = P
T = H + P
pot after action = P + (T - H) = 2P
```

When a call is due, the contribution consists of call `C` plus a raise increment
of `P - C`. `C` does not need to be added again to the target. The ordinary
betting-round minimum, maximum, and action-reopening rules remain authoritative.
If `H + P` is outside the legal wager-total range, the Pot control must remain
unavailable rather than silently clamp or relabel another amount as Pot.

Examples:

| Situation | P | H | C | Revised total T | Added chips | Pot after action |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Unopened pot bet | 20 | 0 | 0 | 20 | 20 | 40 |
| Raise facing 10 | 30 | 0 | 10 | 30 | 30 | 60 |
| Raise after already committing 5 | 30 | 5 | 5 | 35 | 30 | 60 |

## Latest clarification: observe Pot, then add exactly that amount

The shortcut must begin with the number visibly shown in the Pot field at the
moment the player presses it. If that observed number is `P`, the player must
put exactly `P` additional chips into the pot. This is deliberately simple at
the user boundary: observe `Pot: P`, then bet or raise by `P`.

The core API still accepts a **total wager for the current street**, so the GUI
must translate the visible contribution into a different internal number when
the hero has already committed chips:

```text
visible Pot shortcut amount = P
additional chips committed = P
core street-total target T = H + P
```

For example, with `Pot: 30` and an existing hero wager of 5, the Pot control
must continue to show 30, the player must add 30 chips, and the core must
receive a street-total target of 35. Showing `Pot 35` conflates the internal
target with the amount observed by the player and makes the shortcut appear
incorrect even if the final contribution is 30.

This is a modest implementation change, but it needs explicit end-to-end
evidence because the current `PotWagerTargetResult.total` is reused for the
button text, keypad preset, availability decision, and submitted action. The
next correction must represent the visible contribution and internal target as
separate typed values rather than relying on callers to remember which meaning
one integer has.

## Tasks

Tasks are ordered. Complete the first unchecked task before moving to the next
unless the user explicitly changes the order. Record failing-before and
passing-after evidence before checking implementation tasks.

### Completed work for the superseded contract

- [x] **Specify the pot-sized wager contract in normative documentation.** Add
  the `P`, `H`, `C`, and total-target formula above to
  [`ProjectDescription.md`](../ProjectDescription.md), and reconcile the current
  Pot shortcut descriptions in `README.md`, `docs/ARCHITECTURE.md`, and affected
  `devdocs/` references. State explicitly that this is a No Limit convenience
  preset and that wager amounts are street totals, not additional chips.
  Acceptance: bet, raise, short-stack, minimum, and maximum behavior is
  unambiguous and no current document still says that a pot raise simply sends
  the displayed pre-action pot amount.
- [x] **Add failing unit tests for the shared calculation.** Cover an unopened
  pot bet, a raise with no prior hero wager, a raise after a blind or earlier
  street contribution, exact minimum and maximum boundaries, below-minimum and
  above-stack results, and integer-overflow protection. Acceptance: the raise
  examples above fail against the old `pot_amount` target while the unopened
  bet example demonstrates the unchanged case.
- [x] **Implement one typed, presentation-independent pot-target calculator.**
  Derive the raw total from public pot, existing hero street wager, and call
  amount using checked integer arithmetic. Return an explicit unavailable
  result for invalid or overflowing inputs instead of wrapping, mutating game
  state, or embedding GUI behavior in `scripts/core/`. Acceptance: all formula
  and boundary tests pass, and callers cannot confuse a total wager with an
  additional contribution.
- [x] **Use the corrected target in every human GUI Pot control.** Replace the
  raw `displayed_pot_amount` target used by the desktop/tablet button and phone
  wager keypad. Use the same resolved target for the label, enabled state, and
  submitted `PlayerAction`; never display one amount and submit another.
  Acceptance: the 30-pot/10-call example submits `Raise to 50`, unopened
  20-pot betting still submits `Bet to 20`, and unavailable exact-pot targets
  leave the control disabled without affecting Min, free entry, or All-in.
- [x] **Audit strategic-agent pot-fraction sizing.** Check the half-pot and
  one-pot branches in `StrategyDecisionModel` against the same total-target
  semantics. Reuse the shared calculation where the strategy promises a
  pot-sized action, or document and test any intentionally different fraction
  model. Acceptance: human and bot code cannot independently implement
  contradictory meanings of “pot-sized,” and recipient privacy is unchanged.
- [x] **Add live betting-round regressions.** Exercise pot bets and raises
  through a real `TournamentMatch`, including blinds, an existing hero wager,
  short stacks, all-in limits, and repeated raises. Assert the submitted public
  action amount, chips committed, new `current_bet`, pot growth, legal-action
  reopening, and chip conservation. Acceptance: the shortcut changes only its
  target calculation and all existing No Limit validation remains authoritative.
- [x] **Verify every interface and layout profile.** Run the corrected shortcut
  from phone portrait, tablet, small desktop, desktop, and CLI/free-entry
  equivalents where applicable. Ensure calculated amounts fit without clipping
  and remain understandable as totals. Acceptance: automated GUI invariants,
  full tests, lint, and formatting pass without weakening the 20 px text floor
  or current touch-target requirements.

### Completed revised correction attempt (presentation contract now superseded)

- [x] **Replace the superseded contract in normative documentation.** Update
  `docs/ProjectDescription.md`, `README.md`, `docs/ARCHITECTURE.md`, and the
  affected `devdocs/` references to define the product's Pot shortcut by its
  observable invariant: it adds the displayed pre-action pot and leaves a pot
  of `2P`. Preserve the core's street-total convention by documenting
  `T = H + P`, and explicitly distinguish this product rule from the
  conventional post-call Pot Limit raise formula. Acceptance: no current
  document still prescribes `H + P + 2C` for the GUI shortcut.
- [x] **Add failing tests for the revised doubling rule.** Change the shared
  calculator expectations so `P=30, H=0, C=10` targets 30 and `P=30, H=5,
  C=5` targets 35; retain the unopened `P=20` target of 20. Assert in each case
  that `P + (T - H) == 2P`. Retain exact-boundary, unavailable-target, invalid
  input, and checked-overflow coverage for `H + P`. Acceptance: the raise cases
  fail against the currently implemented post-call formula before production
  code changes.
- [x] **Refactor the typed shared calculator to return `H + P`.** Remove the
  call amount from the mathematical target while retaining any call value
  needed only for diagnostics or explicit input validation. Keep the result
  presentation-independent and preserve explicit invalid, overflow, and
  outside-legal-range outcomes. Acceptance: callers receive a street total,
  never a chip delta, and the revised calculator tests pass without weakening
  `BettingRound` validation.
- [x] **Use the revised result in every human Pot control.** Ensure the shared
  table button and phone wager keypad use the same `H + P` value for text,
  enabled state, and submission. Preserve Min, free entry, and All-in as
  separate alternatives. Acceptance: a displayed pot of 30 facing a call of
  10 displays and submits `Pot 30`, while a hero with 5 already committed
  displays and submits the street total 35.
- [x] **Reconcile strategic-agent pot fractions with the revised product
  meaning.** Prefer deriving one-pot and half-pot additions from the pre-action
  pot (`H + P` and `H + floor(P / 2)`) so human and bot code share one meaning.
  If strategy intentionally retains post-call sizing, document that as a
  distinct strategy policy and do not call it the GUI Pot shortcut. Acceptance:
  tests make the chosen distinction explicit and recipient privacy is unchanged.
- [x] **Replace the live-match regressions with final-pot assertions.** Through
  real `TournamentMatch` states, cover unopened bets, facing a wager, an
  existing hero wager, blinds, repeated raises, minimum-raise rejection, short
  stacks, and All-in limits. Capture pre-action `P` and assert the submitted
  total `H + P`, added chips `P`, final pot `2P`, new current bet, legal-action
  reopening, and chip conservation. Acceptance: the 30-pot/10-call case ends
  at 60 rather than 80, and illegal exact targets remain disabled rather than
  clamped.
- [x] **Repeat automated interface and layout verification.** Exercise phone
  portrait, tablet, small desktop, desktop, and applicable CLI/free-entry
  paths; then run the complete GUT and Python suites, lint, formatting, and all
  GUI invariant matrices. Acceptance: `Pot N` remains unclipped at the 20 px
  text floor and all automated checks pass with the revised amounts.

### CLI Pot bet and raise commands

- [x] **Add failing CLI contract tests for `potbet` and `potraise`.** Extend
  parser, help, legal-action rendering, and live-match coverage before changing
  production code. Require the exact single-word commands `potbet` and
  `potraise`; do not require or accept a numeric argument. In the rendered
  `Legal actions` line, list only the command appropriate to the current wager
  kind and show the observable Pot contribution in parentheses in the same
  style as Call, for example `potbet (20)` or `potraise (30)`. Acceptance: the
  tests fail because neither command nor its amount is currently exposed, while
  existing `bet <total>` and `raise <total>` behavior remains covered.
- [x] **Represent Pot commands as CLI intents and resolve them from the current
  view.** Keep parsing independent of match state: parse `potbet` and
  `potraise` into explicit command intents, then have the active match loop use
  the shared typed Pot-target calculator with the current recipient-safe
  `GameView`. Submit the resulting ordinary `PlayerAction.bet_to(T)` or
  `PlayerAction.raise_to(T)`, where the displayed contribution is `P` and the
  core street-total target is `T = H + P`. Do not duplicate the formula in the
  CLI or move presentation concerns into `scripts/core/`. Acceptance: command
  execution observes the same availability, overflow, minimum, maximum, and
  No Limit validation rules as the GUI controls.
- [x] **Expose only executable Pot commands in CLI help and turn output.** Add
  `potbet` and `potraise` to `help`, and extend the current turn's available-
  command rendering so `potbet (P)` appears only when Bet and the exact Pot
  target are available, while `potraise (P)` appears only when Raise and the
  exact Pot target are available. If the target is unavailable or the command
  does not match the legal wager kind, keep the command recognized but reject
  it with a specific, actionable message rather than treating it as unknown or
  silently clamping it. Acceptance: the amount beside the available command is
  the same displayed Pot value used by the shortcut, analogous to `call (C)`,
  and is not the internal `H + P` street total when `H > 0`.
- [x] **Verify CLI Pot commands through settlement.** Cover unopened betting,
  a raise facing a wager, a posted blind or earlier hero contribution, repeated
  raises, exact legal boundaries, below-minimum targets, insufficient stacks,
  and command use outside an active human turn. For successful actions, assert
  displayed command amount `P`, submitted total `H + P`, stack delta `P`, final
  pot `2P`, current bet, action reopening, chip conservation, and action-history
  wording. Acceptance: CLI and GUI produce identical settlement from the same
  public state, and the complete CLI, GUT, and Python suites pass.

### Latest correction tasks: literal observed-Pot contribution

- [x] **Capture the failing physical case as a complete value trace.** Record
  the visible Pot amount `P`, hero's existing street wager `H`, call amount
  `C`, minimum and maximum totals, Pot-control text, submitted public action,
  chips removed from the hero stack, and pot after the action. Add the same
  state as a deterministic real-`TournamentMatch` regression. Acceptance: the
  regression proves which boundary is wrong instead of inferring correctness
  only from the calculator result or final pot.

  Recorded deterministic trace on 2026-10-26: visible `Pot: 80`, `H=20`,
  `C=20`, minimum total `50`, maximum total `490`, and the incorrect control
  text `Pot 100`. Pressing it still submitted `Raise to 100`, removed exactly
  `80` chips, and produced a pot of `160`. The real-`TournamentMatch`
  regression therefore isolates presentation as the failing boundary. Before
  production changes, the focused file passed 34/35 tests and 326/327
  assertions; its only failure was `Pot 100` versus the required `Pot 80`.
- [x] **Give the shared result separate contribution and total fields.** Replace
  the ambiguous single `total` result with a typed result that exposes the
  observed shortcut contribution `P` and the core street-total target `H + P`
  independently, together with availability and failure reason. Retain checked
  overflow, invalid-input, minimum-total, and maximum-total handling.
  Acceptance: no caller can accidentally present `H + P` as the observed Pot
  amount or submit `P` where the core requires a street total.
- [x] **Make every Pot control display and preserve the observed Pot amount.**
  Desktop, tablet, phone, and the phone keypad must show `Pot P`, using the same
  `P` visible in the Pot field for that bound view. Pressing the control must
  submit the paired internal target `H + P`; opening or closing the keypad must
  not recalculate from a later or unrelated view. Acceptance: `Pot: 30` always
  produces a `Pot 30` control, including when `H=5`, while the submitted total
  is 35 and the added chips are 30.
- [x] **Clarify action feedback without changing the core action contract.**
  Audit the human action badge, opponent action badge, event text, and action
  history rendering so a street-total record is not mislabeled as newly added
  chips. Use explicit wording such as `Raise to T` when showing the core total,
  or show the added contribution only when it is derived from before/after
  public state. Acceptance: the UI never claims that a player added `H + P`
  when the stack delta was `P`.
- [x] **Add click-to-settlement regressions for bets and raises.** In real match
  states, snapshot the displayed Pot label immediately before the click and
  cover an unopened bet, facing a wager, a posted blind, an earlier wager in
  the same street, repeated raises, exact minimum/maximum boundaries, below-
  minimum targets, and insufficient stacks. Assert control text `P`, submitted
  total `H + P`, stack delta `P`, final pot `2P`, current bet, action reopening,
  and chip conservation. Acceptance: tests fail if any layer substitutes the
  call amount, current wager, minimum raise, or cached prior pot for `P`.
- [x] **Repeat automated verification with distinct display and submission
  assertions.** Run the complete GUT and Python suites, lint, formatting, and
  phone, iPad, desktop, and historical invariant matrices. Add explicit GUI
  assertions for both numbers when `H > 0`: the visible shortcut remains `P`
  while the submitted street total is `H + P`.

  Verified on 2026-10-26: 544/544 GUT tests with 17,692 assertions, 72/72
  Python tests, full GDScript lint and formatting checks, whitespace validation,
  and the phone, iPad, desktop, and historical GUI invariant matrices all
  passed. The repeated-raise regression explicitly observes `Pot 80`, stages
  and submits street total `100`, and verifies an `80`-chip stack delta.
- [x] **Perform physical/browser acceptance.** Deploy one clean SHA and verify
  the recorded failing example plus unopened bets, raises facing a wager,
  raises after a blind or prior contribution, repeated raises, and insufficient-
  stack cases on affected phone and desktop browsers. Record the SHA and the
  observed before/after values here. Acceptance: the user confirms that the
  Pot control shows the observed Pot amount and that exactly that many chips
  are added.

## Historical automated verification

CLI Pot-command red phase on 2026-10-26: the focused parser, help, renderer,
and live-match suite produced the expected 5 failing tests with 31/36 tests and
424/434 assertions passing before production changes. Failures were limited to
the missing Pot intent kinds, help entry, legal-action amount, and live command
execution; existing numeric `bet <total>` and `raise <total>` coverage passed.

CLI Pot-command passing phase on 2026-10-26: 543/543 GUT tests with 17,654
assertions and 72/72 Python tests passed. Focused GDScript lint, formatting, and
whitespace validation also passed. Live CLI regressions cover the observed Pot
amount, submitted street total, stack delta, doubled pot, current bet, action
reopening, chip conservation, history wording, unavailable targets, and use
outside an active turn.

Verified on 2026-10-26:

- 532/532 GUT tests with 17,534 assertions;
- 72/72 Python tests;
- GDScript lint and formatting checks;
- phone, iPad, desktop, and historical GUI invariant matrices.

Focused revised-contract verification also passed 51/51 tests with 449
assertions across the shared target calculator, strategic sizing, real-match
GUI actions, and Web-font amount rendering. This evidence predates the latest
display-versus-submission clarification and must be repeated after the new
tasks are implemented. Physical/browser acceptance remains deliberately
unchecked until a clean deployment is available and the user reports the
observed wager results.
