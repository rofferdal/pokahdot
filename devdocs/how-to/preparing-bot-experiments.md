# Prepare and compare bot experiments

Use `tools/profile-evolution prepare-experiment` to generate comparable candidate
evaluation and independent confirmation manifests. It prepares commands and
artifacts; it does not run simulations, approve profiles or publish Resources.

## Inputs

Build a complete [lineage registry](replacing-in-game-bot-profiles.md) from the
immutable generation, fitness and selection history. Selected candidates may
come from different generations, including retained survivors and mutated
children. Historical champions must have selection history in that registry.
Keep the original generation artifacts alongside it. Selected candidates must
come from initialized or mutated `generation_manifest` artifacts. Apply
`mutate` to crossover `candidate_batch` output before selecting it for an
experiment; this preserves the existing reconstructible fitness-source contract.

Provide a schema-2 benchmark manifest containing exact snapshots of all declared
legacy opponents and historical champions. An exported current-roster baseline
can supply incumbent snapshots; copy missing historical champion snapshots from
their immutable lineage into a separate manifest. Champion genes must match the
registry exactly. The input baseline remains unchanged.

Create a configuration such as this, substituting actual registry IDs:

```json
{
  "schema_version": 1,
  "experiment_id": "strategy_round_2",
  "registry": "lineage.json",
  "benchmark_manifest": "benchmark_manifest.json",
  "candidate_ids": ["retained_candidate_id", "new_child_id"],
  "legacy_ids": ["random_default", "tight_passive_default", "loose_aggressive_default"],
  "historical_champion_ids": ["selected_champion_id"],
  "seed_starts": {"evaluation": 100000, "mirrored": 200000, "mixed": 300000},
  "tournaments_per_matchup": 300,
  "starting_stack": 1000,
  "small_blind": 5,
  "big_blind": 10,
  "reviewer_id": "independent_reviewer"
}
```

These are the exact required fields; unknown fields and duplicate IDs fail.
Input paths are relative to the configuration file. Selected candidates, legacy
opponents and champions must be distinct. The mixed table includes one candidate
and every benchmark, so at most eight benchmarks are supported. Chip inputs are
1–1,000,000 with small blind no larger than big blind.

`tournaments_per_matchup` is an integer target of at least 300. Heads-up counts
round upward to a multiple of two. Mixed counts round upward to a multiple of
the table size and at least 100 samples in each seat. All plans use cyclic
rotation and `normal_95`. The shared evaluation uses the same heads-up matchups
against every benchmark for every selected candidate, in one common plan.
Confirmation manifests contain exactly one selected candidate in every tournament.

Each seed start begins a separate block; mirrored and mixed blocks reserve a
separate subrange per candidate. Every complete block must fit the lossless
JSON integer domain, exclude zero, and remain disjoint from every other block
and the selected candidates' prior evaluation seeds. Preparation requires the
current `named_stream_sha256_v2` RNG for existing candidate evaluations; it
reports incompatible historical RNG evidence rather than dropping history.
A new experiment cannot make older evidence eligible. Preserve historical
artifacts and prepare appropriate current evaluation/lineage inputs explicitly.

## Validate and prepare

The output directory must not exist; its parent must already exist. Dry-run
writes nothing, prints manifest checksums and seed ranges, lists every planned
artifact and command, and reports incompatibilities. Incompatible dry-runs exit
with status 2 and preserve the complete explanation on stdout plus a structured
error on stderr.

```bash
tools/profile-evolution prepare-experiment \
  --config artifacts/round2_config.json \
  --output-dir artifacts/round2_prepared --dry-run

tools/profile-evolution prepare-experiment \
  --config artifacts/round2_config.json \
  --output-dir artifacts/round2_prepared
```

The prepared directory contains frozen `config.json`, `input_registry.json`,
`benchmark_manifest.json`, one `evaluation_manifest.json`, and separate
`candidate_NNNN_mirrored_manifest.json` / `candidate_NNNN_mixed_manifest.json`
files. Numeric filenames follow configuration candidate order; candidate IDs
remain unchanged inside the artifacts. `experiment.json` lists checksums,
counts, independent ranges and shell-quoted commands. Its `config_checksum`
binds the emitted configuration snapshot; `source_config_checksum` separately
binds the original configuration before relative input paths were rewritten.

Review these generated manifests and counts before executing the printed
commands. Replace `godot` with your local engine path if needed. The commands
validate and run the shared evaluation and each confirmation cohort, compare the
common evaluation, confirm each candidate, then prepare one consolidated review.
Use the [simulation run guide](running-simulations.md) for sharding and resume.
When sharding, supply every evaluation shard to comparison and every confirmation
shard to `confirm-candidate`.

