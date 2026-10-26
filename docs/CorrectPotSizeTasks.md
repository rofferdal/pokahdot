# Correct Pot-Sized Bet and Raise Targets

Status: Reopened — revise the shortcut so every Pot action doubles the pre-action pot
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

## Tasks

Tasks are ordered. Complete the first unchecked task before moving to the next
unless the user explicitly changes the order. Record failing-before and
passing-after evidence before checking implementation tasks.

### Completed work for the superseded contract

- [x] **Specify the pot-sized wager contract in normative documentation.** Add
  the `P`, `H`, `C`, and total-target formula above to
  [`ProjectDescription.md`](ProjectDescription.md), and reconcile the current
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

### Revised correction tasks

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
- [ ] **Repeat automated interface and layout verification.** Exercise phone
  portrait, tablet, small desktop, desktop, and applicable CLI/free-entry
  paths; then run the complete GUT and Python suites, lint, formatting, and all
  GUI invariant matrices. Acceptance: `Pot N` remains unclipped at the 20 px
  text floor and all automated checks pass with the revised amounts.
- [ ] **Perform physical/browser acceptance.** Deploy one clean SHA and verify
  unopened pot bets, pot raises while facing a wager, raises after a blind or
  prior contribution, and insufficient-stack cases in the affected phone and
  desktop browsers. Record deployment provenance and examples here. Acceptance:
  the user confirms that displayed and committed pot-sized amounts are correct.

## Previous automated verification (superseded formula)

Verified on 2026-10-26:

- 527/527 GUT tests with 17,451 assertions;
- 72/72 Python tests;
- GDScript lint and formatting checks;
- phone, iPad, desktop, and historical GUI invariant matrices.

These results verified the now-superseded `H + P + 2C` implementation. New
automated evidence must be recorded after the revised tasks pass. The
physical/browser acceptance task remains deliberately unchecked until a clean
deployment is available and the user reports the observed wager results.
