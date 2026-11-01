# Strategic bot profile reference

The current `curated_v3` roster contains **25 strategic profiles**: five
hand-authored profiles and twenty simulation-selected published profiles.
All use `strategy_parameterized` and the same decision model; their four
parameters create different tendencies. The tables are sorted by display name.
Resource links identify the exact profiles used by the game.

The three optional legacy profiles (Random, Tight Passive and Loose Aggressive)
use other decision models and are excluded here. **Loose Cannon** is the
strategic profile; it is distinct from the legacy Loose Aggressive bot.

## How the parameters affect play

All values are integers from 0 through 100. These are conditional policy
controls, not percentages of all hands played or all actions taken.

| Table column | Resource parameter | Behavioral meaning |
| --- | --- | --- |
| Looseness | `tight_vs_loose` | Higher values lower the hand-potential threshold for continuing: 0 is tight and 100 is loose. The base threshold is `75 - 0.45 * value`, then call price, stack pressure and position modify it. This is a heuristic score, not a winning probability. |
| Opening aggression | `passive_vs_aggressive` | Percentage chance to choose a value bet over a check when both options are available and the hand meets the value threshold. A high value does not force a weak hand to bet. |
| Raise preference | `call_vs_raise` | Base percentage chance to choose an eligible value raise over a call. Marginal hands facing renewed aggression can have this probability reduced by the resistance factor, which accounts for price, wager size and opponents. |
| Bluff chance | `bluff_rate` | Percentage chance to take an eligible weak-hand bluff opportunity. A value of 100 takes every eligible opportunity, not every hand; a value of 0 disables this bluff branch. |

The bluff branch has its own legality, hand-strength and action-history gates.
A bot cannot bluff again after aggression on that street. Delayed bluffs or
entries after repeated aggression require a selective flop window with enough
backdoor potential, a reliable pot, call price at most 20%, at most two active
opponents, and legal call/raise options. Earlier weak-hand opportunities use
the initial window.

Consequently, a profile can be selective about value continuation yet bluff
often, or frequently open with value while preferring calls to further raises.
A raise preference of zero can still allow bluff raises. If only one legal
continuation exists, the model can take that action without a preference roll.

The descriptions below are interpretations of the configured parameters,
not measured action frequencies, strength rankings or guarantees of distinct
personalities. Board cards, position, opponents, stack sizes and legal actions
affect observed behavior. Names are labels and do not alter the policy.

## Style labels

The **Style** column assigns the closest of the four core styles:

- **Tight-Aggressive (TAG):** selective about entering pots, with a preference
  for value bets or raises when eligible.
- **Loose-Aggressive (LAG):** a broader continuation range, with a preference
  for value bets or raises when eligible.
- **Loose-Passive (Calling Station):** a broader continuation range, with
  checking and calling favored on the value path.
- **Tight-Passive (Rock):** a more selective continuation range, with checking
  and calling favored on the value path.

These are approximate parameter-based labels, not measured poker statistics.
For consistency in this reference, Looseness below 70 is classified as tight;
70 or above is loose. Opening aggression or Raise preference of at least 50
classifies the value style as aggressive; otherwise it is passive. These
cutoffs describe this table and are not thresholds used by the game.

Bluff chance remains a separate tendency: even a passive value style can
bluff aggressively when eligible. Likewise, a raise-focused aggressive bot
may check frequently when opening. The labels do not establish that a bot
plays very few starting hands, waits only for monster hands, applies constant
pressure, or is stronger than another style. Read Expected tendencies alongside
Style for those distinctions.

## Active strategic profiles

Five hand-authored profiles are protected members: Balanced, Loose Cannon,
Loose Passive, Nit Caller and Tight Aggressive. The other twenty are published
campaign selections.

