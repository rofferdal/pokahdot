# Variable strategic bluff sizing

Status: complete for the requested 80% minimum / 20% larger-size policy. Created 2026-11-01.

The user requested varied bluff sizes, especially after the flop, because the
previous minimum-only target made bluffs identifiable by size.

## Policy

The user specified that bluffs must prefer the minimum, with at most a 20%
chance of a larger size. After a successful bluff-frequency roll, use the
minimum 80% of the time. The 20% larger-size menu contains minimum plus one
or two big blinds preflop, and half-pot/full-pot contributions postflop
using the same target calculation as value aggression (existing street wager
plus the fraction of the visible pot). Clamp targets to legal wager limits,
remove duplicates and discard targets equal to the minimum. One 20% sizing
roll controls the entire larger menu; choose uniformly among larger targets
only when that roll succeeds. With no larger target, use the minimum without
a sizing roll. This is a probability, not a finite-sample frequency quota.
Invalid/overflowing pot calculations fall back to the legal minimum. Short-stack clamping may produce
an all-in; do not introduce a separate deep-stack all-in bluff choice.

Keep the four profile parameters, bluff eligibility, value sizing and calling
thresholds intact. Record the behavior change as `street_response_v4`.
Historical campaign results remain evidence for the prior source revision;
this task does not authorize additional competitive simulations.

## Tasks

- [x] **BS-01 — Implement and verify sizing.** Baseline existing core tests;
  add reproducibility, street coverage, legal raise-total, short-stack and
  overflow checks; implement bounded mixed sizing using existing helpers.
- [x] **BS-02 — Document the policy.** Update current architecture, profile
  reference and developer guidance. Preserve historical simulation records.
- [x] **BS-03 — Final verification.** Run relevant core/simulation tests,
  lint/format and documentation checks. Follow `AGENTS.md` scope: no unchanged
  GUI/CLI suites and no new campaign simulation rounds.

## Verification evidence

Before the change, 425 core/simulation tests passed. After implementation, all
122 focused strategy/hand-potential/pot-sizing tests pass, including applied
public-history sequences. Session logs: `localtmp/bluff-sizing/` (local-only).

Final verification passes 432 core/simulation tests across 65 scripts with
113,555 assertions, including 122 focused strategy tests. Lint, formatting and
documentation checks pass. On 2026-11-01, the user confirmed keeping the
implemented 80% minimum / 20% larger bluff policy. The shared value/bluff
sizing alternative was not selected; value-bet and value-raise sizing retain
the existing hand-strength-based rules.
