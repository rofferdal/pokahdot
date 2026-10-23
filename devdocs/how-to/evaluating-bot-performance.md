# How-To Guide: Evaluating Bot Performance & Statistical Decision-Making

This guide explains how to analyze simulation metrics, evaluate bot strengths and weaknesses, calculate required sample sizes, and make statistically informed decisions about which in-game bot profiles to replace.

---

## 1. How Much Data is "Enough Information"?

Poker tournaments have high inherent variance. A weak player can win a single tournament through fortunate card runouts, while a strong player can bust early. 

To make sound decisions, you must observe enough tournaments to reduce statistical uncertainty below the performance difference you want to measure.

### The Minimum Sample Size Rule
- **Minimum for initial exploration**: $N = 100$ tournaments per matchup.
- **Minimum for promotion decisions**: **$N \ge 300$ tournaments** per matchup (minimum 100 samples per seat position under cyclic rotation).
- **Gold standard benchmark**: $N \ge 1,000$ tournaments.

### Interpreting the 95% Confidence Interval (`uncertainty_95_half_width`)
The simulation report calculates the 95% confidence interval half-width ($Z = 1.96$) for every metric:
$$\text{True Metric Value} \in [\text{Reported Mean} - \text{half\_width}, \; \text{Reported Mean} + \text{half\_width}]$$

```text
Inconclusive (Overlapping Intervals):
Bot A: [====== 0.52 ======]
Bot B:    [====== 0.55 ======]   <-- Intervals overlap; difference may be noise.

Statistically Significant:
Bot A: [=== 0.45 ===]
Bot B:                  [=== 0.56 ===]   <-- No overlap; Bot B is reliably superior.
```

**Decision Rule**: Only conclude that Profile B is superior to Profile A if:
$$\text{Fitness}(B) - \text{uncertainty}(B) > \text{Fitness}(A) + \text{uncertainty}(A)$$

### The `uncertainty_penalty`
The simulation engine automatically applies an uncertainty penalty to the composite fitness score:
$$\text{uncertainty\_penalty} = \text{clamp}\left(\frac{1}{6} \sum_{i=1}^6 \text{half\_width}_i, \; 0.0, \; 0.10\right)$$
If sample sizes are small, the penalty docks up to $0.10$ from the bot's fitness score.

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
- If a bot attempts an illegal action (e.g. betting when raising is required, or wagering fewer chips than the minimum), the core rejects the action and forces a fallback (check or fold).
- Any candidate with $> 0$ invalid actions has a logic defect and **must be rejected immediately**.

---

## 4. Multi-Regime & Positional Verification

Never evaluate a bot in only one configuration. Before deciding to replace a profile, run verification across two distinct dimensions:

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

## 5. Decision Checklist: When to Replace an In-Game Profile

Use this checklist before promoting a candidate into production:

- [ ] **Sample Count Met**: Evaluated over at least 300 tournaments with cyclic seat rotation.
- [ ] **Confidence Interval Separation**: Fitness exceeds target baseline with non-overlapping 95% confidence intervals.
- [ ] **Zero Invalid Actions**: `invalid_action_fallbacks == 0` across all runs.
- [ ] **Positive Chip Differential**: Demonstrates positive average chip differential against the incumbent roster.
- [ ] **Multi-Regime Stability**: Performs adequately in both heads-up and full-table regimes.
- [ ] **Preserves Roster Diversity**: The candidate fits the intended gameplay archetype (e.g., if replacing a "Calling Station", the new profile should improve that personality without turning every bot into an identical clone).
