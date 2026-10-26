# How-To Guide: Evaluating Bot Performance & Statistical Decision-Making

This guide explains how to analyze simulation metrics, evaluate bot strengths and weaknesses, calculate required sample sizes, and make statistically informed decisions about which in-game bot profiles to replace.

---

## 1. How Much Data is "Enough Information"?

Poker tournaments have high inherent variance. A weak player can win a single tournament through fortunate card runouts, while a strong player can bust early. 

To make sound decisions, you must observe enough tournaments to reduce statistical uncertainty below the performance difference you want to measure.

### The Minimum Sample Size Rule
- **Suggested initial exploration**: 100 tournaments per matchup. Plans choose
  `minimum_profile_samples`; this suggestion is not a universal enforced gate.
- **Minimum for promotion decisions**: **$N \ge 300$ tournaments** per matchup
  and at least 100 candidate samples per seat under cyclic rotation. Thus a
  six-seat matchup needs at least 600 tournaments and a nine-seat matchup 900.
- **Gold standard benchmark**: $N \ge 1,000$ tournaments.

### Interpreting the 95% Confidence Interval (`uncertainty_95_half_width`)
Only `normal_95` is supported; bootstrap is rejected. Uncertainty uses
independent tournament/seed units, averaging repeated-profile seats within a
tournament. Intervals are unavailable below two units, and bounded components
have a Wilson half-width floor. Interpret a reported half-width as:
$$\text{True Metric Value} \in [\text{Reported Mean} - \text{half\_width}, \; \text{Reported Mean} + \text{half\_width}]$$

```text
Inconclusive (Overlapping Intervals):
Bot A: [====== 0.52 ======]
Bot B:    [====== 0.55 ======]   <-- Intervals overlap; difference may be noise.

Statistically Significant:
Bot A: [=== 0.45 ===]
Bot B:                  [=== 0.56 ===]   <-- No overlap; Bot B is reliably superior.
```

**Decision Rule**: For promotion evidence, pair Profile B and Profile A within
each tournament seed and calculate a confidence interval for those differences.
Conclude that B is superior only when the lower bound of the paired difference
is greater than zero. Comparing two independently calculated interval bounds
is not the promotion test.

### The `uncertainty_penalty`
The simulation engine applies a finite-sample penalty that is separate from a
confidence interval:
$$\text{uncertainty\_penalty} = \min\left(0.10, \frac{0.10}{\sqrt{N}}\right)$$
Here, $N$ is the number of independent tournament/seed observations, after
averaging repeated seats for the same profile within each tournament. The
penalty docks up to $0.10$ from the point fitness score without presenting
that deduction as an interval estimate.

---

## 2. Deconstructing the Composite Fitness Score

Pokahdot calculates a normalized, non-monetary tournament fitness score in the range `[0.0, 1.0]`:

$$\text{Fitness} = 0.30 W + 0.20 F + 0.15 T + 0.15 C + 0.10 S + 0.10 B - \text{uncertainty\_penalty}$$

| Component | Weight | Metric Formula | What it Measures |
| :--- | :---: | :--- | :--- |
| **$W$ (Win Score)** | 30% | $1$ if winner, $0$ otherwise | Ability to close out the tournament and take all chips. |
| **$F$ (Finish Score)** | 20% | $\frac{N_{\text{players}} - \text{position}}{N_{\text{players}} - 1}$ | Consistent deep runs ($1.0$ for 1st, $0.0$ for last). |
| **$T$ (Top-Third Score)** | 15% | $1$ if $\text{position} \le \lceil N_{\text{players}} / 3 \rceil$ | Making it past the bubble into top finishers. |
| **$C$ (Chip Score)** | 15% | $\frac{\text{chip\_differential} + \text{starting\_stack}}{N_{\text{players}} \times \text{starting\_stack}}$ | Chip generation efficiency without going bust. |
| **$S$ (Survival Score)** | 10% | $\frac{\text{hands\_survived}}{\text{tournament\_hand\_count}}$ | Staying alive and avoiding reckless eliminations. |
| **$B$ (Blind-Chip Score)** | 10% | $\frac{\text{clamp}(bnc\_per\_100, -100, 100) + 100}{200}$ | Blind-normalized chip growth rate per 100 hands. |

---

## 3. Diagnosing Behavioral Leaks with Style Metrics

Beyond raw fitness, simulation reports provide style metrics that explain **why** a bot is winning or losing:

### 1. VPIP vs PFR (Preflop Discipline)
- **VPIP (Voluntarily Put in Pot %)**: Percentage of hands where the bot voluntarily invested chips preflop (calls, bets, raises).
- **PFR (Preflop Raise %)**: Percentage of hands where the bot raised preflop.

| Archetype | Typical VPIP | Typical PFR | Diagnosis |
| :--- | :---: | :---: | :--- |
| **Nit** | $< 15\%$ | $< 5\%$ | Over-folds; easily exploited by blind stealing. |
| **Calling Station** | $> 40\%$ | $< 8\%$ | Calls too much preflop; bleeds chips postflop without initiative. |
| **Maniac** | $> 50\%$ | $> 35\%$ | Over-aggressive; high variance, susceptible to trap plays. |
| **Solid Aggressive** | $20\% - 30\%$ | $12\% - 20\%$ | Selective starting hands with preflop initiative. |

### 2. Aggression Factor & Action Splits
- **`bet_frequency`**: Propensity to bet when checked to (`check_bet_opportunities`).
  - $< 20\%$: Extremely passive; gives free cards to opponents.
  - $> 70\%$: Over-bluffs or over-values medium hands.
