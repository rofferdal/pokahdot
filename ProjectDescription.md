# Pokahdot — prosjektbeskrivelse

Dette dokumentet er kilde for hva som skal bygges. Implementer etter det som står her, ikke etter vanlige pokervarianter som ikke er nevnt. Ved motstrid vinner denne filen over `README.md`.

## 1. Mål

Pokahdot er et **Texas Hold’em No Limit**-spill i Godot 4 (GDScript, Compatibility-renderer). Én spiller er menneskelig. De øvrige er automatiske agenter med **utskiftbar beslutningskode**.

Samme spillkjerne skal drive:

- grafisk UI (`scenes/`, `scripts/gui/`)
- terminal-UI / headless (`scripts/cli/`)

Kjernen (`scripts/core/`) skal ikke kjenne til Control-noder, scener, stdin eller stdout.

## 2. Ikke-mål (første versjon)

- Ikke Omaha, Short Deck, Stud eller Limit/Pot Limit.
- Ikke turnering, rebuy, straddle, ante eller bomber pot.
- Ikke nettverk, flerspiller over nett eller ekte penger.
- Ikke rake.
- Ikke timer på trekk (mennesket venter til input; boter svarer synkront).

## 3. Spillregler (normativt)

### 3.1 Bord og stacks

- 2–9 deltakere. Standard: **6 seter** (1 menneske + 5 boter).
- Sjetonger er **heltall**. Ingen desimaler.
- Standard blinds: **small blind = 5**, **big blind = 10**.
- Standard startstack: **1000** (100 BB) til hver som sitter med.
- Ingen kjøp underveis. Går stacken til 0, er spilleren ute av neste hender til de ev. får chips (ikke i v1: de sitter igjen som `busted` og skippes).

### 3.2 Kort

- Én kortstokk, 52 kort, ingen jokere.
- Farger: clubs, diamonds, hearts, spades.
- Ranger: 2–9, T, J, Q, K, A. A er høyest, unntatt i hjulet A-2-3-4-5.
- Ingen burn-kort. Stokken stokkes før hver hånd, deretter deles det direkte.
- Hver spiller får **to hullkort**, skjult.
- Community: flop 3, turn 1, river 1. Alle synlige for alle.

### 3.3 Posisjoner

- Button (`dealer`) flyttes ett sete med klokken etter hver hånd, hopp over `busted`.
- SB er venstre for button. BB er venstre for SB.
- Heads-up: button poster SB og handler **først preflop**, og **sist** postflop.

### 3.4 Håndforløp

1. Flytt button (ikke første hånd: trekk tilfeldig første button blant aktive).
2. Nullstill pott, community og hullkort.
3. Stokk stokken.
4. Poster SB og BB (all-in om stack < blind; rest inn i pott).
5. Del to hullkort til hver aktive spiller, med klokken fra SB.
6. Preflop betting.
7. Hvis mer enn én spiller ikke har foldet: flop, betting.
8. Tilsvarende turn og river.
9. Hvis bettingrunden slutter med én gjenstående: vedkommende vinner potten uten showdown.
10. Ellers showdown. Beste hånd vinner. Lik hånd deler potten (oddetallssjetong til første gjenstående spiller med klokken fra button).

En bettingrunde droppes hvis alle gjenstående er all-in eller det bare er én som kan handle.

### 3.5 Handlinger (No Limit)

Gyldige trekk avhenger av `current_bet` (største innsats denne runden, inkludert blinds preflop) og spillerens `bet_this_round` og `stack`.

| Trekk | Når |
| --- | --- |
| `fold` | Alltid når det er spillerens tur og hen ikke er ferdig i hånden. |
| `check` | Når `bet_this_round == current_bet` (ingen mer å matche). |
| `call` | Når `current_bet > bet_this_round`. Call = `min(stack, current_bet - bet_this_round)`. Call av hele stacken er all-in. |
| `bet` | Når `current_bet == 0` postflop (ingen har satset). Min bet = BB. Maks = hele stacken. |
| `raise` | Når `current_bet > 0`. Min **full raise** = `current_bet + last_full_raise_size`. Første raise preflop: `last_full_raise_size` starter som BB, så min raise totalt er 2 BB hvis BB er `current_bet`. Maks = all-in. |