| Display name and Resource | Looseness | Opening aggression | Raise preference | Bluff chance | Style | Expected tendencies |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| [Amber Horizon](../../resources/bot_profiles/published/candidate_g0_0002_3dd6bffeba52fcc1__20261101_r2.tres) | 67 | 65 | 14 | 100 | Tight-Aggressive (TAG) | Moderately selective; often opens with value, usually calls rather than value-raises, and takes every eligible weak-hand bluff opportunity. |
| [Azure Current](../../resources/bot_profiles/published/candidate_g0_0000_8c87829890bd1a11__20261101_r2.tres) | 86 | 98 | 20 | 34 | Loose-Aggressive (LAG) | Broad continuation range; almost always opens with eligible value, but usually calls instead of value-raising. Moderate bluff setting. |
| [Balanced](../../resources/bot_profiles/balanced.tres) | 70 | 28 | 28 | 12 | Loose-Passive (Calling Station) | Moderately broad continuation range; usually checks or calls when both value options exist. Occasional eligible bluffs. |
| [Copper Cadence](../../resources/bot_profiles/published/candidate_campaign_mut_0004_7c710eccf0688d55__20261101_r2.tres) | 53 | 59 | 97 | 48 | Tight-Aggressive (TAG) | More selective than most finalists; mixed opening preference, very strong value-raise preference, and frequent eligible bluffs. |
| [Copper Counter](../../resources/bot_profiles/published/candidate_g0_0009_292e08a42fe29566__20261024_r3b0.tres) | 73 | 44 | 86 | 44 | Loose-Aggressive (LAG) | Broad continuation range; mixed openings, a strong value-raise preference, and frequent eligible bluffs. |
| [Copper-Blaze Counter](../../resources/bot_profiles/published/candidate_g1_mut_0003_a92c427e3ea36b4a__20261024_r3b0.tres) | 66 | 39 | 49 | 54 | Tight-Passive (Rock) | Moderate continuation range; tends toward checking on value openings, mixes calls and value raises, and bluffs frequently when eligible. |
| [Copper-Blaze Ember](../../resources/bot_profiles/published/candidate_campaign_mut_0003_60068c2f18cd352f__20261101_r2.tres) | 91 | 86 | 32 | 32 | Loose-Aggressive (LAG) | Very broad continuation range; strong opening-bet preference, but usually calls rather than value-raising. Moderate eligible bluff frequency. |
| [Copper-Blaze Surge](../../resources/bot_profiles/published/candidate_g1_mut_0002_e856eeb3b2a832ed__20261024_r3b0.tres) | 80 | 82 | 43 | 47 | Loose-Aggressive (LAG) | Broad continuation range; often opens with value, leans toward calling over value-raising, and frequently takes eligible bluff opportunities. |
| [Crimson Beacon](../../resources/bot_profiles/published/candidate_campaign_mut_0002_e71136bb11dc8118__20261101_r2.tres) | 84 | 100 | 62 | 52 | Loose-Aggressive (LAG) | Broad continuation range; always bets when the value check/bet choice applies, often value-raises, and frequently takes eligible bluffs. |
| [Indigo Spark](../../resources/bot_profiles/published/candidate_g0_0006_d319bbb79e4935d8__20261101_r2.tres) | 61 | 33 | 67 | 54 | Tight-Aggressive (TAG) | Moderate continuation range; usually checks on value openings, prefers value raises to calls, and frequently takes eligible bluffs. |
| [Ivory Tempest](../../resources/bot_profiles/published/candidate_g0_0004_3683f0bcf5541341__20261101_r2.tres) | 85 | 64 | 100 | 30 | Loose-Aggressive (LAG) | Broad continuation range; often opens with value and always chooses the value raise in an unadjusted call/raise choice. Moderate eligible bluff frequency. |
| [Jade Undertow](../../resources/bot_profiles/published/candidate_g0_0005_13cce589f42b0696__20261101_r2.tres) | 28 | 12 | 75 | 74 | Tight-Aggressive (TAG) | Selective continuation range and usually checks on value openings, yet strongly prefers value raises when eligible and bluffs frequently in eligible weak-hand windows. |
| [Loose Cannon](../../resources/bot_profiles/loose_aggressive.tres) | 100 | 72 | 72 | 22 | Loose-Aggressive (LAG) | Widest configured continuation range; strong opening-bet and value-raise preferences, with occasional eligible bluffs. |
| [Loose Passive](../../resources/bot_profiles/loose_passive.tres) | 100 | 4 | 4 | 5 | Loose-Passive (Calling Station) | Widest configured continuation range; overwhelmingly checks or calls instead of value betting or raising. Rare eligible bluffs. |
| [Midnight Pulse](../../resources/bot_profiles/published/candidate_g0_0003_8ff30e87c04596e9__20261101_r2.tres) | 79 | 100 | 95 | 82 | Loose-Aggressive (LAG) | Broad continuation range; always bets in the eligible value check/bet choice, nearly always value-raises before resistance adjustment, and bluffs very frequently when eligible. |
| [Nit Caller](../../resources/bot_profiles/nit_caller.tres) | 60 | 4 | 4 | 2 | Tight-Passive (Rock) | Relatively selective; overwhelmingly checks or calls over value bets and raises. Very rare eligible bluffs. |
| [Phantom Orbit](../../resources/bot_profiles/published/candidate_campaign_mut_0000_2f02d51fac35ab34__20261101_r2.tres) | 26 | 53 | 37 | 82 | Tight-Aggressive (TAG) | Selective continuation range; mixed value openings, usually calls rather than value-raising, but takes eligible weak-hand bluffs very frequently. |
| [Phantom-Copper Inferno](../../resources/bot_profiles/published/candidate_g1_mut_0004_23c4aa0775d54bec__20261024_r3b0.tres) | 74 | 70 | 34 | 92 | Loose-Aggressive (LAG) | Broad continuation range; strong value-opening preference, usually calls rather than value-raising, and takes almost every eligible weak-hand bluff. |
| [Phantom-Copper Ripple](../../resources/bot_profiles/published/candidate_campaign_mut_0001_16a0d5cb77701d29__20261101_r2.tres) | 86 | 60 | 41 | 100 | Loose-Aggressive (LAG) | Broad continuation range; often opens with value, leans toward calling over value-raising, and takes every eligible weak-hand bluff opportunity. |
| [River Reverie](../../resources/bot_profiles/published/candidate_campaign_mut_0009_1957546ecfb4a5cf__20261101_r2.tres) | 82 | 24 | 0 | 53 | Loose-Passive (Calling Station) | Broad continuation range; usually checks on value openings and never chooses a voluntary value raise over an available call. Eligible bluff raises are still possible. |
| [River Velvet](../../resources/bot_profiles/published/candidate_g0_0002_ca41c8c26ecf41cf__20261024_r3b0.tres) | 88 | 28 | 2 | 34 | Loose-Passive (Calling Station) | Broad continuation range; usually checks or calls on the value path, with almost no voluntary value raises over calls. Moderate eligible bluff frequency. |
| [Scarlet Torrent](../../resources/bot_profiles/published/candidate_campaign_mut_0005_22f01c7c062f5b68__20261101_r2.tres) | 81 | 100 | 67 | 62 | Loose-Aggressive (LAG) | Broad continuation range; always bets in the eligible value check/bet choice, often value-raises, and bluffs frequently when eligible. |
| [Tight Aggressive](../../resources/bot_profiles/tight_aggressive.tres) | 65 | 53 | 53 | 8 | Tight-Aggressive (TAG) | Moderate continuation range; approximately even opening and value-raise preferences before resistance adjustment. Infrequent eligible bluffs. |
| [Wild Crest](../../resources/bot_profiles/published/candidate_campaign_mut_0008_dcb88cbf0bf7e5dc__20261101_r2.tres) | 92 | 100 | 18 | 41 | Loose-Aggressive (LAG) | Very broad continuation range; always bets in the eligible value check/bet choice, but strongly favors calling over value-raising. Frequent eligible bluffs. |
| [Wild Mirage](../../resources/bot_profiles/published/candidate_g0_0008_28cda20c09a12235__20261024_r3b0.tres) | 80 | 96 | 29 | 55 | Loose-Aggressive (LAG) | Broad continuation range; almost always opens with eligible value, usually calls instead of value-raising, and bluffs frequently when eligible. |

