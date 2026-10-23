# Possible Bot Tilt Concept

Status: Exploratory design note. This document is not yet a normative game or
architecture contract.

## 1. Purpose

This document describes a possible deterministic "player tilt" mechanism for
`StrategyDecisionModel`. Tilt represents a temporary behavioral response to
events during one tournament. It is not a permanent rewrite of a bot profile
and must not change poker rules, reveal private information, or reduce
simulation reproducibility.

The central distinction is:

- a `BotProfile` contains immutable traits that describe susceptibility to and
  recovery from tilt; and
- each configured `StrategyDecisionModel` owns private mutable tilt state for
  its seat and current tournament.

Legacy decision models do not need to support tilt. Simulation may continue to
use them as comparison benchmarks for evolved `StrategyDecisionModel`
profiles.

## 2. Proposed model

```text
Immutable BotProfile parameters
            +
recipient-safe public hand outcomes
            |
            v
private per-seat TiltState (0-100)
            |
            v
temporary effective strategy parameters
            |
            v
StrategyDecisionModel.choose_action()
```

The profile parameters remain unchanged throughout the tournament. Before
each decision, the model derives temporary effective values from the profile's
baseline strategy and current tilt state. All derived percentages are clamped
to the inclusive range 0 through 100.

Every seat must receive a fresh model instance and a fresh `TiltState` when a
tournament is constructed. Tilt is never shared between seats and resets at
the start of a new tournament.

## 3. Candidate profile traits

An initial version could add these bounded integer parameters to
`StrategyDecisionModelParameters`:

- `tilt_sensitivity` (`0-100`): how strongly a qualifying loss increases
  tilt;
- `tilt_recovery` (`0-100`): how quickly accumulated tilt decays after each
  completed hand; and
- `tilt_response` (`0-100`): the direction and strength of the behavioral
  response, where values below 50 become tighter and more passive, 50 is
  neutral, and values above 50 become looser and more aggressive.

These are candidate genes, not final parameter contracts. Their observable
effects must be validated before they are added to profile evolution. In
particular, a neutral response must not become a cost-free gene that evolution
can exploit while accumulating meaningless tilt state.

A later design may split `tilt_response` into independently measurable
looseness, aggression, and bluff responses. That should happen only if one
response axis cannot express useful and behaviorally distinct personalities.

## 4. Tilt-state transitions

The first implementation should update tilt only after normal hand settlement.
This gives every decision in one hand a stable tilt value and avoids coupling
state changes to incidental event ordering within a betting round.

Potential initial rules are:

- losing chips increases tilt in proportion to the loss measured in big
  blinds and the profile's `tilt_sensitivity`;
- winning or breaking even adds no loss pressure;
- `tilt_recovery` reduces tilt after every completed hand;
- current tilt is always clamped to `0-100`; and
- an aborted hand does not create a win, loss, or tilt update.

An illustrative formula is:

```text
loss_bb = max(0, hand_start_stack - hand_end_stack) / hand_big_blind
increase = loss_bb * tilt_sensitivity / 100
recovery = tilt_recovery / 10
tilt = clamp(tilt + increase - recovery, 0, 100)
```

The production formula should use documented integer or fixed-point rounding,
explicit overflow-safe bounds, and the big blind that applied to the completed
hand. Its constants require simulation calibration; the formula above is a
behavioral sketch rather than a final balance decision.

Possible later triggers include consecutive losing hands and losing a large
pot at a legitimately revealed showdown. Concepts such as a "bad beat" must
not inspect folded cards, unrevealed opponent cards, the deck, or any other
state unavailable to that bot.

The initial mechanism should not make a separate random roll to decide whether
the bot becomes tilted. Deterministic state transitions are easier to test,
replay, explain, and evolve. If randomness is later justified, it must use the
bot's injected RNG stream and be represented in decision traces.

## 5. Effect on strategy decisions

Tilt should modify the existing strategy parameters temporarily rather than
bypass `StrategyDecisionModel` with a separate action policy. For example, a
signed style shift can be derived from current tilt and `tilt_response`:

```text
style_shift = round(tilt * (tilt_response - 50) / 100)

effective_tight_vs_loose = clamp(tight_vs_loose + style_shift, 0, 100)
effective_passive_vs_aggressive =
    clamp(passive_vs_aggressive + style_shift, 0, 100)
effective_call_vs_raise = clamp(call_vs_raise + style_shift, 0, 100)
effective_bluff_rate = clamp(bluff_rate + bounded_bluff_shift, 0, 100)
```