All-in som er **mindre enn min full raise** er tillatt, men **åpner ikke** ny action for spillere som allerede har handlet og matchet forrige full raise. Spillere som ennå ikke har handlet, må fortsatt folde/calle/raise.

Bettingrunden er ferdig når:

- alle gjenstående har handlet minst én gang etter siste **full** bet/raise, og
- alle gjenstående som ikke er all-in har like mye inne denne runden (`bet_this_round` lik `current_bet`, eller all-in).

### 3.6 Potter og sidepotter

Når minst én spiller er all-in for mindre enn andre, skal `PotManager` lage **sidepotter**. En spiller kan bare vinne potter hen er med i. Foldede spillere kan ikke vinne, men chipsene deres blir i potten.

### 3.7 Håndvurdering

Hver spiller bruker nøyaktig **fem** kort, valgt som beste kombinasjon av opptil syv (2 hull + 5 board). Ranger, høyest først:

1. Straight flush (inkl. royal)
2. Four of a kind
3. Full house
4. Flush
5. Straight (hjulet A-2-3-4-5 teller som 5-høy)
6. Three of a kind
7. Two pair
8. One pair
9. High card

Sammenligning bruker standard kickere. Farge har **ingen** verdi utover flush. Evaluatoren skal være deterministisk og tesbar, uten UI.

## 4. Aktører

### 4.1 Menneske

- Nøyaktig **én** `HumanAgent` ved bordet i standardspill.
- Får kun **egen** hullkort + offentlig tilstand.
- GUI og CLI oversetter klikk/kommando til `PlayerAction` og sender den til kjernen.
- Kjernen blokkerer hånden til gyldig handling er mottatt (ingen timeout i v1).

### 4.2 Simulerte spillere

- Alle andre seter har en `BotAgent` som implementerer samme grensesnitt som mennesket.
- Agentkode skal ligge **utenfor** regelmotoren: `scripts/core/agents/`.
- Hver bot får et **informasjonsbegrenset** syn (`GameView`): egne hullkort, board, potter, stacks, posisjoner, gyldige trekk — **ikke** andres hullkort (unntatt ved showdown).
- Det skal være lett å bytte strategi per sete uten å røre `Deck`, `Pot` eller bettingregler.

Minst tre medfølgende strategier i v1 (egne filer):

1. `RandomAgent` — tilfeldig gyldig trekk (for røyk-test).
2. `TightPassiveAgent` — folde svake hender, ellers check/call; sjelden raise.
3. `LooseAggressiveAgent` — oftere bet/raise med bredere range.

Strategiene kan være enkle heuristikker (f.eks. Chen-lignende score preflop + board-tekstur postflop). De skal **ikke** jukse.

Standardbord: sete 0 = menneske, seter 1–5 = ulike boter (minst to ulike klasser i bruk).

## 5. Arkitektur

### 5.1 Prinsipper

- Ett ansvar per modul: kortstokk, kort, spiller, sjetonger/pott, betting, evaluering, agenter, UI.
- Spilltilstand eies av kjernen. UI speiler tilstand; UI muterer ikke stacks/kort direkte.
- Bruk sterkt typet GDScript. Kort- og regeldata som Custom Resources der det passer (`CardData`).
- Ingen C# eller plattformspesifikke plugins.

### 5.2 Mapper og klasser (skal opprettes)

```
scripts/core/
  card_data.gd          # Resource: rank, suit, id
  deck.gd               # 52 kort, shuffle, draw, reset
  chip_stack.gd         # stack for én spiller; trekk/legg til; aldri negativ
  pot_manager.gd        # main + side pots; contribute; award
  player.gd             # sete, navn, stack, hole_cards, folded, all_in, busted
  player_action.gd      # enum + amount
  game_view.gd          # readonly snapshot til agenter/UI
  hand_evaluator.gd     # 7 → beste 5, sammenligning
  betting_round.gd      # gyldige trekk, min raise, action-reopen
  table.gd              # seter, button, blinds
  match.gd              # en session: flere hender til stopp
  hand_controller.gd    # én hånd: deal, gater, showdown
  agents/
    agent.gd            # interface: choose_action(view) -> PlayerAction
    human_agent.gd      # venter på innkommende handling
    random_agent.gd
    tight_passive_agent.gd
    loose_aggressive_agent.gd
scripts/gui/            # kun visning og input til HumanAgent
scripts/cli/            # tekstvisning og kommandoer til HumanAgent
resources/              # .tres for CardData, evt. table-config
scenes/                 # Control-basert bord
```

