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
  where superseded by RG-63–RG-66. Preview/physical acceptance stays in the backlog.

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
  RG-39 reusable controls are implemented, verified and user-accepted.
  RG-40 cards and center board are implemented, verified and user-accepted.
  RG-41 seats and human panels and RG-41R review refinements are implemented
  and verified; review2 is provisionally user-accepted, with gameplay review
  remaining in the final acceptance milestones. RG-42–RG-45 phone tokens, action
  controls, event history and in-canvas overlays/keypads are implemented and
  verified by the complete check and all four GUI matrices. Combined component
  design review is complete. The user accepted the RG-45R opponent
  layout, component galleries, event-history scaling, menu and summary designs.
  The portrait keypad arrangement is accepted with clarified deletion/Cancel
  and Pot amounts; compact landscape is selected when needed. RG-45R3 refines
  its inline value and single-line limits header; this design is user-accepted.
  The Phase 4 checkpoint is committed and pushed. RG-50 seat-ring templates and
  native container are implemented. RG-50R lowers the human seat, aligns its
  action rail and centers the upper pair with avatar-width spacing. Revised
  six/nine-seat placement and RG-50S interiors are accepted (1,005 tests pass).
  RG-51 wide previews and all revised RG-52/53 phone previews are user-accepted.
  Symmetric landscape placement and the narrower centered portrait human panel
  are implemented and verified (1,102 tests pass). RG-51–RG-53 are complete;
  the Phase 5 checkpoint is committed and pushed. RG-60–62 replacement test
  coverage, exported layout and font-parity gates are complete. The replacement
  is the default, and RG-54 retirement and final verification are complete. The
  user accepted its phone-portrait, phone-landscape and wide synthetic layouts
  on 2026-10-30. RG-63–RG-66 follow-up implements symmetric tablet pairs, a centered
  human, upper-right markers, phone browser fit and fullscreen entry/retry,
  with avatars and inline Min/Pot retained. Automated verification passes
  (863 tests, four native matrices, 138 strict browser layouts and fourteen input
  cases). The centered six-player iPad layout and proportional lower-right hole
  cards are visually accepted. The latest physical Chrome review reports no
  remaining errors across desktop, phone and iPad. Proportional upper-left
  avatars are implemented and verified; RG-63–RG-66 are complete. Broader device/
  gameplay acceptance remains open.

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
