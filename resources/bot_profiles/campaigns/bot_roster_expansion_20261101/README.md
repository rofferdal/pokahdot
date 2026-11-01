# Bot roster expansion — 2026-11-01

This record binds the user-approved `curated_v3` publication: twenty selected
profiles, plus five protected hand-authored strategic and three optional legacy
profiles in the game catalog. Amber Horizon replaces Copper-Blaze Venture;
all other round-two finalists and names are retained. Six incumbent Resources
are retained and fourteen new Resources are published.

## Publication policy and evidence

This directory contains development evidence and is excluded from Web game
packs. Publication provenance JSON is also excluded. The playable `.tres`
profiles remain runtime resources; their roster membership is unchanged.

The explicit policy is `campaign_human_selection_publication_v1`. The user
approved the revised selection and publication in place of the strict
benchmark-performance gate. This is a human selection decision, not a claim
that all twenty passed strict confirmation.

`selection.json` preserves the pre-approval snapshot: its `pending` policy
status and `publication_authorized_under_current_policy: false` describe the
original strict policy. The later `human_publication_review.json` explicitly
supersedes that pending decision under the separate human-selection policy;
`publication_result.json` records completed publication.

- [Final official roster](FINAL_ROSTER.md) and [all thirty final outcomes](final_outcomes.json).
- [Frozen campaign and lineage](campaign.json).
- [Original round-one comparison](round1_comparison.json) and
  [original round-two comparison](round2_comparison.json): immutable simulation
  rankings, cuts, fitness components and report references.
- [Revised selection](selection.json): exact frozen identities, parameters,
  names, single swap and original evidence bindings.
- [Explicit human review](human_publication_review.json): policy authorization
  and decisions bound to the selection and original comparison checksums.
- [Publication result](publication_result.json): all twenty resource paths,
  SHA-256 values and policy-specific provenance sidecars.
- [Strict confirmation assessments](strict_confirmation_assessments.json):
  archived summaries of the original findings. These summaries are not
  independently replayable confirmation envelopes. The original complete
  confirmation envelopes and embedded raw reports remain in the session's
  ignored `localtmp/bot_roster_expansion_20261101/promotion_review/` directory.

The revised twenty include one strict confirmation pass, eighteen failures,
and Amber Horizon with no independent confirmation batches. Original strict
confirmation validators and their results were not modified. The complete
competition and confirmation workflow ran 40,095 tournaments, excluding the
throughput pilot; every campaign tournament started nine strategic profiles.
Legacy models did not participate.

## Validation and reproduction

`tools/profile_evolution/campaign_publication.py` provides `validate_selection`,
`approve_selection` and `publish_selection`. Load the checksummed selection,
original round-two comparison and human review using
`tools.profile_evolution.artifacts.load_artifact`. `approve_selection` must
recreate the exact review from its recorded explicit approval;
`publish_selection` independently verifies that binding before writing any
Resources. It refuses existing new publication destinations and preserves
retained incumbent Resources. Reproduction must use a separate checkout or
output root with the six original incumbent Resources; do not overwrite this
publication or its sidecars.

The strict confirmation-based `tools/profile-evolution publish-profile` path
remains unchanged and rejects failed confirmation. Game activation is the
separate source-controlled membership in
[`PlayableBotRoster`](../../../../scripts/core/agents/playable_bot_roster.gd).
Tests generate temporary inputs from tracked fixtures and never require this
session's `localtmp/` reports. See the
[owning backlog](../../../../docs/arkiv/BotRosterExpansionTasks.md) for task status,
validation evidence and the full decision history.

The [strategic baseline](strategic_baseline.json) contains the 25 active strategic
profiles, 25 nine-player matchups and 2,250 planned tournaments. Godot CLI
validation passes; no baseline games were run. The full 28-profile catalog
export is an inventory snapshot in the session directory and is not campaign
simulation input.

[Final verification](verification.json) records passing 424 core/simulation and
225 evolution/campaign tests. The test scope follows the updated `AGENTS.md`:
unchanged GUI/CLI suites were not rerun during final verification. The initial
full run found four stale expectations; all nine tests in their corrected
integration files pass. See the backlog for the exact execution history.
