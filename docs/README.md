# Documentation Index

## Authority

- [`ProjectDescription.md`](ProjectDescription.md) is the normative product
  specification and poker-rule authority.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) is the authoritative implementation
  design. It may refine structure but cannot change the product rules.

## Current task index

This is the single entry point for active work. Follow the first unchecked task
in the selected backlog unless the user explicitly selects another task or
section. Keep completion evidence and checkboxes in the owning backlog.
- [`RestructureGuiTasks.md`](RestructureGuiTasks.md) — GUI replacement in progress:
  viewport normalization and RG-11 review corrections verified. RG-12's pure
  size/fit policy and isolated guidance scene are implemented and verified;
  guidance design user-accepted. RG-13 replacement policy routing is verified;
  RG-20 presentation models and RG-21 coverage migration are verified.
  RG-30 theme palette/review3 is verified and user-accepted. RG-31 compact/regular
  typography and reference font-scaling removal are verified; the dealer/blind
  markers, winner-star appearance/placement and status alignment are user-accepted.
  RG-39 reusable controls are next after the requested commit/push checkpoint
  and reference-typography preview. Replacement component composition remains
  in its ordered tasks.

- [`RulesInGameTasks.md`](RulesInGameTasks.md) — planned, independent workstream:
  a concise Pokahdot tournament-rules reference from the GUI Start screen and
  interactive CLI `rules` command. Implementation is not started; this plan
  does not change the GUI restructuring sequence or its acceptance status.

- [`GuiProfileHoverTasks.md`](GuiProfileHoverTasks.md) — planned, independent
  workstream: hovering a bot seat's display name reveals its public bot profile
  name. Implementation is not started; this plan preserves the GUI replacement
  sequence and pending visual acceptance.


## Archived task records

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