`Deck` kjenner ikke spillere. `ChipStack` kjenner ikke kort. `HandEvaluator` kjenner ikke potter. `Agent` kjenner ikke intern mutasjon, bare `GameView`.

### 5.3 Handlingsobjekt

```
enum ActionKind { FOLD, CHECK, CALL, BET, RAISE }
class PlayerAction:
  var kind: ActionKind
  var amount: int   # 0 for fold/check/call; totalt innsatsbeløp denne handlingen for bet/raise
```

Ugyldig handling fra UI eller bot skal avvises av `betting_round.gd`. Bot som returnerer ugyldig trekk: fall tilbake til `fold` hvis fold er mulig, ellers `check`/`call`. Logg advarsel.

### 5.4 `GameView` (offentlig kontrakt)

Inneholder minst:

- `street`: preflop | flop | turn | river | showdown | hand_end
- `button_seat`, `acting_seat`, `sb_seat`, `bb_seat`
- `community_cards`
- `pots` (beløp og hvilke seter som er med)
- per sete: stack, bet_this_round, folded, all_in, busted, navn, om det er menneske
- `hero_seat`, `hero_hole_cards` (kun for den agenten viewet er bygd for)
- `legal_actions` med min/maks amount for bet/raise og call-størrelse
- `hand_number`

Andres hullkort kun når `street == showdown` eller hånden er over og kortene faktisk ble vist.

## 6. Brukergrensesnitt

### 6.1 GUI

- Control-noder. Skalerbart (`canvas_items`).
- Vis: board, potter, stacks, blinds, whose turn, egne kort.
- Motstanderes kort skjult til showdown.
- Knapper: Fold, Check/Call, Bet/Raise (beløp: min, 1/2 pot, pot, all-in, fri input).
- Én hovedscene for bordet.

### 6.2 CLI (headless)

Start: `godot --headless --path . --script res://scripts/cli/cli_app.gd`

- Skriv lesbar tilstand til stdout.
- Les kommandoer fra stdin, f.eks. `fold`, `check`, `call`, `bet 50`, `raise 100`, `allin`.
- Ugyldig kommando: feilmelding, spør igjen. Ikke krasj.
- Boter handler uten å vente på stdin.

## 7. Konfigurasjon

En Resource eller konstant config:

- `player_count` (2–9, default 6)
- `small_blind`, `big_blind`
- `starting_stack`
- `rng_seed` (0 = tidsbasert; ellers deterministisk, påkrevd for tester)
- `seat_agents`: sete → agent-id

## 8. Testing (kjerne)

Automatiserbare Godot-tester eller rene GDScript-asserts mot kjernen, minst:

- Stokk har 52 unike kort etter `reset` + `shuffle`.
- Hjul-straight slår K-høy, taper for 6-høy straight.
- Sidepot: A all-in 40, B 100, C 100; A kan bare vinne 120 totalt fra den potten (40×3), B vs C om resten.
- Min raise preflop fra BB-størrelse.
- Short all-in raise åpner ikke action på nytt for den som allerede har called.
- Agent får ikke motstanderes hullkort i `GameView` før showdown.

## 9. Akseptansekriterier for første spillbare versjon

1. En hånd Texas Hold’em No Limit kan spilles ferdig i CLI med 1 menneske og minst 2 boter.
2. Samme kjerne kan kobles til GUI uten duplisert regelkode.
3. Byte av bot-klasse på et sete krever bare config/konstruksjon, ikke endring i `Deck`/`PotManager`/`HandEvaluator`.
4. Sjetonger stemmer etter hver hånd (sum stacks + pott uendret gjennom hånden; etter utbetaling er pott 0 og sum stacks lik startsum for hånden minus busted-historikk).
5. Mennesket ser aldri motstanderes hullkort før showdown, verken i GUI eller CLI.