Positive shifts model reckless or "spew" tilt. Negative shifts model fearful
or shutdown tilt. Bluff changes should be more tightly bounded than the other
style changes so high tilt does not automatically collapse into constant
bluffing.

Legal-action validation and fallback behavior remain unchanged. Tilt may
influence which legal action the model requests, but it cannot create new
actions, alter wagering limits, or mutate game state directly.

## 6. Observation contract and information safety

The current implementation forwards `PublicActionRecord` values to
`DecisionModel.observe()`. Action records alone do not provide a reliable
hand-settlement boundary or the observing seat's net result. Supporting tilt
therefore requires a richer recipient-safe observation contract.

The architecture already describes `PublicGameEvent` as the intended
immutable observation type for actions, public cards, pot awards,
eliminations, street changes, and other public outcomes. A hand-settlement
observation for tilt should provide only the information needed by the model,
such as:

- hand number;
- observing seat;
- that seat's stack at hand start and after settlement;
- the big blind used for that hand;
- whether that seat received a pot award; and
- showdown information that was legitimately revealed to that recipient.

`BotAgent` should forward each observation exactly once and in domain-event
order. The decision model must not retain live `Table`, `Player`,
`TournamentMatch`, or UI references. A typed recipient-safe event is preferred
over an untyped dictionary or direct access to simulation metrics.

## 7. Simulation observability

Simulation reports and bounded decision traces should make tilt behavior
auditable without exposing hidden cards. Candidate metrics include:

- average and maximum tilt by profile, matchup, seat, and regime;
- hands spent in documented low, medium, and high tilt bands;
- number and cause of tilt increases;
- average hands required to recover below each tilt threshold;
- VPIP, PFR, aggression factor, and bluff frequency by tilt band;
- invalid-action fallbacks by tilt band; and
- tournament outcomes following large losses or sustained high tilt.

A strategy-decision trace should record current tilt, the applicable baseline
parameters, derived effective parameters, and the public cause of the most
recent state transition. Ordinary game views and player-facing UI do not need
to expose an opponent's private tilt state.

## 8. Profile evolution

Tilt traits should not enter the evolutionary genome until controlled,
fixed-seed batches demonstrate distinct and repeatable behavioral effects. A
safe sequence is:

1. Implement tilt with fixed traits and deterministic state transitions.
2. Add unit tests for transitions, bounds, recovery, reset, and information
   safety.
3. Add simulation metrics and verify that each proposed trait changes an
   intended observable behavior.
4. Define profile-snapshot and manifest migration for the new fields.
5. Add the validated traits to generation, crossover, bounded mutation,
   lineage, and candidate-export artifacts.
6. Evaluate candidates across mirrored seats, stack depths, table sizes,
   legacy opponents, and historical champions.

Fitness should not reward tournament wins alone. Guardrails should reject
profiles that gain results through persistent maximum tilt, pathological
bluffing, invalid-action fallback behavior, or one narrow matchup. Behavioral
diversity may justify preserving both cautious and reckless tilt responses if
each remains legal, reproducible, and competitive.

## 9. Verification expectations

Unit and integration coverage should include:

- zero sensitivity never increases tilt;
- maximum sensitivity and large losses remain bounded at 100;
- recovery is deterministic and cannot reduce tilt below zero;
- aborted hands do not change tilt;
- a new tournament starts every model at zero tilt;
- profile Resources and configured parameter snapshots are never mutated;
- identical profiles, observations, and RNG seeds produce identical actions
  and tilt traces;
- different seats never share tilt state;
- unrevealed cards cannot influence a tilt transition;
- all tilt-adjusted actions remain legal or follow the existing fallback
  contract; and
- simulation reports remain reproducible and contain no private-card leakage.

## 10. Open decisions

Before implementation, the following choices need explicit acceptance and
calibration:

- whether only net chip loss or additional public outcomes can trigger tilt;
- whether recovery happens before or after applying a hand's loss pressure;
- whether wins actively reduce tilt beyond ordinary recovery;
- the integer/fixed-point formula and rounding rules;
- maximum per-hand tilt increase and maximum effective-parameter shifts;
- whether one response axis is sufficient or separate response genes are
  necessary; and
- whether a bot's tilt should ever be shown in the GUI or remain private
  strategy state.

The smallest useful version is deterministic net-loss pressure, deterministic
recovery, one response axis, private state, and simulation-only diagnostics.
This version can establish whether tilt adds meaningful behavior before the
profile genome and promotion workflow become more complex.
