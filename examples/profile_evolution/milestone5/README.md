# Milestone 5 executable evidence

This directory preserves a small, deterministic end-to-end run of the
external profile-evolution workflow. It is smoke evidence for mechanics and
promotion safeguards, not a claim that the tiny sample sizes establish a
strong poker profile.

The history starts with 11 generated candidates in `generation_0.json` and a
real 22-tournament Godot report. Fitness and 20% elitist selection feed seeded
crossover and mutation, producing the two candidates in `generation_1.json`.
Their evaluation, the selected historical benchmarks, and all creation
provenance are rebuilt into `lineage_registry.json`.

The final candidate was independently checked in two disjoint real-engine
batches:

- `mirrored_confirmation_report.json`: four cyclic heads-up tournaments
  against the built-in `balanced` legacy profile and a selected generation-0
  historical champion.
- `mixed_confirmation_report.json`: three cyclic three-player tournaments
  containing the candidate, legacy profile, and historical champion.

`confirmation.json` is immutable historical smoke evidence from before the
fixed `promotion_evidence_v1` contract. It records that the candidate was not
promotion-eligible because the mixed batch observed invalid-action fallbacks;
under the current policy, its four- and three-tournament batches are also
exploratory-only because they are below 300 tournaments per matchup and 100
candidate observations per seat. The files prefixed with
`rejected_candidate_` preserve the same historical gate rejecting the other
generation-1 candidate. These artifacts are not rewritten to claim current
provenance or policy compliance. Consequently there is intentionally no
candidate bundle: `export-candidates` rejects ineligible confirmations, and no
command in this workflow edits the playable roster.

Run the Python contract tests with:

```sh
make profile-evolution-test
```

The complete repository validation remains:

```sh
make check
```