## Historical strategic profiles outside the active roster

These four Resources remain in the repository for history. They were rejected
during the campaign and are absent from `DEFAULT_PROFILE_PATHS`; normal GUI
and CLI selection does not use them. Their continued presence in the published
directory does not make them active. Campaign candidates that were never
published as Resources are not game profiles and are not listed here.

| Display name and Resource | Looseness | Opening aggression | Raise preference | Bluff chance | Style | Expected tendencies |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| [Copper-Blaze Drift](../../resources/bot_profiles/published/candidate_g1_mut_0001_7420b8a13d172e7f__20261024_r3b0.tres) | 77 | 60 | 32 | 43 | Loose-Aggressive (LAG) | Broad continuation range; often opens with value, usually calls over value-raising, and frequently takes eligible bluff opportunities. |
| [Crimson Surge](../../resources/bot_profiles/published/candidate_g0_0004_65dfe5e8e29beba9__20261024_r3b0.tres) | 75 | 83 | 69 | 51 | Loose-Aggressive (LAG) | Broad continuation range; strong opening-bet and value-raise preferences, with frequent eligible bluffs. |
| [Phantom Blaze](../../resources/bot_profiles/published/candidate_g0_0005_7e36a0b114c9dcaf__20261024_r3b0.tres) | 13 | 70 | 44 | 88 | Tight-Aggressive (TAG) | Very selective continuation range; often opens with eligible value, leans toward calling over value-raising, and takes eligible weak-hand bluffs very frequently. |
| [Scarlet Charge](../../resources/bot_profiles/published/candidate_g0_0001_e944f5fff577f272__20261024_r3b0.tres) | 69 | 94 | 65 | 49 | Tight-Aggressive (TAG) | Moderate continuation range; almost always opens with eligible value, often value-raises, and frequently takes eligible bluffs. |

## Source of truth

- [Active roster membership](../../scripts/core/agents/playable_bot_roster.gd).
- [Parameter definitions](../../scripts/core/agents/strategy_decision_model_parameters.gd).
- [Decision policy and context adjustments](../../scripts/core/agents/strategy_decision_model.gd).
- [Final campaign selection and publication evidence](../../resources/bot_profiles/campaigns/bot_roster_expansion_20261101/FINAL_ROSTER.md).

When a profile, its active membership or the decision policy changes, update
the corresponding values and explanations here.
