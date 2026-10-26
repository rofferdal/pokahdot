# Correct Pot-Sized Bet and Raise Targets

Status: Automated implementation complete — physical/browser acceptance remains  
Started: 2026-10-26

## Scope

Pokahdot is No Limit Texas Hold'em. `Pot bet` and `Pot raise` are convenience
presets, not a Pot Limit game mode. They must produce a conventional pot-sized
wager while continuing to submit the core's existing **total wager for the
street**. This work must not change betting legality, the fixed-big-blind
minimum full-raise rule, action reopening, stack accounting, or side-pot rules.

The calculation must use only recipient-safe public state and remain outside
GUI node geometry. GUI, CLI, and simulation adapters must continue to submit
ordinary `PlayerAction` values through `BettingRound` validation.

## Confirmed defect

The GUI currently uses `pot_amount` itself as the total wager target for both
an unopened pot bet and a pot raise. That is correct for an unopened postflop
pot bet, where the player has no existing street wager and nothing to call.
It is too small when facing a wager because it omits both the call and the
growth of the pot caused by that call.

Define:

- `P`: pot before the player acts, including chips already committed;
- `H`: the player's existing wager on the current street;
- `C`: the additional call amount;
- `T`: the total wager target submitted to the core.

The conventional pot-sized target is:

```text
pot after call = P + C
T = H + C + pot after call
T = H + P + 2C
```

Examples:

| Situation | P | H | C | Correct total T | Current GUI total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Unopened pot bet | 20 | 0 | 0 | 20 | 20 |
| Raise facing 10 | 30 | 0 | 10 | 50 | 30 |
| Raise after already committing 5 | 30 | 5 | 5 | 45 | 30 |

An exact pot-sized shortcut is available only when `T` is within the existing
`minimum_wager_total` and `maximum_wager_total` bounds. If it is outside those
bounds, the Pot control remains unavailable; it must not silently call a
smaller wager “Pot.” The existing minimum and All-in controls remain the
explicit alternatives.

## Tasks

Tasks are ordered. Complete the first unchecked task before moving to the next
unless the user explicitly changes the order. Record failing-before and
passing-after evidence before checking implementation tasks.

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
- [ ] **Perform physical/browser acceptance.** Deploy one clean SHA and verify
  unopened pot bets, pot raises while facing a wager, raises after a blind or
  prior contribution, and insufficient-stack cases in the affected phone and
  desktop browsers. Record deployment provenance and examples here. Acceptance:
  the user confirms that displayed and committed pot-sized amounts are correct.

## Automated verification

Verified on 2026-10-26:

- 527/527 GUT tests with 17,451 assertions;
- 72/72 Python tests;
- GDScript lint and formatting checks;
- phone, iPad, desktop, and historical GUI invariant matrices.

The physical/browser acceptance task remains deliberately unchecked until a
clean deployment is available and the user reports the observed wager results.
