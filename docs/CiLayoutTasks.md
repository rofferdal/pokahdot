# Parallel CI layout checks

Status: Complete (2026-10-31), including CI-03 and CI-04. Requested: 2026-10-31.

Keep full local native-layout/release checks and support independent matrix
groups on separate GitHub Actions runners. CI-04 follows the later explicit
request to disable matrix runners by default in Actions, with a repository
setting to restore them. Add fixture progress and timing without changing layout algorithms,
frame limits or test assertions. Include the subsequently requested slow
`test_gui_phone_table_layout.gd` suite in its own required CI job, with exact
coverage partitioning from the ordinary GUT suite. Diagnose the broader hosted
slowdown with runner CPU/memory details, timing summaries and XML artifacts.

- [x] **CI-00 — Split CI execution without dropping coverage.**
  Status: Complete. Four characterization targets, the complete phone-layout
  unit suite and four existing invariant targets initially ran in nine shared native
  jobs, alongside shared quality checks. Local `check`, `release-candidate-gate`
  and `web-release` remain complete. The PR status retains its name and rejects
  failed, cancelled or skipped dependencies. Deployment requires both shared
  workflows before export of the same pushed SHA. actionlint 1.7.12 passes;
  all sixteen aggregate-result combinations and coverage-contract tests pass.
- [x] **CI-01 — Add progress and verify the contracts.**
  Status: Complete. Fixture START/DONE logs identify elapsed time and requested
  or observed frame counts. The phone suite reports all 120 state combinations,
  24 capability cases and twelve envelope comparisons. Before refactoring,
  characterization and release-contract tests pass. Afterward, full `make check`,
  all four characterization shards, and all four invariant matrices pass.
  At CI-01 verification, quality passed 882 tests and phone passed eleven, covering the
  same 893 unit/integration tests as the ordinary full GUT run. All 117 quality
  script paths were reconciled against discovery. Partition tests cover future
  files, missing partitions and configuration preservation. Report tests cover
  empty/failed execution, missing scripts and timing order; a real GUT XML
  sample was generated and summarized. Lint and format checks pass.
- [x] **CI-02 — Reconcile current CI guidance.**
  Status: Complete. Updated root README, architecture, Web deployment and GUI
  visual-testing guidance, developer test commands and the documentation index.
  Historical records are preserved. `make docs-check`, actionlint and
  `git diff --check` pass. Timing artifacts and summaries describe measured
  execution; hardware logs separate hosted resources from local assumptions.

- [x] **CI-03 — Split the remaining serial M3 invariant job.**
  Status: Complete. Baseline, three shards, the full four-category invariant
  gate and `make check` pass (895 unit/integration tests). Preserve all 99 cases in three required CI shards:
  supported layouts (27), wide public states (40), and phone public states (32).
  Keep the full local gate, fixture identities, validation and wait limits.
  Verify disjoint exact coverage, each shard, other invariant categories and
  the full suite. Reconcile current job-count/command documentation. Evidence:
  `localtmp/ci-layout-m3/`; hosted wall-time remains to be measured.

- [x] **CI-04 — Make matrix runners optional in GitHub Actions.**
  Status: Complete. actionlint, both workflow selection contracts, partition
  tests, all sixteen aggregate-result cases and documentation checks pass.
  User explicitly requested builds
  without `*_matrix_runner.gd`. Actions defaults to excluding those suites.
  Repository variable `RUN_GUI_MATRIX_TESTS=true` enables all eleven native
  jobs; otherwise the complete phone-unit job remains required alongside
  quality checks. Quality discovery excludes matching matrix filenames even
  if they later appear in ordinary test directories. Local full checks remain
  unchanged. Update current coverage guidance and verify both selections.

Evidence under `localtmp/ci-layout/`: `baseline-characterization.log`,
`baseline-release.log`, `check.log`, `quality.log`, `phone-unit.log`,
`shard-*.log`, `invariants.log`, `contracts.log`, `aggregate-results.log`,
`partition.log`, `diagnostic-tests.log`, `sample.xml`,
`sample-timing-summary.md`, `actionlint.log`, `lint.log`, `format.log` and
`docs-check.log`. Verification used native macOS Godot 4.7.2 headless. Hosted
runner queue time and actual parallel wall-time improvement require a subsequent
GitHub Actions run; no hosted performance improvement is claimed yet.
