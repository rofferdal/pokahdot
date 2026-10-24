# Two-Round Bot Roster Improvement Prompt

Use this document as the execution prompt for a future bot-evolution run. It
implements the intent of `devdocs/tutorials/improving-bots-with-simulations.md`
without bypassing the repository's evidence and review gates.

## Outcome and non-negotiable constraints

Produce ten evidence-backed, stylistically distinct `StrategyDecisionModel`
profiles for the playable roster. The current roster must remain unchanged
until the final reviewed source change.

At the time this document was written, `PlayableBotRoster` contains eight
profiles:

- Three retained legacy profiles: `random_default`, `tight_passive_default`,
  and `loose_aggressive_default`.
- Five strategic profiles: `nit_caller`, `tight_aggressive`, `loose_passive`,
  `loose_aggressive`, and `balanced`.

The product allows at most 25 strategic profiles. Adding ten promoted
strategic profiles would result in 15 strategic profiles and is therefore
within the limit. Re-check the exported roster before acting; do not rely on
these counts if the catalog has changed.

The simulation engine supports at most nine players per tournament. Thus, a
"set" of 18 profiles in round 1 or 23 profiles in round 2 is a candidate pool,
not one table. Every current profile must be present in each round's manifest.
Use deterministic randomized mixed-field scheduling so every profile appears
equally often and shares a table with every other profile at least once.

Do not auto-promote, publish, or alter `PlayableBotRoster`. The repository
requires independent mirrored and mixed-table evidence, followed by approval
from an independent human reviewer, before publication. If no reviewer is
available, finish with artifacts and a proposed roster patch only.

## Important tool limitations

### Long-running Godot execution collaboration

The application runner available to an execution agent can impose a short
foreground command window. This is an execution-environment limit, not a
Godot simulation limit. A large simulation can finish every tournament yet
still be stopped while Godot serializes its report, leaving no report artifact.

If a required Godot `run` command cannot persist its output within the agent's
command window, the agent must stop before performing any dependent step. It
must record the condition in `run_log.md` and ask the user to run the exact
command in their IDE terminal. The handoff must include:

- the complete command, including the run-local manifest and output paths;
- the expected report path and any console-log redirection path;
- a command to verify the report exists after completion; and
- an instruction for the user to reply when the command has completed.

The user should run the command directly in the repository root. For example:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script \
  res://scripts/simulation/simulation_cli_app.gd -- \
  run --config artifacts/bot_evolution_<run_id>/round1_manifest.json \
  --output artifacts/bot_evolution_<run_id>/round1_report.json --format json \
  > artifacts/bot_evolution_<run_id>/round1_console.log 2>&1
