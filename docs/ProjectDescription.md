# Pokahdot — Product Specification

This document is the normative source for what Pokahdot must build. Implement
the rules stated here rather than assumptions from poker variants that are not
specified. If this document conflicts with `README.md`, this document wins.

## 1. Goal

Pokahdot is a **No Limit Texas Hold'em** game built with Godot 4, GDScript, and
the Compatibility renderer. One player is human and the remaining players are
automated agents with replaceable decision logic.

The same game core drives:

- the graphical interface (`scenes/`, `scripts/gui/`);
- the interactive terminal interface (`scripts/cli/`); and
- non-interactive, all-bot simulation (`scripts/simulation/`).

The core (`scripts/core/`) must not know about `Control` nodes, scenes, stdin,
or stdout. Only the dedicated simulation composition path may create an
all-bot tournament; normal GUI and interactive CLI play require exactly one
human.

## 2. Version 1: single-table tournament

Version 1 is a **single-table No Limit Texas Hold'em tournament**, not a cash
game. Every participant starts with the same number of chips, and play
continues hand by hand until only one participant has chips. Chips are game
state only: v1 has no money, buy-in, cash-out, prize payout, monetary return,
or rebuy.

- At startup, the human may choose the participant count, common starting
  stack, starting small blind, and starting big blind. Every field has a
  default and is optional, so a tournament can start without user-supplied
  values. Participant count and starting stack remain fixed; blinds follow
  the hand-based progression in section 4.1.
- A participant who loses all chips is permanently eliminated.
- Blinds increase according to the fixed hand-based blind-level schedule;
  there is no timed blind clock.
- The last participant with chips wins.
- The human may quit at any time. The tournament then ends without a winner.

## 3. Version 1 non-goals

- Omaha, Short Deck, Stud, Limit, and Pot Limit.
- Rebuys, straddles, antes, and bomb pots.
- Networking, online multiplayer, real money, and prize payouts.
- Rake.
- Action timers. Human input may wait indefinitely; bots respond
  synchronously.
- Alternate blind schedules. Simulation may vary starting blinds, but uses
  the same fixed progression as product play.

## 4. Poker rules (normative)

### 4.1 Table, stacks, and blind progression

- Startup accepts **2–9 tournament participants**. The default is **6 seats**
  (1 human and 5 bots).
- Chips are integers; fractional chips are not permitted.
- Startup accepts positive integer starting small and big blinds, with the
  small blind no greater than the big blind. Defaults are **small blind = 5**
  and **big blind = 10**. They define the first blind level.
- Startup accepts a positive integer starting stack. The default is **1000**
  (100 starting big blinds). The resolved value is applied equally to every
  participant; stacks then change only through ordinary play.
- A player whose stack reaches 0 is marked `busted` and takes no part in later
  hands.
- The tournament ends when one player has chips; that player wins.

Blind-level state is owned by the game core and updates after a hand has
completed, settlement and elimination have occurred, and before the next hand
starts. The completed hand retains its blinds; an increase applies to the next
hand. At the beginning of each level,
`active_player_count_at_level_start` is captured. A level that begins with
five or more active players lasts
`active_player_count_at_level_start * 2` completed hands. A level that begins
with fewer than five active players lasts 10 completed hands. The interval is
fixed for the entire level even if the active-player count changes; the next
level captures a new count.

At each increase, the new big blind is the smallest even integer greater than
or equal to `current_big_blind * 1.25` (125%, rounded upward to the nearest
even integer). The new small blind is exactly half the new big blind. Examples:
5/10 becomes 7/14 (`10 * 1.25 = 12.5`, rounded up to 14), and 7/14 becomes
9/18 (`14 * 1.25 = 17.5`, rounded up to 18).

### 4.2 Cards

- One 52-card deck; no jokers.
- Suits: clubs, diamonds, hearts, and spades.
- Ranks: 2–9, T, J, Q, K, A. Ace is high except in the A-2-3-4-5 wheel.
- No burn cards. Shuffle before each hand, then deal directly.
- Each player receives two private hole cards.
- Community cards are a three-card flop, one-card turn, and one-card river,
  all visible to every player.

### 4.3 Positions

- The button (`dealer`) moves one active seat clockwise after every hand,
  skipping `busted` players.
