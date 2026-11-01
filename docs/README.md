# Documentation Index

## Authority

- [`ProjectDescription.md`](ProjectDescription.md) is the normative product
  specification and poker-rule authority.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) is the authoritative implementation
  design. It may refine structure but cannot change the product rules.
- Current GUI layout principles are specified in
  [ProjectDescription §7.1](ProjectDescription.md#71-gui) and implemented under
  [ARCHITECTURE → GUI adapter](ARCHITECTURE.md#gui-adapter). Dated galleries,
  retired reference measurements and completed-task wording are historical
  where superseded by RG-63–RG-66. Final preview/device acceptance and cleanup
  evidence are preserved in the archived GUI record below.

Tests must generate any `localtmp/` inputs during the current run; ignored
session evidence is never a test prerequisite. See the [testing rules](../devdocs/how-to/running-and-testing.md#5-code-quality--pre-commit-verification).

## Current task index

This is the single entry point for active work. Follow the first unchecked task
in the selected backlog unless the user explicitly selects another task or
section. Keep completion evidence and checkboxes in the owning backlog.

- [`BotRosterExpansionTasks.md`](BotRosterExpansionTasks.md) — BRE-00–11 verified; the user-approved twenty-profile roster is published and active as `curated_v3` (25 strategic profiles, 28 entries total). Scoped final verification is complete.
  Automate fair two-round selection of 20 published strategic profiles from
  30 contenders, with equal participation, complete opponent coverage, explicit approval of both competitive manifests, one
  consolidated human promotion review, and activation in the game roster.

## Archived task records

- [`arkiv/BotFoldVsCallAfterRaisesTasks.md`](arkiv/BotFoldVsCallAfterRaisesTasks.md) —
  complete: BFCR-00–10. The v3 follow-up restores context-sensitive re-raising
  and selective bluff opportunities while preserving fixed-state call quality
  and the four existing profile parameters. Calibration and fresh confirmation
  pass balanced criteria; full verification passes 956 Godot tests, 254 Python
  tests, 17 layout checks and all four GUI invariant gates. Game interfaces
  and profile Resources are unchanged.

- [`arkiv/GuiProfileHoverTasks.md`](arkiv/GuiProfileHoverTasks.md) — complete, independent
  workstream: hovering a bot seat's display name reveals its public bot profile
  name. The user accepted desktop and compact long-name previews on 2026-11-01.
  Full checks pass with 914 Godot tests, 237 Python tests and all four GUI
  invariant matrices. Native evidence remains separate from browser/device
  acceptance. The requested larger player-details box now includes the public
  profile line and fits complete text without scrolling when space permits;
  follow-up regression passes 916 Godot tests. This preserves the accepted GUI
  replacement baseline.

- [`arkiv/GuiSpaceWarningTasks.md`](arkiv/GuiSpaceWarningTasks.md) — complete: configure
  the space warning, defaulting to best-effort play with edge overflow.

- [`arkiv/CiLayoutTasks.md`](arkiv/CiLayoutTasks.md) — complete: Actions skips
  `test_gui_*.gd` and `*_matrix_runner.gd` by default. `RUN_GUI_TESTS` and
  `RUN_GUI_MATRIX_TESTS` independently restore those groups; both true enable
  eleven native jobs, including disjoint M3 shards. Non-GUI quality checks remain
  required; local full gates retain all matrices. Timing reports and local
  verification pass; hosted performance awaits a new Actions run.

- [`arkiv/RulesInGameTasks.md`](arkiv/RulesInGameTasks.md) — completed independent workstream:
  GUI Start → Rules and interactive CLI `rules` share one tournament-reference
  document. RIG-00–05 are verified; the user accepted native Start/Rules previews
  on 2026-10-31. Full checks pass with 889 Godot tests, 227 Python tests and all
  four GUI invariant matrices. Browser/physical-device coverage remains separate.
  This work does not reopen the accepted GUI restructuring baseline.

- [`arkiv/RestructureGuiTasks.md`](arkiv/RestructureGuiTasks.md) — GUI restructuring,
  physical-browser corrections and Phase 9 cleanup implemented and verified.
  RG-80–RG-82 were explicitly user-accepted on 2026-10-31. Final verification
  passes 863 tests, all four native GUI matrices, 138 strict browser layouts,
  fourteen input cases and 25 geometry cases; all 142 exported captures match
  the accepted baseline. FINISH is complete: the user reviewed and approved the
  diff; cleanup commit `edfc603` is pushed to `origin/gui-restructure`.
- [`arkiv/MinimumRaiseTasks.md`](arkiv/MinimumRaiseTasks.md) — completed
  street-local minimum full-raise increments and GUI/CLI verification;
  MR-00–MR-06 user-accepted after testing with no reported errors (2026-10-28).
- [`arkiv/AstraSuggestionTasks.md`](arkiv/AstraSuggestionTasks.md) — historical
  correctness, GUI, maintenance and CLI work; its evidence does not complete
  the replacement GUI's implementation or device acceptance tasks.

- [`arkiv/OptimizingPhoneGuiTasks.md`](arkiv/OptimizingPhoneGuiTasks.md) — historical
  phone review and acceptance evidence; open recorded device checks are not
  completed by archive placement or automated gates.
- [`arkiv/LanTestTasks.md`](arkiv/LanTestTasks.md) — completed LAN workflow;
  user accepted resolution limitations. Current commands live in the
  [LAN how-to](../devdocs/how-to/local-wifi-web-testing.md).
- [`arkiv/OptimizingDesktopGuiTasks.md`](arkiv/OptimizingDesktopGuiTasks.md) —
  implementation tasks checked; exact hosted measurements and visual acceptance
  were not recorded. Archive placement does not certify acceptance.
- [`arkiv/OptimizingIpadTasks.md`](arkiv/OptimizingIpadTasks.md) — historical
  physical iPad acceptance, limited to its recorded evidence.

Local screenshots and logs under ignored `localtmp/` are session evidence,
not portable repository artifacts. Missing local captures cannot be recreated
as historical evidence; retain their recorded names and limitations.

## Specifications, runbooks, and guides

- [`Simulation_And_Evolutionary_Bot_Strategy.md`](Simulation_And_Evolutionary_Bot_Strategy.md)
  — simulation manifest/report contract, metrics, privacy, and profile
  evolution, including curated-roster baseline export.
- [Preparing and comparing bot experiments](../devdocs/how-to/preparing-bot-experiments.md)
  — strict configuration, generated manifests, compatible cohorts and pending review.
- [`POKERCARDS_IN_CLI.md`](POKERCARDS_IN_CLI.md) — interactive CLI card text
  format.
- [`OPTIONAL_WEB_SETUP.md`](OPTIONAL_WEB_SETUP.md) — automatic `main`-branch
  Web publishing and optional hosted browser/device verification runbook.
- [`ProvisionalGUILayoutGuidance.md`](ProvisionalGUILayoutGuidance.md) —
  provisional responsive Godot GUI guidance consistent with the architecture.
- [GUI composition](../devdocs/reference/gui-composition.md) — reusable scenes,
  layout ownership, detached presentation models, viewport fit and input flow,
  illustrated with Mermaid diagrams.
- [`GuiModelCoverage.md`](GuiModelCoverage.md) — RG-21 old-to-new presentation
  coverage map, retained adapter checks and measured runtime.
- [`GUI_VISUAL_TESTING.md`](GUI_VISUAL_TESTING.md) — canonical GUI viewport and
  state fixtures, screenshot evidence, review, and local gate workflow.
- [`templates/GUI_DEFECT.md`](templates/GUI_DEFECT.md) — standard record for GUI
  visual, layout, reachability, and hosted-presentation defects.

## Archived history

[`arkiv/`](arkiv/README.md) preserves superseded plans and completed task history,
including the completed core, CLI, GUI, simulation, and release-readiness
backlogs and the accepted iPad optimization record. Its files are historical
evidence, not active requirements or backlogs. All documents under `docs/arkiv/`
are historical legacy records. Their internal links may be invalid and are
excluded from the documentation gate; current documents remain validated.