```

After the user confirms completion, the agent must first check the expected
report exists and then run `inspect` and `replay` against that exact immutable
artifact. It must not substitute a partial shard or rerun a dependent
evaluation merely because the long-running report is unavailable.

### Mandatory user review before each ranking simulation

After creating or changing a round manifest, the execution agent must validate
it but must not start the simulation yet. The agent must ask the user to open
and verify the exact manifest in their IDE. The request must concisely report:

- the manifest path and checksum;
- profile, regime, matchup, evaluation-plan, and total-tournament counts;
- the schedule seed and per-matchup tournament count; and
- confirmation that equal profile appearances, complete pair coverage, and
  cyclic seat balance were validated.

The user must explicitly approve that manifest before the agent runs it. If
the manifest changes after approval, the approval is invalidated: validate the
new artifact and ask the user to review and approve it again. Record the
request, the user's response, and the approved checksum in `run_log.md`.

The current `tools/profile-evolution` CLI deliberately creates opaque,
content-derived candidate IDs such as `candidate_g0_0000_<hash>`. It does not
support semantic candidate IDs, arbitrary population merging, or carrying five
candidates from one generation into another generated manifest. It also has no
automatic roster-edit command.

For this run, assign a unique descriptive **working label** to each candidate
in the run-local `artifacts/bot_evolution_<run_id>/candidate_labels.md` file.
The label must describe its observed intended style, for example
`Iron-Nit`, `River-Hawk`, `Velvet-Caller`, or `Blind-Press`. Map each label to
the immutable candidate ID and all four gene values. Do not edit the generated
artifact to replace candidate IDs. A winning candidate receives its final
player-visible descriptive name through `publish-profile --display-name`.

The second-round 15-candidate comparison can be simulated exactly, but it
cannot currently be represented as one generated `generation_manifest` for a
single `evaluate-fitness` ranking. Evaluate the five fresh random candidates
and five mutated children with their own valid immutable artifacts, retain the
round-1 fitness artifact for the five survivors, and make the final
cross-round ranking from the common round-2 report using the documented
fitness formula and raw profile results. Record the calculation, inputs, and
tie-breaks in `final_ranking.md`. Do not forge or hand-edit checksummed
evolution artifacts to work around this limitation.

If a future implementation needs a fully tool-enforced single ranking of all
15 candidates, add a separately reviewed profile-evolution operation that
constructs a provenance-preserving merged generation artifact first. Do not
implement that new capability as an incidental part of this run.

## Execution prompt

You are executing a reproducible, two-round bot-evolution experiment. Work
only inside a newly named directory,
`artifacts/bot_evolution_<YYYYMMDD>_<run_id>/`; never overwrite a prior
artifact. Use English in all files. Preserve unrelated working-tree changes.

### 1. Initialize and snapshot

1. Read the following before changing anything:
   `AGENTS.md`, `docs/ProjectDescription.md`, `docs/ARCHITECTURE.md`,
   `devdocs/tutorials/improving-bots-with-simulations.md`,
   `devdocs/how-to/running-simulations.md`,
   `devdocs/how-to/evaluating-bot-performance.md`, and
   `devdocs/how-to/replacing-in-game-bot-profiles.md`.
2. Inspect `docs/*Tasks.md`; do not modify an unrelated incomplete task.
3. Run `make profile-evolution-test` before beginning. Stop and report if it
   fails.
4. Export and validate an immutable current-roster baseline. Use a descriptive
   run-specific batch ID, a non-zero seed, and a tournament count divisible by
   the roster size and satisfying the export sample minimum.

   ```sh
   godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
     export-roster-manifest \
     --output artifacts/bot_evolution_<run_id>/roster_before.json \
     --batch-id bot_evolution_<run_id>_before \
     --seed <baseline_seed> --tournament-count 2520

   godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
     validate --config artifacts/bot_evolution_<run_id>/roster_before.json --format json
   ```

5. Record the actual current profile IDs, roster version, parameters, chosen
   seeds, Git revision, and commands in `run_log.md`. Run the baseline report
   if it is useful diagnostically, but never treat it as promotion evidence.

### 2. Round 1: ten deliberately diverse candidates

1. Create strict gene bounds for all four strategy genes in `0..100`, then
   initialize exactly ten candidates with a recorded seed:

   ```sh
   tools/profile-evolution init-generation \
     --bounds artifacts/bot_evolution_<run_id>/bounds.json \
     --population-size 10 --seed <round1_generation_seed> \
     --output artifacts/bot_evolution_<run_id>/round1_generation.json
   ```

2. Examine the generated genes. Give all ten candidates unique working labels
   in `candidate_labels.md` (see the section on naming and descriptive labels).
   Immutable tool-generated candidate IDs remain authoritative and opaque.
   If random initialization failed to cover clearly
   different styles, discard the *entire unrun generation* and initialize a
   new one with a new seed; do not edit candidate genes or IDs. Seek broad
   coverage across tight/loose play, initiative, raise tendency, and bluffing,
   while retaining an L1 distance of at least 10 from every incumbent strategy
   profile and from every other candidate where practical.
3. Build a schema-2 round-1 manifest containing all eight incumbent snapshots
   and all ten candidate snapshots. With `N = 18` profiles and `K = 9` seats,
   generate exactly `N` distinct nine-player matchups from a recorded non-zero
   schedule seed. The schedule must satisfy all of these invariants:

   - every matchup contains exactly `K` distinct profiles;
   - every profile appears in exactly `K` matchups;
   - every unordered pair of profiles occurs together in at least one matchup;
   - matchup IDs and profile order are stable for the recorded seed; and
   - the complete schedule is rejected and regenerated with a new recorded
     seed if any invariant fails.

   Preserve the schedule seed, generator version or algorithm description,
   per-profile appearance counts, and pair-coverage counts in
   `round1_schedule.md`. Before generating a schedule, verify the necessary
   feasibility conditions `N >= K` and `K * (K - 1) >= N - 1`.

   Use one nine-player, 100bb, 5/10, normative-hand-based regime. Create one
   evaluation plan containing all 18 matchup IDs, with cyclic rotation,
   `normal_95`, `minimum_profile_samples: 300`, and
   `tournament_count: 1782` (`18 matchups * 99 tournaments`). The planner
   round-robins the matchup IDs, so each matchup receives exactly 99
   tournaments. Ninety-nine is used instead of 100 because a nine-player
   cyclic plan requires a multiple of nine for balanced seats. Each profile
   therefore receives 891 total tournament samples and 99 samples in each
   seat across its nine matchups.
4. Validate the manifest. Report its checksum and schedule summary, then ask
   the user to inspect `round1_manifest.json` in their IDE. Wait for explicit
   approval of that exact checksum before running it. After approval, run,
   inspect, and replay at least one tournament:

   ```sh
   godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
     validate --config artifacts/bot_evolution_<run_id>/round1_manifest.json --format json

   godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
     run --config artifacts/bot_evolution_<run_id>/round1_manifest.json \
     --output artifacts/bot_evolution_<run_id>/round1_report.json --format json

   godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
     inspect --report artifacts/bot_evolution_<run_id>/round1_report.json --format text
   ```

5. Evaluate round 1 with the immutable generation and complete report:

   ```sh
   tools/profile-evolution evaluate-fitness \
     --generation artifacts/bot_evolution_<run_id>/round1_generation.json \
     --report artifacts/bot_evolution_<run_id>/round1_report.json \
     --output artifacts/bot_evolution_<run_id>/round1_fitness.json
   ```

6. Reject immediately every candidate with non-zero invalid-action fallbacks.
   Rank remaining candidates by eligible fitness descending, then candidate ID
   as the deterministic tie-breaker. Remove the five lowest-ranked round-1
   candidates. Record all ten results, confidence intervals, style metrics,
   and the five survivors in `round1_decision.md`.

### 3. Round 2: retain five, add ten

1. Retain the five round-1 survivors unchanged. They must be in the round-2
   manifest and must not receive new IDs or altered genes.
2. Create exactly five independent random candidates through a separate
   `init-generation --population-size 5` call with a new seed. Assign five
   unique working labels that reflect the generated styles.
3. Create five variations of the best round-1 candidates:

   - Run `select` on `round1_fitness.json` with `--elite-fraction 0.20`.
     This retains the top two eligible parents, which is the maximum supported
     deterministic elite selection from a population of ten.
   - Run `crossover --target-count 5` with a new seed.
   - Run `mutate` on the crossover artifact using a bounded policy, for
     example 100% mutation probability and maximum delta 12. Use a new seed.
   - Label each child by the parent styles and its meaningful gene change.

   Preserve all generation, selection, crossover, and mutation artifacts for
   later lineage reconstruction.
4. Build one schema-2 round-2 simulation manifest containing the eight
   incumbents, five retained survivors, five fresh-random candidates, and five
   mutated children: `N = 23` profiles in total. With `K = 9` seats, generate
   exactly 23 distinct nine-player matchups from a new recorded non-zero
   schedule seed. Apply the same equal-appearance, complete pair-coverage,
   deterministic ordering, feasibility, rejection, and audit requirements as
   round 1, and record the evidence in `round2_schedule.md`.

   Create one evaluation plan containing all 23 matchup IDs, with cyclic
   rotation, `normal_95`, `minimum_profile_samples: 300`, and
   `tournament_count: 2277` (`23 matchups * 99 tournaments`). Each matchup
   receives exactly 99 tournaments; every profile appears in exactly nine
   matchups and therefore receives 891 total samples, balanced to 99 samples
   in each seat.
5. Validate the manifest. Report its checksum and schedule summary, then ask
   the user to inspect `round2_manifest.json` in their IDE. Wait for explicit
   approval of that exact checksum before running it. After approval, run,
   inspect, and replay the round-2 report. Evaluate the fresh random generation
   and the mutated-child generation separately against the complete same
   report. Retain the round-1 fitness result for survivors and calculate all
   15 candidates' mixed-field round-2 comparison in
   `final_ranking.md` from per-tournament report data using the exact six-part
   fitness formula and uncertainty penalty documented in
   `devdocs/how-to/evaluating-bot-performance.md`.
6. Exclude any profile with non-zero invalid fallbacks, insufficient samples,
   invalid report data, or a materially inconclusive result. Select the best
   ten eligible new profiles, documenting the rank, uncertainty, style
   statistics, genes, working label, and deterministic tie-breaks. Preserve
   archetype diversity; do not select near-clones solely because of a small
   fitness difference.

### 4. Mandatory promotion evidence for each proposed top ten

The two ranking rounds are not enough to add a profile to the game. For each
of the ten proposed profiles:

1. Rebuild a complete lineage registry from every relevant generation,
   selection, crossover, mutation, and fitness artifact. Use
   `tools/profile-evolution build-lineage`; validate it with
   `inspect-lineage`.
2. Run independent confirmation evidence with seeds disjoint from all prior
   reports and from each other:

   - Mirrored cyclic heads-up plans covering the candidate against all three
     retained legacy profiles and the selected historical champion.
   - Mixed cyclic tables of at least three seats that include the candidate,
     legacy opponents, and the historical champion.

   Use at least 300 tournaments per candidate and zero invalid-action
   fallbacks. The confirmation CLI verifies the stricter exact coverage.
3. Run `confirm-candidate` with the lineage registry, all three legacy IDs,
   the declared historical champion, and the complete mirrored and mixed
   reports. Do not substitute the two ranking reports for these independent
   reports.
4. Stop for an independent human reviewer. The reviewer must inspect the
   confirmation evidence and run `review-promotion --approve` with their own
   identity. A review note is optional. The execution agent must not approve
   its own candidates.
5. Only for candidates with eligible confirmation and independent approval,
   run `publish-profile`, choosing the working label as the descriptive
   `--display-name`. Never overwrite an existing published resource.

### 5. Integrate only the approved profiles

After and only after all ten profiles have passed their individual review
gates:

1. Add the ten published resource paths to
   `scripts/core/agents/playable_bot_roster.gd`; retain all three legacy
   profiles and existing profiles unless a separately approved replacement is
   necessary. Increment `ROSTER_VERSION` once.
2. Update roster tests to assert the new version, membership, strategic count,
   and deterministic selection. Do not change simulation capacity behavior.
3. Export a new post-change roster baseline under a new artifact name.
4. Run the relevant roster test, `make profile-evolution-test`, and `make
   check`. Resolve failures before handoff.
5. Report the ten published IDs, display names, resource paths, final roster
   version, all artifact paths, test results, and any candidates rejected by
   gates. Do not commit unless explicitly asked.

## Completion criteria

The run is complete only when exactly ten new profiles have: a retained
provenance chain; valid, independent confirmation evidence; an independent
human approval; a no-clobber published resource; roster integration that stays
within the 25-strategic-profile limit; and passing verification. Otherwise,
hand off the reproducible artifacts and the precise unmet gate rather than
claiming that the roster was updated.