- The small blind is left of the button; the big blind is left of the small
  blind.
- Heads-up, the button posts the small blind and acts **first preflop** and
  **last postflop**.

### 4.4 Hand flow

1. Select a random initial button from active participants; on later hands,
   move it clockwise to the next active seat.
2. Reset the pot, community cards, and hole cards.
3. Shuffle the deck.
4. Post small and big blinds. A player with less than the blind posts the
   remaining stack and is all-in.
5. Deal two hole cards to each active player, clockwise from the small blind.
6. Run preflop betting.
7. If more than one player has not folded, deal the flop and run betting.
8. Repeat for the turn and river.
9. If a betting round leaves one player, that player wins the pot without a
   showdown.
10. Otherwise run showdown. The best hand wins. Equal hands split the pot;
    an odd chip goes to the first remaining player clockwise from the button.

After settlement, mark every zero-stack player as eliminated. If only one
player has chips, finish the tournament and declare that player the winner;
otherwise begin the next hand.

The human may request to quit at any time. Stop the current action or hand
immediately, mark the tournament as quit by the player, and do not settle the
pot or declare a winner.

Skip a betting round when every remaining player is all-in or only one player
can act.

### 4.5 Actions (No Limit)

Legal actions depend on `current_bet`, the largest wager on the current street
(including preflop blinds), plus the player's `bet_this_round` and `stack`.

| Action | When legal |
| --- | --- |
| `fold` | Whenever it is the player's turn and the player has not finished the hand. |
| `check` | When `bet_this_round == current_bet`. |
| `call` | When `current_bet > bet_this_round`. The call is `min(stack, current_bet - bet_this_round)`; committing the full stack is all-in. |
| `bet` | Postflop when `current_bet == 0`. Minimum is one big blind; maximum is the full stack. |
| `raise` | When `current_bet > 0`. A minimum **full raise** reaches `current_bet + big_blind`, regardless of previous full-raise sizes on that street. The first preflop raise is therefore at least 2 BB when `current_bet` is 1 BB. Maximum is all-in. |

An all-in raise below the minimum full raise is legal, but does **not** reopen
raising for players who already acted and matched the previous full raise.
Players who have not yet acted must still fold, call, or raise.

A betting round is complete when:

- every remaining player has acted at least once after the latest full bet or
  raise; and
- every remaining player who is not all-in has matched `current_bet`.

### 4.6 Pots and side pots

When at least one player is all-in for less than another contribution,
`PotManager` creates side pots. A player may win only pots for which that
player is eligible. Folded players cannot win, but their chips remain in the
pot. Unmatched excess is returned to its contributor rather than represented
as a one-player pot. Adjacent layers with identical eligible winners merge
into one canonical pot.

### 4.7 Hand evaluation

Each player uses exactly five cards: the best five-card combination from up to
seven cards (2 hole cards plus 5 community cards). Categories, highest first:

1. Straight flush, including royal flush
2. Four of a kind
3. Full house
4. Flush
5. Straight; A-2-3-4-5 is five-high
6. Three of a kind
7. Two pair
8. One pair
9. High card

Comparison uses standard kickers. Suit has no value except for making a flush.
The evaluator must be deterministic, testable, and independent of UI.

## 5. Participants and agents

### 5.1 Human

- Standard GUI and interactive CLI play has exactly one `HumanAgent`.
- The human receives only their own hole cards and public state.
- GUI and CLI translate clicks or commands to `PlayerAction` and submit it to
  the core.
- The core pauses hand progress until it receives a legal action; v1 has no
  timeout.

### 5.2 Bots

- Every other product-game seat has a `BotAgent` implementing the same agent
  contract as the human.
- Agent code lives outside the rules engine under `scripts/core/agents/`.
- Each bot receives an information-limited `GameView`: its own hole cards,
  board, pots, stacks, positions, and legal actions, but no opponent hole
  cards unless legitimately revealed at showdown.
- A seat's strategy can change without modifying deck, pot, or betting rules.

Version 1 includes at least three strategies in separate files:

1. `RandomAgent` — chooses a random legal action for smoke testing.
2. `TightPassiveAgent` — folds weak hands, otherwise checks or calls, and
   rarely raises.
