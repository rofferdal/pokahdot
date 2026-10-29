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
  unified geometry/classification, pure presentation models, component scenes,
  themes and container-owned responsive layouts. RG-00–RG-11, including
  RG-11R–RG-11R6 follow-ups, implemented and verified. Keypads, revised Start
  and review7 phone previews accepted; final short-phone and seven-way-winner
  boundary previews await review. Stopped before RG-12 at the user's request.
  The subsequent RG-11R7 LAN diagnostic regression is fixed and verified by
  a successful rebuild; RG-12 remains untouched.


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
