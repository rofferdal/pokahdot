# Strategy Parameter Validation

Historical record reviewed 2026-10-26; the original measurement date was not
recorded here. The endpoint measurements below come from the pre-correctness-fix
milestone implementation and schema-2 report era. Preserve these figures and
checksums as history; current tests and algorithms may produce different results.
They do not establish current promotion eligibility.

This record closed simulation-core Milestone 4. It measures the schema-1
parameter model, records the schema-2 decision, and defines the reproducible
regression coverage used before profile evolution begins.

## Controlled batches

Both runs used heads-up tournaments with a 100-chip stack, 5/10 starting
blinds, cyclic seat rotation, and 400 explicit tournaments (100 per isolated
matchup). Effective seeds were 41000 through 41399. In every matchup the two
profiles differed in exactly one parameter, using endpoint values 0 and 100;
all other values were fixed. The same batch run twice produces identical
metric summaries in `test_strategy_parameter_validation.gd`.

The schema-1 report had manifest checksum
`22799e687430cb09676f0cde7cfd54b1a26b0b14317963d75f741a6e7a6d5de2`.
Its endpoint totals were:

| Isolated control | Value 0 | Value 100 | Observation |
| --- | ---: | ---: | --- |
| `tight_vs_loose` | VPIP 3/5211 (0.06%) | VPIP 348/5211 (6.68%) | Distinct continuation range |
| `passive_vs_aggressive` | Aggressive 0/1908 opportunities | 525/1890 (27.78%) | Changed both betting and raising |
| `call_vs_bet` | Aggressive 0/1771 opportunities | 479/1703 (28.13%) | Same observable role as the preceding control |
| `bluff_rate` | Bluffs 0/1301 eligible | 954/954 (100%) | Exact eligible-opportunity probability |

Static inspection explained the overlap: schema 1 selected an aggressive
continuation only when two independent rolls both succeeded. Its probability
was therefore `passive_vs_aggressive * call_vs_bet / 10000`; swapping the two
values preserved the behavior distribution. They were not independent genes.

## Schema-2 contract

Schema 2 retains four bounded integer percentages but gives each one a single
observable responsibility:

| Parameter | Range | Behavioral metric |
| --- | --- | --- |
| `tight_vs_loose` | 0--100 inclusive | VPIP and continuation rate |
| `passive_vs_aggressive` | 0--100 inclusive | Bet share when check and bet are legal |
| `call_vs_raise` | 0--100 inclusive | Raise share among call/raise continuations |
| `bluff_rate` | 0--100 inclusive | Bluffs divided by eligible weak-hand opportunities |

The schema-2 confirmation report had manifest checksum
`37d01d9add13e258e163c0b409f625c75b42a8e50959f16aa86fcded5dc777cd`.
Opening-aggression endpoints produced 0/213 versus 319/344 bets (0% versus
92.73%) while their raise shares remained near the fixed 50% control (44.70%
and 51.67%). `call_vs_raise` endpoints produced raise shares of 0/346 and
251/251 (0% and 100%), while bet shares stayed near their fixed 50% control
(42.81% and 43.47%). Tightness and bluff endpoints reproduced the schema-1
VPIP and eligible-bluff results.

Simulation reports now include raw counts and denominators for bet/raise
opportunities, check-versus-bet decisions, call-versus-raise decisions, and
eligible bluffs. VPIP and PFR are deduplicated per hand, while action counts
cover all streets and classify all-ins by whether they call or increase the
prior wager. Aggregate behavioral rates divide summed numerators by summed
denominators, so zero-opportunity tournaments do not dilute the result. Full
decision measurement is independent of bounded trace sampling.

## Migration and genome scope

Schema-1 snapshots are not silently interpreted as schema 2. Migrate an old
profile by calculating
`round(old.passive_vs_aggressive * old.call_vs_bet / 100)` and assigning the
result to both `passive_vs_aggressive` and `call_vs_raise`. The bundled
profiles migrated as follows:

| Profile | Migrated opening/raise percentage |
| --- | ---: |
| Nit Caller | 4 |
| Tight Aggressive | 53 |
| Loose Passive | 4 |
| Loose Aggressive | 72 |
| Balanced | 28 |

At this milestone, manifest and report schemas were version 2 and required
complete snapshots. Strategy parameter schema 2 still defines the four genes;
current manifests use schema 2 and reports schema 4/command v6. Subsequent
river-draw, context, raise-rights, ranking, and uncertainty fixes require fresh
evaluation before relying on historical rankings. The current
[simulation contract](Simulation_And_Evolutionary_Bot_Strategy.md) owns formats
and promotion requirements; this record does not freeze decision algorithms.

## Historical policy note: `street_response_v2`

The initial fold-versus-call policy changed decision behavior without adding
profile genes; the four schema-2 parameters remained the parameter contract.
Calling can receive a bounded cheap-price credit independently of value-raise
eligibility. Marginal hands stop value re-raising after an opponent increases
the wager following their own aggression; strong hands can still re-raise.
Weak bluffs are eligible only before the actor's first voluntary action on the
street and before two wager increases have occurred. Eligibility is checked
before consuming a bluff roll.

Policy diagnostics count `eligible_bluff_opportunities` from the policy's actual
eligibility decision, including opportunities for profiles with `bluff_rate = 0`.
Older diagnostic-free traces retain the former weak-hand-plus-legal-wager
definition. This changes the denominator's meaning, so the historical endpoint
figures above are not current-policy benchmarks. Source identity distinguishes
evaluation evidence; parameter, manifest and report formats remain unchanged.
The [BFCR record](arkiv/BotFoldVsCallAfterRaisesTasks.md) owns current verification
results and limits. Published Resources and historical reports are preserved.

## Current policy note: `street_response_v3`

The follow-up replaces v2's marginal re-raise veto with a 0.15–0.85 resistance
factor multiplying the existing `call_vs_raise` percentage. It preserves the
cheap-call credit, original value threshold, opening-bet preference and strong
hand raise probability. Selective weak flop backdoor re-raises supplement the
initial bluff window; own aggression or two voluntary actions closes further
weak bluffs. Eligibility still precedes the existing `bluff_rate` roll.

All four genes remain active: `tight_vs_loose` sets continuation breadth,
`passive_vs_aggressive` governs opening bets, `call_vs_raise` governs eligible
raises, and `bluff_rate` governs eligible weak bluffs. Fixed-state paired-seed
regressions check that increasing raise preference preserves monotonic raise
choices under resistance, and that zero bluff preference suppresses bluffs
while 100 selects every eligible opportunity. These checks establish parameter
influence, not tournament strength or a guaranteed aggregate action rate.

Hand-potential and draw-quality scores are ratings, not equity. The policy uses
call price without calculating opponent-range equity or expected value. The
[current strategy contract](Simulation_And_Evolutionary_Bot_Strategy.md#23-strategy-parameter-contract)
defines the resistance factor and selective windows; the
[BFCR record](arkiv/BotFoldVsCallAfterRaisesTasks.md) owns verification evidence.
Parameter and report formats, published profiles and historical figures above
remain unchanged. Compare results only with matching executable provenance
and compatible opportunity definitions.