3. `LooseAggressiveAgent` — bets or raises more often with a wider range.

Strategies may use simple heuristics, such as a Chen-like preflop score and
postflop board texture. They must not cheat.

The default table uses seat 0 for the human and seats 1–5 for bots, with at
least two different bot classes represented.

### 5.3 Simulation-only composition

Simulation v1 may create 2–9 all-bot participants only through the dedicated
non-interactive simulation composition root. It may vary player count,
starting stack, starting small blind, and starting big blind per explicit
regime. It must use the fixed blind progression from section 4.1; alternate
blind schedules are deferred. Simulation does not relax card privacy or any
poker rule.

## 6. Architecture

### 6.1 Principles

- One responsibility per module: deck, card, player, chips/pots, betting,
  evaluation, agents, and presentation.
- The core owns game state. A UI reflects state and never mutates stacks or
  cards directly.
- Use strongly typed GDScript. Use Custom Resources for card and rule data
  where appropriate, including `CardData`.
- Do not use C# or platform-specific plugins.

### 6.2 Directories and principal classes

```text
scripts/core/
  card_data.gd          # Resource: rank, suit, ID
  deck.gd               # 52 cards; shuffle, draw, reset
  chip_stack.gd         # one player's stack; debit/credit; never negative
  pot_manager.gd        # main and side pots; contribute, award
  player.gd             # seat, name, stack, hole cards, state flags
  player_action.gd      # action enum and amount
  game_view.gd          # read-only snapshot for agents and adapters
  hand_evaluator.gd     # best five of seven; comparison
  betting_round.gd      # legal actions, minimum raise, action reopening
  table.gd              # seats, button, blinds
  match.gd              # tournament lifecycle
  hand_controller.gd    # one hand: deal, streets, showdown
  agents/
    agent.gd
    human_agent.gd
    random_agent.gd
    tight_passive_agent.gd
    loose_aggressive_agent.gd
scripts/gui/            # rendering and input to HumanAgent only
scripts/cli/            # interactive text UI and input to HumanAgent only
scripts/simulation/     # non-interactive all-bot batch adapter
resources/              # CardData and configuration Resources
scenes/                 # Control-based table
```

`Deck` does not know players. `ChipStack` does not know cards.
`HandEvaluator` does not know pots. `Agent` receives `GameView`, not mutable
internal state.

`match.gd` owns the tournament lifecycle and supports normal completion with a
winner and voluntary termination with `end_reason = player_quit`. Voluntary
termination is a control command, not a poker action in `PlayerAction`.

### 6.3 Action object

```gdscript
enum ActionKind { FOLD, CHECK, CALL, BET, RAISE }
class PlayerAction:
    var kind: ActionKind
    var amount: int # 0 for fold/check/call; target street total for bet/raise
```

`betting_round.gd` rejects invalid UI or bot actions. If a bot returns an
invalid action, log a warning and fall back to `fold` when legal, otherwise
`check` or `call`.

### 6.4 `GameView` public contract

It contains at least:

- `street`: `preflop`, `flop`, `turn`, `river`, `showdown`, or `hand_end`;
- `button_seat`, `acting_seat`, `sb_seat`, and `bb_seat`;
- community cards;
- pots with amounts and eligible seats;
- for every seat: stack, street wager, folded/all-in/busted state, name, and
  human flag;
- `hero_seat` and only that recipient's `hero_hole_cards`;
- legal actions with call size and bet/raise minimum and maximum;
- public action history and recipient-safe showdown results for cards that
  were legitimately revealed, including category, tie-break values, and the
  selected five-card hand;
- hand number;
- tournament status (`running` or `finished`);
- end reason (`none`, `winner`, or `player_quit`); and
- active seats, eliminated seats, and optional winner.

Opponent hole cards appear only at showdown, or after the hand when those
cards were actually shown.

## 7. User interfaces

### 7.1 GUI

- Use `Control` nodes with `canvas_items` stretch and `expand` aspect. This
  scales the 2D layout but does not alone guarantee sharp text or graphics.
- Before constructing a tournament, show participant count, starting stack,
  small blind, and big blind, prefilled with defaults. Starting without edits
  is valid. Explain invalid input and do not begin a hand until all values are
  valid.
- Show board, pots, stacks, blinds, acting player, the human's cards,
  active/eliminated players, and the tournament winner.