Output directories are reserved without replacement. Complete files use the
shared no-clobber writer; `experiment.json` is committed last as the readiness
marker. On failure, only successfully published files owned by that operation
are removed. Unknown competing files and uncertain post-publication failures
are retained for inspection. A directory without its readiness marker is not a
completed preparation. No existing directory, file or dangling output symlink
is overwritten or followed.

## Compare the common evaluation

After its reports complete, compare all selected candidates against the same
cohort, preserving their generation identities:

```bash
tools/profile-evolution compare-experiment \
  --config artifacts/round2_prepared/config.json \
  --report artifacts/round2_prepared/evaluation_report.json \
  --output-dir artifacts/round2_prepared/comparison
```

For sharded execution, repeat `--report` once for every shard. Comparison rejects
changed manifests, missing/duplicate shards, mixed executable provenance,
invalid snapshots, unsuccessful tournaments and invalid metric data through the
existing fitness contracts. It recomputes each candidate's fitness from raw
profile results. It does not combine scores from different historical cohorts.

`comparison/comparison.json` ranks eligible candidates by fitness descending,
then candidate ID ascending. Ineligible candidates remain visible with reasons,
null fitness and no rank. Each row retains generation identity, original
creation context, component means, uncertainty and sample counts. Fitness is a
point estimate with the existing finite-sample penalty; ranking is not a claim
of statistically demonstrated superiority or promotion eligibility.

Per-candidate fitness artifacts bind their original immutable creation artifact,
not a synthetic merged generation. `evaluated_registry.json` preserves original
creation records, parent links, prior evaluations and champion selection
history, then appends the common-cohort evidence. Use this registry in the
printed confirmation commands. `comparison.json` is the final readiness marker
for this output set. Comparison never edits its input files.

## Consolidated independent review

Execute the printed `confirm-candidate` commands against the evaluated registry
and independent mirrored/mixed reports. The existing confirmation tool applies
all performance, sample, seed-independence and diversity gates. Sufficient
counts alone do not establish promotion eligibility.

The last generated command uses `prepare-promotion-review` with every resulting
confirmation. It creates one editable plan with all decisions `pending`. An
independent reviewer records `approve` or `reject` and optional names/notes;
`finalize-promotion-review` binds those explicit decisions to the exact
confirmations. Follow the [publication guide](replacing-in-game-bot-profiles.md)
for the separate approved publication and roster changes. Neither experiment
command makes or finalizes reviewer decisions.

## Nine-player roster campaign preparation

The separate [roster expansion backlog](../../docs/BotRosterExpansionTasks.md)
requires nine-player starts throughout. Its ledger preparation, candidate generation and cyclic scheduling are
implemented. Competitive execution requires the user's explicit approval of
the exact manifest; roster activation remains a later task.
The existing experiment commands above retain their heads-up policy.

```bash
tools/roster-campaign prepare \
  --inventory tests/fixtures/campaign_inventory.json \
  --historical-registry tests/fixtures/campaign_history/lineage_registry.json \
  --historical-registry examples/profile_evolution/milestone5/lineage_registry.json \
  --campaign-id bot_roster_expansion_20261101 \
  --output-dir localtmp/new_campaign_prepared

tools/roster-campaign validate \
  --campaign localtmp/new_campaign_prepared/campaign.json
```

Create the output parent first; the destination directory must not exist.
Preparation binds original historical artifacts in archival-only adapters,
freezes the incumbent inventory and seed reservations, and writes the campaign
readiness marker last. No historical execution metadata is invented, and
historical scores never count as new evaluation or confirmation evidence.

Generate and freeze the twenty new contenders from a prepared campaign:

```bash
tools/roster-campaign generate-candidates \
  --campaign localtmp/new_campaign_prepared/campaign.json \
  --output-dir localtmp/new_campaign_candidates
```

The new output directory must not exist. Its `campaign.json` readiness marker
binds the prepared inputs and exact deterministic creation evidence for all
thirty contenders. Candidate creation alone does not run or authorize promotion.

Prepare the first competitive manifest and its independent fairness report:

```bash
tools/roster-campaign prepare-round \
  --campaign localtmp/new_campaign_candidates/campaign.json \
  --output-dir localtmp/new_campaign_round1
```

This writes one schema-2 competitive manifest with 35 cyclic-shift matchups,
equal participation, full opponent coverage and a pair-matchup spread no larger
than two. The seed is the user-specified `0,1,4,6,11,17,23,31,32`.
Show the full manifest, number-to-profile mapping, fairness report and budget
to the user before any competitive execution. No continuation instruction
substitutes for approval of the displayed manifest checksum.

The actual second manifest is prepared only after validated round-one results
supply exactly 25 survivor IDs. Add the five protected strategic controls,
shuffle the 30 identities using the recorded round-two ordering stream, then
apply modulo-30 cyclic shifts and obtain separate manifest approval. Legacy
models never enter competitive tables. A pair-matchup spread of two is allowed
in both rounds; complete pair coverage is mandatory independently of spread.