- **`raise_share`**: Percentage of calls converted into raises (`call_raise_opportunities`).
  - Low raise share ($< 15\%$) indicates the bot never punishes weak bets.
- **`eligible_bluff_frequency`**: Rate of bluffs when holding weak hands.
  - An effective bluff rate is typically between $5\%$ and $15\%$. Rates above $25\%$ often turn into chip donation against calling stations.

### 3. Invalid Action Fallbacks (Immediate Disqualification)
- **`invalid_action_fallbacks`**: Must be **zero**.
- If a bot attempts an illegal action (e.g. betting when raising is required, or wagering fewer chips than the minimum), the core rejects the action and uses a validated fold-first fallback (then check, then call).
- Any candidate with $> 0$ invalid actions has a logic defect and **must be rejected immediately**.

---

## 4. Multi-Regime & Positional Verification

Never evaluate a bot in only one configuration. Before deciding to replace a profile, run verification across two distinct dimensions:

The `export-roster-manifest` command is the right way to capture a
reproducible whole-roster starting point. Its standard preset deliberately
creates one roster-sized 100bb regime. Treat that report as a baseline and
diagnostic, not as proof across regimes or as candidate promotion evidence.
Build separate candidate-inclusive manifests for the mirrored and mixed runs
required by the promotion gate; retain their manifest checksums, reports, and
non-overlapping effective seed identities. Confirmation interprets the ranges
using each report's recorded RNG stream derivation version.

### 1. Positional Neutrality (Cyclic Seat Rotation)
Because the dealer button acts last postflop, position is a major advantage in Hold'em. 
- Always specify `"seat_rotation": "cyclic"` in your evaluation plans.
- Ensure `tournament_count` is an integer multiple of the regime's `player_count`.

### 2. Regime Diversity
A bot that excels in Heads-Up play ($N=2$) might fail in a 6-Max table ($N=6$):
- **Heads-up regime**: Rewards high VPIP ($> 50\%$) and relentless aggression to capture blinds.
- **6-Max regime**: Punishes high VPIP because multi-way pots require stronger showdown value.

Test candidate bots against both regimes:
- `heads_up_100bb`: 2 players, 1000 chips, 5/10 blinds.
- `six_max_100bb`: 6 players, 1000 chips, 5/10 blinds.

---

## 5. Automated Promotion Gates & Decision Checklist

Pokahdot enforces promotion rigor through the [`confirm-candidate`](../../tools/profile_evolution/confirmation.py) tool. An eligible candidate must satisfy each of the following strict criteria:

### The 8 Automated Promotion Criteria (`confirm-candidate`):
1. **Lineage Provenance**: The candidate profile must be present in the lineage registry with complete generation, crossover, and mutation ancestry.
2. **Independent Dual Regimes**: Must be evaluated in both **Mirrored** (heads-up, cyclic seats against each declared legacy profile and champion individually) and **Mixed-Table** (competing against legacy and champion baselines) simulation reports.
3. **Non-Overlapping Seed Sequences**: Mirrored and mixed benchmark reports must have independent, non-overlapping effective seed identities. Reused reports, RNG-version mismatches, shared seeds, and legacy modulo aliases are automatically rejected.
4. **Sample Thresholds**: Must satisfy sample requirements ($N \ge 300$ tournaments, minimum 100 per seat under cyclic rotation).
5. **Demonstrated Improvement**: Against every declared benchmark in each
   matchup, the lower normal-95 bound of the paired per-tournament raw
   composite difference must be strictly positive. Ties and overlapping
   intervals remain exploratory results.
6. **Zero Invalid Actions**: `invalid_action_fallbacks == 0` across all evaluation runs without exception.
7. **Multi-Opponent Coverage**: Candidate must face declared legacy archetypes (`random_default`, `tight_passive_default`, `loose_aggressive_default`) and historical champions.
8. **Genetic Diversity Gate (L1 Distance $\ge 10$)**:
   To avoid cloning existing archetypes, the tool calculates the L1 distance across the four percentage genes:
   $$\text{L1 Distance} = |\Delta\text{tight}| + |\Delta\text{passive}| + |\Delta\text{call}| + |\Delta\text{bluff}|$$
   The distance to every comparable declared legacy or historical champion profile must be **at least 10 percentage points**.

### Post-Confirmation Human Gate:
- Passing automated confirmation marks the candidate as `"promotion_eligible": true` and `"review_required": true`.
- Collect every proposed candidate with `prepare-promotion-review`. Its roster
  review compares every candidate pair using gene L1 distance and separately
  measured VPIP, PFR, bet/raise frequency, bet frequency, and raise share. An
  independent human reviewer must still change each candidate's one `decision`
  field from `pending` to `approve` or `reject`, then run
  `finalize-promotion-review` against the complete confirmation set.
- `publish-profile` may generate a Godot `.tres` resource only when the single finalized batch review contains an approved decision bound to that exact candidate and confirmation checksum. A review note is optional.
- Publication requires a finalized approved review artifact and never modifies
  the playable roster. Checksums bind its content, but do not authenticate the
  supplied reviewer label or prove reviewer independence.

The authoritative [metrics and fitness contract](../../docs/Simulation_And_Evolutionary_Bot_Strategy.md#3-metrics-and-fitness)
and [confirmation policy](../../docs/Simulation_And_Evolutionary_Bot_Strategy.md#5-external-profile-evolution-tool)
own the formulas and gates. Behavioral archetype ranges above are diagnostic
heuristics, not enforced promotion thresholds.