- Hide opponent cards until legitimately revealed at showdown.
- Provide Fold, Check/Call, and Bet/Raise controls with minimum, Pot raise,
  all-in, and free-entry amounts. `Pot raise` uses the displayed pot total
  through ordinary wager validation and is disabled when that target is not a
  legal raise the human can cover.
- Provide a clearly visible `Quit` control at all times and request
  confirmation before quitting.
- Use one main table scene. The default window is 1920 × 1080, and the table
  must reflow without overlap at representative desktop and mobile aspect
  ratios.
- Provide 16 distinct avatar resources with 32 × 32 source pixels. Assign
  avatars without replacement per tournament and enlarge them when needed for
  readability.
- Render a green table with distinct community-card, wager, and pot zones.
- Present the human seat at the bottom without changing the core seat identity
  or poker position. Opponents show two card backs until showdown. Folded or
  eliminated seats remain visible in grayscale without hole cards.
- Seat panels show readable names, stack immediately below the name, position
  markers, and the latest public action from the **active betting round** on a
  separate line. Clear all prior seat action text at the start of preflop and
  each transition to flop, turn, and river; retain the complete public history
  in the event log. Center community cards, wagers, and pots as one group.
- Place compact, explicit two-row action controls beside the human seat. The
  event log is scrollable, high contrast, and cannot cover seats. At showdown,
  show each revealed player's best hand above that player's seat.
- All player-facing text is at least 20 px and uses Godot's built-in plain
  non-serif UI font. Compact layouts reflow or simplify rather than shrinking
  below the minimum.
- Containers, anchors, and responsive margins are the default layout tools.
  A documented single layout owner may assign explicit rectangles to a
  specialized region, provided no `Container` competes for those child
  rectangles. Mobile touch targets are at least 48 × 48 px; horizontal text
  buttons target approximately 160 × 50 px where space permits.
- Prefer viewport dimensions and aspect ratio for responsive layout decisions;
  OS feature flags may supplement but must not replace viewport detection.
- Follow [`gui_scaling_best_practice.md`](gui_scaling_best_practice.md) when
  resolving GUI scaling issues.

#### GUI display-name contract

- Store exactly **50 unique first names** with broad international
  representation. Each name consists only of Unicode letters and contains no
  more than **eight Unicode code points**. Length is measured by code points,
  not bytes or rendered glyph width.
- Assign bot names without replacement for one tournament. Keep the mapping
  stable until that tournament ends.
- The GUI human label is exactly `Human`. The GUI never renders a generated
  name or the interactive CLI suffix for the human.
- Name assignment uses a separately named, presentation-only `gui_names` RNG
  stream. Avatar assignment uses a distinct `gui_avatars` stream. Consuming
  either stream cannot perturb the other or any deck, button, bot-decision, or
  simulation RNG stream.
- GUI names are presentation-only and do not alter `Player`, `GameView`,
  agents, game configuration, domain events, simulation artifacts, or CLI
  labels.

### 7.2 Interactive CLI (headless)

Start with:

```bash
godot --headless --path . --script res://scripts/cli/cli_app.gd
```

- Before constructing a tournament, display defaults and allow immediate
  startup without supplied values. In configuration mode, each field may be
  overridden independently; blank input retains that field's default.
- Explain invalid startup values and prompt again. No hand starts from invalid
  configuration.
- Write readable game state to stdout.
- In every player list, append the literal suffix `(you)` immediately after
  the human's display name, for example `Player 1 (you)`. Exactly one player
  has the suffix and no bot does. Use the `GameView` human flag, not name,
  seat, acting status, or card visibility. This existing CLI labeling is not
  changed by the GUI naming contract.
- Format visible cards according to
  [`POKERCARDS_IN_CLI.md`](POKERCARDS_IN_CLI.md). A card is rank followed by
  its Unicode suit, such as `A♠` or `10♥`; collections use
  `[ A♠ | 10♥ | K♦ ]`. Never render internal card IDs or numeric rank/suit
  pairs.
- Assume UTF-8 and handle rank `10` without fixed-width padding assumptions.
- Read `fold`, `check`, `call`, `bet 50`, `raise 100`, `allin`, `quit`, and
  `exit` from stdin.
- For an invalid command, show an error and prompt again without crashing.
- Bots act without waiting for stdin.
- Human `quit` or `exit` ends the tournament immediately.

## 8. Configuration

A Resource or constant configuration supplies defaults and validated core
input:

- `player_count`: 2–9, default 6;
- `small_blind` and `big_blind`;
- `starting_stack`;
- `rng_seed`: 0 selects a time-based seed; any other value is deterministic
  and tests require a nonzero value;
- `seat_agents`: seat to agent ID;
- `tournament_mode`: `single_table` in v1.

Before constructing each product tournament, GUI and interactive CLI may
independently override `player_count`, `starting_stack`, `small_blind`, and
`big_blind`. Defaults are 6, 1000, 5, and 10. Omitted values are resolved
individually from defaults. Validate, copy, and freeze the resolved
configuration when the tournament starts. A later tournament may choose new
values. Product play has `player_count - 1` bot seats and one human at seat 0.

A simulation manifest specifies one or more explicit regimes using the same
four configurable values and ordinary validation. Every regime uses the
normative fixed blind progression. Simulation profile parameters for
`StrategyDecisionModel` are integer percentages in the inclusive range
0–100.

## 9. Testing

Automated Godot tests or pure GDScript assertions cover at least:

- A deck contains 52 unique cards after reset and shuffle.
- A five-high wheel beats king-high and loses to a six-high straight.
- Side pot: A all-in for 40, B for 100, C for 100; A is eligible for only the
  120-chip main pot, and B and C contest the remainder.
- Minimum preflop raise from a big-blind wager.
- A short all-in raise does not reopen action for a player who already called.
- An agent does not receive opponent hole cards before showdown.
- A zero-stack player is eliminated and omitted from the next hand.
- Button and blinds skip eliminated players.
- The tournament ends with the correct winner when one seat has chips.
- Human quit during or between hands produces `player_quit` and no winner.
- Full omission uses defaults; valid partial overrides preserve defaults for
  omitted fields; valid non-default values control player count, equal initial
  stacks, and starting blinds; invalid explicit values fail before the first
  hand; blind progression remains normative.
- Every CLI player list marks exactly the human with `(you)` across rerenders
  and later hands.
- CLI card output follows `POKERCARDS_IN_CLI.md`, including suits, rank `10`,
  separators, brackets, and absence of internal codes.
- The GUI name catalog has exactly 50 unique entries, each made only of
  Unicode letters and no longer than eight Unicode code points; assignments
  cover every bot seat without replacement and never alter avatar or game RNG
  results.
- Normal GUI and interactive CLI construction reject zero-human tables, while
  simulation-only construction permits all-bot tables.

## 10. Acceptance criteria for the first playable version

1. A single-table No Limit Texas Hold'em tournament can be completed in the
   interactive CLI with one human and at least two bots.
2. The same core connects to GUI without duplicated poker rules.
3. Changing the bot class at a seat requires only configuration/construction,
   not changes to `Deck`, `PotManager`, or `HandEvaluator`.
4. Chips balance after every normal hand: player stacks plus pot remain
   constant during the hand; after settlement the pot is zero and all stacks
   total the tournament's initial chips.
5. Eliminated players do not enter later hands, and the tournament stops with
   one remaining player.
6. The human can quit at any time in GUI or interactive CLI; play stops with
   no winner and `end_reason = player_quit`.
7. The human never sees unrevealed opponent hole cards in GUI or CLI.
8. Before every product tournament, GUI and CLI may optionally override the
   participant count, common starting stack, and starting blinds. Full
   omission uses 6, 1000, and 5/10; partial omission preserves per-field
   defaults. The resolved configuration is displayed, and the fixed blind
   progression cannot change during the tournament.
9. Every visible CLI card uses rank plus Unicode suit and every collection
   uses brackets and ` | ` as defined in `POKERCARDS_IN_CLI.md`.
10. Every CLI player overview marks exactly the human with `(you)` and no bot.
11. GUI seat action text contains only the active betting round and clears at
    preflop and each street transition; the event log retains full public hand
    history.
12. GUI bots use the validated 50-name catalog without replacement; the human
    is labeled exactly `Human`; name selection cannot perturb avatars or game
    randomness.
