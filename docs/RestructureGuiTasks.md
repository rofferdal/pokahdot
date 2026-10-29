# Restructure GUI Tasks

Status: In progress — RG-00–RG-11 and RG-11R–RG-11R7 are implemented and
verified. Previously accepted keypads, Start and review7 phone previews retain
their recorded acceptance; the final two review8 boundary previews still
await review. The user requested a fresh `localtmp/` and resumed ordered work on
2026-10-29. RG-12 policy and isolated guidance presentation are implemented;
verification is complete. The user accepted the guidance design and authorized
continuation on 2026-10-29. RG-13 replacement routing is implemented and
verified and committed at `122f344`. RG-20 presentation models are implemented
and verified. RG-21 coverage migration is verified. The RG-30 theme review
candidate is authored, verified and user-accepted. RG-31 typography is implemented
and verified, including user-selected removal of reference font scaling.
RG-39 is next, after the commit/push and reference-typography review checkpoint.
Replacement component styling remains pending in its ordered tasks.
Reviewed: 2026-10-27 against source commit
`0669f41b7fc203d60640a6250f661b933ee33247` and the current working tree.
This documentation review is not RG-00 baseline execution or device acceptance.
Owner mode: Tech Lead / Architect for Phase 0–1 decisions, Senior Software
Engineer for implementation, QA for Phase 6.

This backlog contains an analysis of the current Godot GUI against common
practice for responsive GUIs on desktop browsers, iPad and phones, an
assessment of the GUI tests, a target structure, and ordered tasks for a
structured refactoring. The target principles in this document lead the
redesign; the current implementation is a migration baseline, not a reason to
retain competing geometry owners or runtime-built presentation. The
[product specification](ProjectDescription.md) owns product rules and the
[architecture](ARCHITECTURE.md#gui-adapter) describes implemented behavior.
Proposed changes below must be recorded as future decisions before those
implementation descriptions are replaced. If implementation would contradict
product requirements or an approved architectural decision, stop and ask the
user to resolve that specific conflict. Do not silently weaken the redesign
or change requirements to make an implementation task pass.

This backlog is self-contained. Other `docs/*Tasks.md` files, active or
archived, are not inputs and may be outdated. Do not read their checkboxes
as requirements, do not wait on their open tasks, and do not update them from
this work. If one of them conflicts with this document, follow this document,
the product specification and the architecture. Device acceptance for the
restructured GUI is tracked in Phase 8 below.

## Execution scope clarified by the user — 2026-10-28

Prioritize idiomatic responsive Godot layouts driven by available space and
measured content. Historical screen dimensions are regression samples, not
fixed design targets or a device whitelist. Support desktop physical-keyboard
input and touch on tablets/iPads and phones in both portrait and landscape.
Input modality remains independent of layout size/class. Use container minimums,
anchors, theme metrics and finite fit plans to adapt compositions while keeping
required content readable and targets reachable.

The replacement now targets phone landscape explicitly. Earlier deferral labels
in the recorded reference baseline describe legacy evidence; they do not defer
the new landscape implementation or acceptance. RG-12, RG-52 and RG-80 must
cover both phone orientations. Acceptance remains pending until implementation,
verification and the user's visual/device review.

Additional presentation clarifications (2026-10-28): the complete seat
component owns both its visible panel and the permanently reserved action/
showdown band beneath it. Winning hand/result descriptions use bold, bright
yellow text, including split/side-pot winners. Seat copy may scale down to
18 logical/CSS px (user confirmed); card ranks and other GUI text retain 20 px,
and touch targets retain 48×48. A hidden docked log remains accessible through
a Log action or reachable menu in every layout, including completed hands.
These are explicit RG-20/30/31/41/43–45/51–52/80–82 requirements; implementation
and visual acceptance remain pending in their owning tasks.

Control-style clarification (2026-10-28): every visible action, including
Quit, uses the shared rounded dark-green/white-text button presentation.
Number/text fields use sharp corners, white backgrounds and dark-green text.
Keypad keys belong to the button family; entry/value fields belong to the field
family. RG-30 defines the theme states and RG-39 authors the reusable controls
before their composition into other scenes.

Preview feedback (2026-10-29): reduce event-history text to 18 logical/CSS px
to show more lines, as a dedicated log-body exception to the 20 px floor for
other non-seat text. Preserve the shared top and bottom alignment of the docked
log, human panel and action area. Upper corner seats must clear the rounded
felt border, not merely fit its rectangular bounds. Keypad digits always use
`1 2 3 / 4 5 6 / 7 8 9`, with `0` directly beneath `8`, including compact
landscape. Reflow utility controls separately rather than widening the digit
grid to five columns. RG-11R revises the previews; RG-30/31/44/45/50/51 retain
these contracts in the replacement. The original previews are not accepted.

Seat-row clarification (2026-10-29, user confirmed): every horizontal row on
every screen/layout contains at most three player seats, including the human
when it occupies that row. This applies to all supported player counts and
both orientations, not only the upper row or one device family. Preserve
the later stricter phone-portrait rule: at most two opponents per row, with
one centered top seat for odd opponent counts. Preserve
clockwise seat identity and complete footprints when selecting more rows or
ring levels. Tiny vertical offsets do not turn a four-seat row into compliance.
RG-11R audits the reference; RG-12/42/50–52 and their tests must enforce the
cap through explicit row/slot composition, not a corrective collision pass.

Design independence reaffirmed by the user (2026-10-29): the legacy layout
does not constrain the new GUI on any screen. Its positions, row arrangements,
breakpoints, runtime-built hierarchy and exact-pixel tests are reference
implementation details, not replacement acceptance requirements. New layouts
may change all of them to satisfy the user's visual rules and measured fit.
Keep behavioral/privacy/input coverage; replace incidental structure checks
with independent component and container contracts. Legacy violations neither
justify exceptions in the new layout nor require a detour to redesign the old
GUI before implementing the replacement. RG-11R is only the selected preview
correction, not a template the replacement must reproduce.

Capacity/priority clarification (2026-10-29): prioritize measured phone fit
because it is the most constrained layout. Use the existing 2–7-player phone
scope as the working target in both orientations; larger tablet/desktop
layouts support 2–9. Seven-player phone fixtures are required stress cases
through component minimums, model density, action flow and final composition,
not a late reduction of a desktop design. Keep the role-specific text floors,
48×48 touch targets, exact required copy and three-seat row cap. Define and
test feasible envelopes; insufficient space shows guidance rather than shrinking
controls, hiding players or changing an active tournament's count. This
clarification changes fixture priority, not the ordered execution of tasks.

Keypad review refinement (2026-10-29): the user accepts the 3×3+centered-0
number arrangement and explicit value limits, but rejects the ragged utility
arrangement. Utility buttons must form a neat, filled rectangle with aligned
columns and uniform cells. Numeric entry contains no tournament Quit action.
Cancel discards the draft and leaves the committed field unchanged; Done
commits the draft for adapter validation. Tournament Quit remains outside number entry, reachable
after cancelling/closing it. RG-11R2 implements this revision; RG-39/45 inherit
the same presentation and responsibility boundary.

Earlier table review (2026-10-29; Total palette superseded below): the user accepts the revised 1280×720
table presentation except for the Total entry field, which still resembles an
action button. Apply the already-required white surface, sharp corners and
dark-green field text/caret/placeholder in normal, focused and read-only
states; preserve action-button styling for Raise. RG-11R3 makes this bounded
preview correction. It does not complete the authored RG-30/RG-39 theme/control
replacement. The forthcoming new wide layout must also show nine players for
review, with at most three seats in any row; the old layout is no constraint.

Latest review (2026-10-29, RG-11R4): the compact keypad is accepted only for
landscape aspect ratios; both portrait compositions remain accepted. The
table is accepted apart from a revised Total preference: light-grey text on
dark green, zero-radius rectangular corners and a slightly shorter face
vertically centered with Raise. Preserve a full 48 px interactive allocation;
draw a centered 40 px face at the 48 px baseline via StyleBox margins. This
Total-only variation supersedes its earlier white palette, not generic input
styling. RG-30/RG-39 retain the `WagerTotalField` variation and distinct drawn/
interactive geometry; tests must not lower target-size floors to shrink a face.
The same review also requires the table Quit control to have the rounded
rectangle border and interaction states of the action-area buttons. Reuse the
existing shared action-style application; tournament Quit remains outside
numeric entry. This is included in RG-11R4, not a separate layout redesign.

Branding/text refinement (2026-10-29, RG-11R5): use the supplied Pokahdot logo
above the Start-screen form and subtly embossed into the table cloth behind
game content, allowing partial obscuring. Convert the JPEG's baked checkerboard
to a genuinely transparent PNG (`assets/images/Pokahdot_logo.png`) and use
that shared asset in both places. Preserve aspect ratio, passive input behavior
and table geometry. The later review rejects startup scrollbars and any light
logo backing panel: fit essential controls by adapting optional copy and logo
allocation, retaining text/target floors. Total keeps its dark, sharp, shorter centered face,
but its grey text becomes slightly darker than the button labels (`#B8C3BB`
in this implementation). RG-30/39/45/51/52 preserve the branding and Total-role
contracts in the replacement; the logo component is reusable across cutover.

Earlier branding/phone review (2026-10-29): the user accepts branded Start-screen
layout at 390×844, 844×390 and 1280×720 apart from the light logo panel, which
must be removed for a transparent logo on the dark background. The 844×330
scrolling form is rejected: no Start-screen scrollbar is allowed. Desktop
embossed-table previews at 1280×720 and 1920×1080 are accepted. The phone
portrait table is rejected: redesign seat areas, move the full community group
immediately above the human area, and remove the surrounding table rim/margins
for a full green screen. New layouts must satisfy measured readability and
touch targets, not retain the rejected legacy arrangement. RG-11R6 is this
explicitly selected phone review task; RG-42/50–52 inherit its approved rules.
Subsequent acceptance: the no-scroll `rg11-review6-startup` captures and all
five `rg11-review7-*` two-column portrait captures are accepted. This completes
visual review of these increments; fresh broad verification remains required.

Visual-polish clarification (2026-10-29): the user permits GUI beautification
where it follows sound design practice and preserves user-facing functionality.
The single-font constraint remains: use only Godot's built-in default font,
including variations derived from it. Preserve existing text/target floors,
required copy and input behavior, and show new visual designs for acceptance
before continuing beyond their review checkpoint.

Theme-review refinement (2026-10-29): the user generally likes the RG-30
palette, with three requested changes. Disabled action labels use a slightly
darker grey (`#A8A8A8` in the revised candidate); enabled/hover/pressed/focus
labels remain white. Larger-screen seat surfaces must display the selected
avatar from the existing tournament assignment; compact phones may omit it.
Cards must retain a width/height ratio of at least 5:7 (poker-card proportions)
or be wider, including their actual rendered allocation, not just nominal
minimums. Value and suit have comparable visual size, fit as large as measured
content permits, and retain padding from every edge. Preserve the single
built-in font. RG-30 revises the gallery; RG-31/40–42/50–52 must retain these
contracts in the actual components and layouts. The revised preview awaits
acceptance; RG-31 remains untouched.

Further theme refinement (2026-10-29): folded seat surfaces, borders, text and
avatars must be fully grayscale. Give the human seat more reading space than
bot seats where the wide composition permits it; increase the human's text and
avatar allocation rather than scaling its painted pixels. Strengthen the acting
white border beyond the initial three-pixel candidate (six pixels in review3).
Increase card value/suit occupancy by measuring visible glyph bounds instead
of reserving unused font line leading. Retain safe padding, the single built-in
font, 5:7-or-wider card proportions and role-specific text floors. Cards must
be scalable with container space; the gallery's fixed 120×168 samples and
90/91 px fonts are examples, not production size constants. RG-30 revises this
preview; RG-31/40/41/50–52 carry the contracts into responsive components.
Review3 acceptance remains pending before RG-31.

### Visual instructions → implementation and acceptance

This table traces the user's chat instructions to the resulting GUI and code
structure. It specifies required replacement behavior, not completed work;
the checkboxes in the owning tasks remain the completion record.

| User instruction | Required GUI behavior | Code-structure impact / owning tasks | Acceptance evidence |
| --- | --- | --- | --- |
| Adapt to screens rather than copying old dimensions | Desktop keyboard and tablet/phone touch work in both orientations; resizing and rotation retain readable content and reachable actions. | One viewport adapter and size/fit policy; container-owned wide/phone compositions use measured component minima. Input modality is independent of size class. RG-10–13, RG-50–52. | Boundary/resize/safe-area sweeps plus physical reviews RG-80–82; historical dimensions remain regression samples. |
| Cards are a separate presentation component | Community, hero and opponent cards share face, back and empty-slot presentation. | Pure `CardViewModel`; reusable `PlayingCard` and `CardRow` scenes replace card factories and duplicated card construction. RG-20, RG-40–42, RG-54. | Render every state, rank `10`, minimum-size fit and recipient-safe hidden cards in every context. |
| A seat includes the text below its rectangle | The latest-action/showdown band stays allocated beneath the panel, including when blank; it cannot collide with neighbors. | `SeatPanel`, `HeroPanel` and compact `SeatToken` own their complete status footprint. Container minimum sizes and snapshots include the band, not just the drawn rectangle. RG-20, RG-41–42, RG-50–52. | Blank/action/two-line showdown cases preserve allocation and pass full-footprint containment and overlap checks. |
| Winning descriptions are bold and bright yellow | Every winning hand/result description uses bold `#FFFF00`, including split/side-pot winners and exact fold-win `Winner` text. | Models expose semantic winner emphasis; a shared `WinningHandText` theme variation renders it. Layout measures the bold font. RG-20, RG-30–31, RG-41–42. | Single/split/side-pot and fold-win component captures verify color, weight and complete text fit. |
| Seat text may shrink to the confirmed 18 px minimum | Seat names, stacks, markers and action/showdown copy can shrink within a bounded range; card ranks and other text stay at least 20 px, targets at least 48×48. | Role-aware compact/regular theme metrics and measured minima replace whole-tree font scaling. RG-30–31, RG-40–42. | Measure actual displayed sizes after viewport/DPR conversion and test long names, large values and bold showdown copy. |
| A hidden log must remain accessible | A reachable Log action/menu opens the same scrollable public history whenever docking does not fit, including completed hands. | One recipient-safe log model and reusable `EventLog`; `ActionBar`/menus expose access and `OverlayHost` owns the modal view. RG-20, RG-43–45, RG-51–52. | Activate Log in every composition and completed-hand/Pots state; verify history, scrolling, focus restoration and blocked underlying input. |
| Smaller log copy, aligned lower row and clear upper corners | Log body uses 18 px; docked log/hero/actions share top and bottom edges; no seat intersects the rounded felt border. | Dedicated log typography role, shared lower-row allocation and measured rounded-border clearance in the seat plan/container. RG-11R, RG-30/31/44/50/51. | Revised 1280×720 capture, exact row alignment and curved-border clearance checks; no other text-floor relaxation. |
| Conventional numeric keypad in every orientation | Digits stay in three ordered columns with centered 0 below 8. | Stable digit grid plus separately composed utility/actions; compact layout reflows surrounding regions. RG-11R, RG-39/45. | Portrait/compact-landscape captures and row/column order, fit, 48 px targets and transactional input checks. |
| Rectangular keypad utilities, no tournament Quit | Uniform utility cells form a filled rectangle; approved digits and visible limits remain. Cancel discards the draft; Done commits the draft for adapter validation. | One utility grid contains editing/preset/commit/cancel controls. Remove tournament-exit signal/button/wiring from number entry. RG-11R2, RG-39/45. | Inspect compact/portrait and plain-number/wager states; verify aligned cells, no Quit action, exact cancel/commit semantics and limits. |
| At most three seats side by side; two opponents in phone portrait | Every horizontal row contains at most three players. Phone portrait uses pairs; odd opponent counts start with one centered, equal-width seat. | Row/slot plans and content-derived minimums enforce these caps while retaining clockwise seat IDs and the human at the bottom. RG-11R6, RG-12/42/50–52. | Test every supported count and mode, including short phone portrait, 8/9-player wide layouts and live rotation; no cosmetic staggering to evade row limits. |
| Prioritize readable, tappable phone layouts; larger screens support nine players | Phones target 2–7 players and tablets/desktops 2–9, with readable copy and large enough actions. | Phone-constrained component minima and action flow inform unified fit policy and both compositions. RG-12/31/39–43/50–52. | Seven-player phone portrait/landscape stress fixtures, nine-player wide fixtures and live resize retain typography/targets and tournament state. |
| All actions, including Quit, share a defined button view | Rounded dark-green buttons with white text cover startup, wagering, menus, Quit, confirmations and keypad keys. | Shared theme variations and reusable `ActionButton`; compose it throughout components instead of local runtime styling. RG-30, RG-39, RG-43/45, RG-54. | Review normal/focus/hover/pressed/disabled states, keyboard/touch activation and minimum target sizes. |
| Fields must look different from buttons | Generic fields are sharp-cornered white/dark-green; Total uses light-grey on dark green with a shorter centered face. Touch entry retains its field presentation. | Separate `InputField`/`NumberField` and `WagerTotalField` theme variations; adapters retain validation and transactional drafts. RG-11R4, RG-30/39/43/45. | Compare normal/focus/read-only/error states, drawn face versus 48 px hit area, exact drafts and cancel/commit behavior. |
| Replace old code rather than accumulating wrappers | The finished GUI has clear owners and less custom responsive geometry. | Direct authored-component replacement; remove legacy factories, layout/collision helpers and reference-specific snapshot producers at verified cutover. See the retirement table below; RG-13, RG-39–54. | Record removed files and remaining geometry/build sites, preserve independent behavior coverage and remeasure code size at cutover. |
| Stop for acceptance when new design can be shown | Present each reviewable visual increment before continuing with later tasks. | Keep implementation status separate from user acceptance. Save screenshots under `localtmp/gui-elements/` when possible. | Every acceptance stop includes screenshots, the affected GUI behavior, a current file/component overview, Godot/responsive-layout rationale and explicit remaining legacy work. |

These requirements change presentation, component ownership and fit contracts;
they do not move poker rules into views or relax private-card protection.
Apply this checklist to tablet and desktop reviews as well as phone reviews.

## 1. Summary

The core/GUI separation, recipient-safe `GameView`, modal guard, transactional
keypad, input modality and Web DPR normalization remain sound foundations.
The proposed destination remains one viewport adapter, one classification
policy, pure presentation models, reusable component scenes, theme-owned
styling and container-owned layout, including a custom seat-ring container.

Some groundwork now exists. `PokerTableController` is 2,545 lines with 115
functions; `_layout_table()` is a 66-line coordinator. Typed seat, action,
overlay and layout helpers have replaced the earlier monolithic implementation.
All four diagnostic matrices already share one runner. These extractions are
useful migration boundaries, but most widgets are still built in code and the
layout helpers still apply manual geometry, competing classification predicates
and deferred collision/center corrections. They do not implement the target
scene/container architecture. Architectural quality and responsive behavior are
the acceptance criteria; reducing the diff or retaining existing GUI code is
not a requirement. A replacement GUI built from scratch is an acceptable
implementation strategy.

The migration must also preserve newer behavior: complete seat/status
footprints, clockwise core-seat order, measured card/name/stack copy, finite
phone content rows, default completed-hand winner presentation, and existing
modal/focus/keypad rules. The native/Web refresh profiler and exported-browser
layout runner are existing verification tools to extend, not new tools to
recreate. Keep the legacy GUI available as a reference while building the replacement,
using separate scenes or a temporary selector where useful. Reuse helpers only
when they fit the target design. Preserve product behavior and verification
coverage, not legacy node trees, pixel coordinates, visual defects or internal
APIs. Cut over only after the replacement and its tests satisfy the contracts.

## 2. Current structure and reusable foundations

The inventory below describes the pre-migration reviewed source, not current
acceptance evidence or size limits. RG-11 has since moved Window normalization
from startup to the app-owned viewport adapter.

| Area | Current files / size | Migration implication |
| --- | --- | --- |
| Controller | `scripts/gui/poker_table_controller.gd`: 2,545 lines, 115 functions | Still owns binding, copy, pacing, input and significant phone/desktop layout work; its main coordinator is already extracted. |
| Typed components | `gui_table_seat_factory.gd` / `gui_table_seat_view.gd` (491 / 55 lines), `gui_table_action_controls.gd` (196), `gui_table_overlay_views.gd` (129) | Reuse ownership boundaries and handles while replacing factories/runtime mutation with authored scenes. Handles are still discovered once by child name. |
| Layout policy/application | `gui_table_layout_pass.gd` / `gui_table_seat_layout.gd` (159 / 233), `gui_mobile_table_layout.gd` (515), `table_seat_layout.gd` (245) | Branching has moved into these helpers; changing only controller predicates would leave competing policy behind. |
| Finite plans | `gui_phone_layout_plan.gd`, `gui_phone_seat_layout.gd`, `gui_phone_token_content_plan.gd`, `gui_six_seat_desktop_plan.gd` | Preserve complete-footprint, content-fit and stable-seat-order contracts when moving their math behind containers. |
| Scenes / startup | `scenes/poker_table.tscn` (425), `scenes/main.tscn` (197), `startup_config_controller.gd` (414) | Table still mixes phone/wide nodes; startup is container-based but owns app-wide Web geometry normalization. |
| Theme / input | `resources/gui_theme.tres` contains only `default_font_size = 29`; `wager_keypad.gd` (350), `gui_modal_guard.gd` (138) | Move style and keypad construction into resources/scenes while preserving input transactions and modal lifetime. |
| Tests | 36 `tests/unit/test_gui_*.gd` files, 262 test functions, 9,005 lines; nine GUI support scripts | Current coverage is broader than the original inventory, but still coupled to internal structure. Non-`test_gui_*` startup/keypad tests also remain relevant. |
| Matrix runner | `tests/support/gui_invariant_matrix_runner.gd`, `gui_invariant_matrix_suites.gd`, `gui_phone_matrix_contract.gd` | Already consolidated. Preserve ordered case identities: 348 M3, 406 phone, 288 iPad, 232 desktop; four manual files are thin entry points. |
| Browser / performance | `tools/run_web_input_tests.py`, `tools/run_web_layout_tests.py`, `tools/web_layout_assertions.py`, `tools/profile_gui_refresh.py`, `tests/web/`, `tests/performance/` | Reuse observers, real `Window` geometry, order/content checks and profiling fixtures throughout migration. |

### Transitional size and retirement plan — 2026-10-28

RG-00 baseline `4e087960` versus the RG-11 working tree: production
`scripts/gui/` grew from 36 scripts / 7,226 lines to 49 / 8,355; the two scenes
grew from 622 to 626 lines. No production files have been removed. Counts exclude
`.uid` metadata and tests. The 13 additions comprise nine snapshot/measurement
scripts (557 lines) and four platform scripts (408 lines); existing scripts
grew by 164 lines. This is safety/viewport infrastructure, not completed GUI
simplification. The controller remains 2,651 lines. Measure these totals again
at cutover alongside custom geometry ownership and runtime widget construction;
component scene count alone is not a simplicity measure.

| Legacy files / family | Replacement tasks | Removal gate |
| --- | --- | --- |
| `gui_layout_profile.gd`, `gui_table_layout_pass.gd` | RG-12/13 unified policy | RG-54 after independent replacement coverage |
| `gui_mobile_table_layout.gd`, `gui_table_seat_layout.gd`, `table_seat_layout.gd`, `gui_six_seat_desktop_plan.gd` | RG-50/51 measured seat-ring and wide containers | RG-54 |
| `gui_phone_layout_plan.gd`, `gui_phone_seat_layout.gd`, `gui_phone_token_content_plan.gd` | RG-42/52 measured token/phone containers | RG-54; retain pure row-fit logic only if useful without fixed geometry ownership |
| `card_face_factory.gd`, `gui_table_seat_factory.gd`, `gui_table_seat_view.gd` | RG-40–42 authored card/seat components | RG-54 after all production/reference callers migrate |
| `gui_table_action_controls.gd`, `gui_table_overlay_views.gd`, keypad runtime construction | RG-39/43/45 shared controls, action bar and overlay host | RG-54; preserve transaction/focus contracts |
| `gui_table_style.gd`, `folded_seat_style.gd` | RG-30/31 theme variations and authored material where needed | RG-54 after style callers migrate |
| `gui_web_viewport_geometry.gd` | RG-11 viewport adapter | Remove after remaining reference/test callers migrate; production no longer uses it |
| Reference-specific `gui_table_snapshot_producer.gd`, `gui_startup_snapshot_producer.gd` | Replacement components expose semantic measurements | RG-53/54; retain the detached snapshot API, not permanent legacy wrappers |
| `scenes/poker_table.tscn` and old controller implementation | RG-51–53 replacement compositions and small orchestrator | RG-54 after RG-60–62; retain `main.tscn` as the composition root |

Remove a retired script's `.uid` after all references are gone. Reuse independent
assignment services, safe formatters, pacing and modal contracts where they fit.
Stop extracting further legacy builder/layout helpers: implement replacements
directly. RG-13 may use a small temporary policy bridge if necessary; replacement
layouts consume the new policy directly. Review consolidation of tiny snapshot
value files during cutover only if it improves clarity; that is not extra work
before the replacement. Final ownership and less custom layout code matter more
than forcing every reusable component into fewer files.

RG-31 timing clarification (2026-10-29): the user explicitly selected immediate
removal of font scaling in the reference GUI, including the recursive font
repair helper. That typography migration happens in RG-31; retirement of the
remaining reference scenes, factories and geometry owners stays at RG-54.

## 3. Analysis against responsive-GUI practice in Godot

### 3.1 Viewport, scaling and safe areas

The gaps below describe the pre-migration review. RG-10 measured the scaling
effects; RG-11 now owns normalization, safe-area intersection and export metadata
through the app adapter. They are retained here to explain those tasks.

The target needs a defined mapping between physical/backing pixels, browser CSS
pixels, Godot logical units and usable table-local coordinates. These are not
interchangeable, and DPR must not be applied twice.

- The reference used `GuiWebViewportGeometry` to convert backing size using
  screen scale; `StartupConfigController` applied it to
  `Window.content_scale_size` on Web. Move this ownership to the app adapter, preserving the existing startup/table
  behavior and leaving CLI/simulation processes unaffected.
- The reference had no implemented safe-area adapter or export `viewport-fit=cover`
  contract. Measure Web insets through a CSS probe and convert native mobile
  display-safe rectangles into window/logical coordinates. Preserve the usable
  rectangle's origin, not only its size, and subtract browser/inset reductions
  once. Headless tests must inject geometry instead of trusting display APIs.
- Native uses a 1920 × 1080 design viewport with `canvas_items` / `expand`.
  A smaller window can retain design-space coordinates while rendering them
  at a reduced scale. The effect on classification, output text and touch size
  needs an actual `Window` measurement in RG-10; a nominal 20-unit font is not
  proof of a 20-CSS-pixel or physical-pixel output. Do not infer physical text
  size from the base viewport alone.
- Headless scene fixtures mostly set `SubViewport`/Control geometry directly.
  The exported input and layout fixtures already mount production main and
  exercise Web normalization through the real `Window`; reuse that path.

### 3.2 Classification and fit policy still disagree

`GuiLayoutProfile.classify()` already has a fallback for every size. The issue
is inconsistent policy across owners, not the absence of a total function.

| Owner | Current input / policy |
| --- | --- |
| `GuiLayoutProfile` | Root size; phone short edge ≤ 600, long edge ≤ 920 and aspect ≥ 1.35; tablet and small-desktop ranges. |
| `GuiTableLayoutPass` | Root classification plus inset surface predicates, compact-tablet/full-ring conditions and helper-selected scales. |
| `GuiMobileTableLayout` | Surface-size portrait/tablet/small-desktop tests; small desktop `< 1300 × < 760`, unlike profile `< 1100 × < 760`. |
| `GuiSixSeatDesktopPlan.can_use()` | Six-seat desktop only, width below 1600 plus complete-footprint feasibility; it already bypasses legacy clearance passes when selected. |
| Remaining controller / seat helpers | Additional measured-center, numeric-copy, seat-count and height decisions, including short seven-/nine-seat compositions. |

A focused headless policy probe confirms `DESKTOP` plus mobile-portrait flags for
650 × 900, and `DESKTOP` plus legacy small-desktop sizing at 1250 × 700
(with the authored surface inset); 1377 × 777 instead selects the deterministic
six-seat plan. These are characterization cases, not
verified overlap defects. iPad portrait deliberately combines a tablet profile
with portrait geometry. Record observed results before declaring failures.

The replacement must classify one adapter-owned usable rectangle, then pass a
typed policy to components. Local measured-fit decisions (for example a third
content row or a container minimum size) remain necessary; they must not become
another set of global device breakpoints. Width/height class monotonicity is
specified per axis and orientation, not by ordering arbitrary profile enum IDs.

### 3.3 Layout ownership

Godot containers own the geometry of their direct Control children. The custom
seat container must implement `NOTIFICATION_SORT_CHILDREN`, use
`fit_child_in_rect()` and report content-derived minimum sizes. Its pure plan
must account for child minima; normalized anchors alone cannot guarantee fit.
See [Godot container guidance](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html)
and the [Container API](https://docs.godotengine.org/en/stable/classes/class_container.html).

Current manual/deferred geometry remains in the controller and extracted
helpers. The ordinary paths still call clearance/intersection resolvers;
the constrained six-seat desktop plan instead reserves complete footprints
before placement. Preserve that deterministic behavior while replacing all
paths with one container owner, not merely moving the old collision loops.
Phone token content has a finite measured-row plan now; preserve its exact
content and visibility rules rather than rebuilding them from old offsets.

A layout outside its declared minimum cannot fit arbitrarily many seats while
retaining the role-appropriate 18/20 px text floors and 48 px controls. Define feasible envelopes and an
explicit unsupported-size/guidance state. Existing supported canonical fixtures
remain mandatory; reducing their support requires an explicit user decision. Never silently clip required copy,
shrink type, drop players or change an active tournament to make a sweep pass.

### 3.4 Scenes, models and styling

The typed helpers are already useful boundaries but remain runtime builders.
`GuiTableSeatView` captures handles once; helpers still style/reparent controls,
restore metadata-backed state, and mix phone/wide nodes in one table scene.
Replace those implementations with authored component scenes and explicit
models while keeping the ownership improvements.

Presentation copy remains distributed across controller, seat/action helpers,
`ShowdownHandFormatter`, `GuiEventFormatter` and `TournamentStatusFormatter`.
Reuse the pure formatters. View models select recipient-safe content and action
availability; they call existing core helpers such as `PotWagerTarget` rather
than implementing poker validation or minimum-raise rules in the GUI.

Styling remains runtime-heavy: 54 `add_theme_*` call sites in the controller,
with further calls in extracted helpers, mobile layout, startup and keypad.
The theme still contains only a default font size. Move static palette,
StyleBoxes, variations and sizes into resources. Verify effective inherited
fonts and actual component/touch rectangles; theme values alone cannot certify
fit or button minimum size. Retain complete names, exact numeric values and
rank `10` measurement with the built-in default font.

### 3.5 Contracts to preserve

- Core/GUI separation, recipient safety and presentation-only assignments/RNG.
- Human at the bottom and opponents in clockwise core-seat order, including
  reordered view arrays and nonzero recipient seats.
- Whole seat/status footprints, `Winner` after fold wins, default phone winner
  copy/Pots access, exact awards and legitimately revealed cards.
- Phone 2–7 and larger profiles 2–9; an 8-/9-player match resized to phone
  keeps its state and shows guidance. The replacement must support both phone orientations with measured fit guidance.
- At least 18 px seat copy and 20 px card/other GUI text, 48 × 48 touch
  targets, full names/stacks and reachable history through a Log action/menu
  whenever its dock is hidden. Keep all existing numeric-bound cases.
- Modal exclusivity, held advancement, focus restore, Escape/engine-back,
  touch/pointer modality, and keypad commit/cancel behavior.
- Current profile-exit behavior cancels a phone wager draft without committing
  it; phone rotation preserves the draft. The target may preserve more state,
  but RG-45/RG-53 must explicitly resolve that change before replacing tests.
- `GuiActionPacer` and the two-second action / five-second completed-hand
  cadence. Component decomposition does not authorize changed game pacing.

## 4. Verification strategy

### 4.1 Reuse existing coverage

The existing invariant helper checks containment, overlap, clipping, font floors
and targets. Current tests also protect clockwise order, finite phone rows,
long names, large exact numbers, modal/keypad behavior and repeated resizes.
There are 15 canonical viewport fixtures with varied count sets; phone includes
7 players and iPad includes 7 and 9. Counts 3, 5 and 8 and broader automatic
classification paths still need systematic coverage.

`run_web_layout_tests.py` already drives production-main Window normalization,
resizes, geometry/content/order checks and DPR 1/2. Its default report mode can
retain failures while returning success; use `--strict` for a correctness gate.
The CI `Exported Web input` job already tests pointer/touch/keypad/focus and
showdown behavior, but is not yet the full layout/DPR matrix proposed here.

Native/Web refresh profiling and lifetime evidence already exist. The current
architecture retains disposable seat/card widgets in the existing runtime
builder because measured results did not justify retrofitting retention there.
That finding does not require a new scene-based GUI to reproduce the old
lifetime policy. Define explicit ownership for persistent component scenes or
disposable subcontent, render fresh safe models, and test privacy, focus, modal
and stale-content behavior. Profile the replacement against the baseline;
geometry-only resizes should avoid unnecessary reconstruction. A whole-view
cache is not a substitute for correct component lifetime.

### 4.2 Migrate contracts, not incidental structure

Many tests and both Web observers access internal nodes, private controller
fields and exact rectangles. A stable snapshot must cover every existing
invariant before deleting those dependencies: seats/status/cards, labels and
text-fit data, controls/targets, overlays, effective fonts, coordinate origins,
visibility, layout readiness and core-seat ownership. Preserve rejection tests
that deliberately expose a private card or introduce overlap; a snapshot that
omits the offending child must not produce a false pass.

Move pure copy/availability assertions to model tests, while retaining scene
integration tests that exercise real control activation, input modality,
`PlayerAction` submission and core rejection without state mutation. Reuse core
rule tests; do not reduce adapter tests to emitting a mocked signal.

Characterization sweeps are finite samples, not continuous proofs. Separate
cheap pure geometry/policy sweeps from a bounded rendered scene matrix, and
budget CI runtime before choosing grid steps. Include measured fit transitions,
±1 breakpoint cases, fractional DPR, safe-area origins and real resize streams.
Known failures need exact signatures and review; fail on regressions and on
unexpected passes until the record is updated. Unsupported sizes require an
explicit supported-minimum contract rather than blanket exceptions.

Nested containers can need multiple deferred passes after minimum-size changes.
Retain a bounded settle/readiness contract and detect non-convergence; do not
promise that one frame always settles a composition. Physical-device acceptance
remains separate from headless and exported-browser checks in Phase 8.

## 5. Target structure

```mermaid
flowchart TD
    VA[App-owned ViewportAdapter Node<br/>DPR, safe area, usable rect] --> SC[SizeClass.classify]
    SC --> TC[PokerTableController<br/>orchestration only]
    GV[GameView + assignments + action history] --> VM[TableViewModel<br/>pure RefCounted]
    VM --> TC
    TC -->|selects| PL[PhoneTableLayout.tscn]
    TC -->|selects| WL[WideTableLayout.tscn]
    PL --> C1[SeatToken.tscn]
    WL --> C2[SeatPanel.tscn / HeroPanel.tscn]
    PL & WL --> C3[CenterBoard.tscn]
    PL & WL --> C4[ActionBar.tscn]
    WL --> C5[EventLog.tscn]
    WL --> SR[SeatRingContainer<br/>custom Container + SeatSlotTemplate]
    TC --> OH[OverlayHost<br/>menu, summary, detail, quit, keypad, log]
    OH --> C5
    C1 & C2 & C3 --> CR[CardRow.tscn]
    CR --> PC[PlayingCard.tscn<br/>face, back, empty]
    C4 & OH --> AC[ActionButton.tscn / InputField.tscn]
    OH --> MG[GuiModalGuard]
    TH[Theme: base + compact/regular variations] -.styles.-> PL & WL & OH
```

Principles:

- **Design before reuse.** A full GUI replacement is allowed. Existing
  helpers are references and potential inputs, not mandatory target modules.
  Implement clean scene/container boundaries directly when adapting a helper
  would preserve competing ownership, hidden mutation or incidental structure.
- **One geometry source.** `ViewportAdapter` (an app-owned Node under
  `Main`, implemented in `scripts/gui/platform/`) owns Web normalization and safe-area insets and
  emits an immutable geometry snapshot plus `usable_rect_changed(rect)`.
  Define units, usable origin, window-to-logical transforms and inset ownership.
  On Web a CSS probe exposes computed `env(safe-area-inset-*)` values through
  `JavaScriptBridge`; audit the export viewport meta tag before enabling
  `viewport-fit=cover`. On native mobile convert/intersect
  `DisplayServer.get_display_safe_area()` with the app window before mapping to
  logical coordinates. Headless/non-GUI roots use a safe injected/no-op path.
  See the [DisplayServer API](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area).
- **One classifier.** `SizeClass.classify(usable_size, override)` returns a
  width class and a height class, plus one derived `LayoutMode` (`PHONE`,
  `PHONE_LANDSCAPE`, `WIDE_COMPACT`, `WIDE`). It is total:
  every positive size maps to exactly one mode; invalid or uninitialized sizes
  have an explicit not-ready result. Define feasible minimums and an
  unsupported-size presentation separately from classification. Components may
  compare measured content minima with their allocation, but only this policy
  owns global layout breakpoints.
- **Pure presentation model.** `TableViewModel`, `SeatViewModel`,
  `CenterViewModel`, `ActionBarViewModel`, `HandSummaryViewModel` and
  `CardViewModel` are built
  from `GameView`, the assignments and the public action history, with a
  density parameter (full/compact/minimal). They contain every player-facing
  string and enabled flag. `CardViewModel` explicitly represents empty, back
  and authorized face states; hidden cards carry no rank/suit identity. They
  do not reference `Node`.
- **Component scenes.** Each component exposes `render(model)` and signals
  such as `action_requested(PlayerAction)` and `details_requested(seat)`. It
  does not read `GameView` or peer internals. Parent composition uses public
  child APIs and normal Control minimum-size measurement.
- **Container layout.** The wide layout is containers plus one
  `SeatRingContainer` (extends `Container`) that reserves a center rect and
  places complete seat/status footprints from `SeatSlotTemplate` resources
  and measured child minima. Implement `_get_minimum_size()` and normal
  minimum-size invalidation as well as sorting. Mirrored templates must retain
  clockwise core-seat order with the recipient at the bottom. The phone layout
  uses containers for opponent tokens, center, hero and action rail; reuse or
  replace `GuiPhoneSeatLayout` math as appropriate. Collision passes are
  removed: an infeasible plan reports unsupported size instead of publishing
  overlapping rectangles.
- **Theme-first styling.** The palette, `StyleBox`es and font sizes live in
  `resources/gui_theme.tres` with type variations. State changes (acting,
  folded, winner) switch `theme_type_variation` instead of creating
  `StyleBox`es at runtime. Compact/regular sizes come from two theme
  resources or font-size variations applied at the layout root when the size
  class changes. Theme lint checks defined sizes/inheritance; rendered component
  tests establish effective 18 px seat-copy/log-body / 20 px card/other text floors,
  full text fit and 48 px touch targets.
  The theme uses Godot's built-in default font
  (`ThemeDB.fallback_font`) only; no font files are added or downloaded.
- **Mode switch, not mutation.** When the layout mode changes, the
  controller frees the old layout scene and instantiates the other one, then
  renders the current view model. Tournament state and presentation assignments
  remain outside the replaced
  subtree; `OverlayHost` owns modal state, input drafts and focus restoration.
  RG-45/RG-53 explicitly resolve profile-exit cancel versus draft preservation
  before changing that behavior.
- **Stable test API.** `get_layout_snapshot() -> GuiLayoutSnapshot` returns
  role-named rectangles (`center`, `action`, `event`, `quit`, `more`,
  `seat/<id>`, `status/<id>`, `overlay`) and text/target/card-visibility metadata
  in a documented coordinate space,
  including usable origin, effective fonts and readiness. Include typed startup
  and overlay snapshots. Headless tests and exported read-only observers consume
  the same semantic roles and public signals; observers retain no private cards.
  Scene-loading paths remain valid bootstrap configuration, not layout selectors.

Review size targets: controller under 500 lines; other GUI scripts under 400
lines; zero
`find_child()` by name in production code; runtime `add_theme_*_override`
only where a value is truly data-dependent. Line counts do not substitute for
clear ownership, correct minimum-size propagation and responsive behavior.

## 6. Guardrails for every task

- Follow the AGENTS.md loop for implementation: establish passing
  `make check` and `make gui-current-invariant-gate` before restructuring and
  rerun both after each atomic implementation change. Documentation-only work
  runs `make docs-check`; it does not certify GUI behavior.
- Update architectural decisions and implemented component guidance as each
  change lands. RG-70 consolidates consistency; it does not postpone those
  updates until the end of the rewrite.
- Do not change `scripts/core/`, poker rules, `GameView` or simulation code.
- Preserve the product invariants listed in Section 3.5 and the modal/keypad
  contracts in [ARCHITECTURE.md](ARCHITECTURE.md#gui-adapter).
- A clean replacement implementation is permitted. Keep the legacy GUI
  available as a reference, not a mandatory architecture or visual template.
  Compare product contracts through a temporary selector/separate scenes; do not
  require new components to fit old node trees. Delete legacy code at cutover
  after the replacement tests and observers work independently.
- Write screenshots and logs to ignored `localtmp/`.
- A synthetic pass is not device acceptance; record device evidence only in
  the Phase 8 tasks of this document.
- Do not consult or edit other `docs/*Tasks.md` backlogs for this work.
- Use only Godot's built-in default font. Do not add, bundle, download or
  reference any other font file or system font; vary only font sizes.

## 7. Tasks

Each task lists status, mode, scope and completion condition. Complete them
in phase order unless the user selects another task. RG-54 is intentionally
placed after Phase 6 verification; deletion must follow test/observer migration.
A task may replace its whole GUI subsystem rather than adapt the old one,
provided the target contracts and acceptance evidence are retained.

### Phase 0 — Safety net before restructuring

- [x] **RG-00 — Record the executable baseline.** Status: Complete (2026-10-28). Mode: QA.
  Run `make check` and `make gui-current-invariant-gate`; record the source
  SHA, relevant dirty-source fingerprint, commands, case counts and limitations.
  Capture both M3 and phone reference suites using the existing visual runner
  with `--development --output` under `localtmp/restructure_baseline/`.
  Check current documentation links first: this review found preexisting
  relocation errors after the Astra record moved to `docs/arkiv/`; do not
  misreport those as GUI regressions or a green baseline.
  Done: all required gates pass and a reproducible reference is recorded here;
  existing defects are explicitly distinguished from accepted product behavior.

- [x] **RG-01 — Define and adapt the stable layout snapshot API.** Status:
  Complete (2026-10-28). Mode: Senior. Add typed `GuiLayoutSnapshot` and
  `PokerTableController.get_layout_snapshot()` over the current rectangle APIs
  and typed handles. Cover every existing invariant, startup/overlays, complete
  seat/status footprints, actual child/card visibility, text fit, effective
  typography, interaction targets and readiness. Normalize current mixed
  surface-local/global coordinates; specify the usable origin and conversion.
  Done: unit tests cover phone/wide/startup/overlay roles and invariants can
  still detect deliberate private-card exposure and content/geometry failures.

- [x] **RG-02 — Migrate shared assertions and observers to snapshots.** Status:
  Complete (2026-10-28). Mode: QA. Adapt `gui_invariant_assertions.gd`,
  `gui_phone_matrix_contract.gd`, `gui_scene_harness.gd` and `tests/web/`
  observers to the semantic contract, retaining bounded layout settling.
  Support the reference and replacement implementations without requiring the
  same node tree. Keep exported observers read-only and excluded from releases.
  Done: shared invariants do not traverse internal node paths/names or private
  controller fields; headless and exported gates retain rejection coverage.

- [x] **RG-03 — Characterize policy boundaries and fit envelopes.** Status:
  Complete (2026-10-28). Mode: QA. Add cheap pure policy/geometry sweeps over widths
  320–2560 and heights 320–1600, all counts 2–9, and ±1 at existing boundaries.
  Start with step 80, with a step-20 diagnostic `gui-layout-sweep` target;
  measure runtime before adding work to `check`. Use a bounded representative
  scene matrix for text, modal and real minimum-size propagation. Include
  650 × 900, 1250 × 700 and same-widget resize streams without presuming a
  failure. Identify phone 2–7 support, legacy landscape diagnostics and insufficient-space
  cases separately; never claim that every size can contain every count.
  Done: observed failure signatures/inputs are reviewed in
  `tests/fixtures/gui_layout_sweep_known_failures.json`; new failures and
  unexpected passes fail the characterization check. RG-10/RG-12 define the
  final support envelope; no blanket clipping or overlap exemptions.

- [x] **RG-04 — Preserve the existing consolidated matrix infrastructure.**
  Status: Complete (2026-10-28). Mode: QA. The shared `GuiInvariantMatrixRunner`,
  declarative `GuiInvariantMatrixSuites` and phone contract already exist.
  Verify their snapshot migration rather than creating another runner. Keep
  four thin manual entry points and existing Make aliases, ordered case IDs
  and capture-source provenance. Extend the shared definitions for new cases.
  Done: the 348 M3 / 406 phone / 288 iPad / 232 desktop historical selections
  remain identifiable; additional coverage is versioned explicitly and all
  four diagnostic gates pass.

### Phase 1 — One source of geometry truth

- [x] **RG-10 — Decide logical geometry, minimums and native scaling. [Decision]**
  Status: Complete (2026-10-28). Mode: Tech Lead. Define physical/backing, CSS, Window
  and Control units with evidence from actual 1280 × 720 and 1920 × 1080
  native windows and exported Web. Choose a coherent stretch/base/scale
  policy; multiplying by screen scale is not automatically correct. State the
  user-visible text/target interpretation and minimum feasible sizes per mode,
  density and count, including unsupported-size guidance.
  Done: record the decision and conversion examples in
  [ARCHITECTURE.md](ARCHITECTURE.md#gui-adapter), using
  [Godot scaling guidance](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

- [x] **RG-11 — Introduce `ViewportAdapter`.** Status: Complete. Mode:
  Senior. Implement the app-level GUI adapter and injectable immutable geometry
  snapshot. Transfer existing Web normalization out of startup; define CSS
  inset probing/export viewport metadata and native mobile safe-area conversion.
  Apply reductions once, retain nonzero origins, and handle resize, browser
  chrome, rotation and invalid/zero/headless geometry without affecting CLI
  or simulation roots.
  Done: startup and table consume one geometry source; tests cover DPR
  1/2/2.625/3, nonzero/asymmetric insets, fallback platforms and real Window
  normalization; existing exported input and strict layout checks pass.

- [x] **RG-11R — Revise foundation previews from user feedback.** Status:
  Complete; subsequent accepted revisions recorded below. Mode: Senior + QA.
  User-selected correction before RG-12:
  event-log body 18 px, aligned docked log/hero/actions at both edges, upper
  seats clear of the rounded felt border, and a permanent 3×3 digit grid with
  centered 0 below 8. Keep utility controls separate, all other typography
  floors and 48 px targets intact. Preserve draft/focus and recipient privacy.
  Done: revised screenshots under `localtmp/gui-elements/`, meaningful geometry,
  typography and keypad-order regressions, required gates, then user review.
  Audit the newly confirmed universal three-seat cap and record remaining
  legacy gaps; implementing it throughout the replacement belongs to
  RG-12/42/50–52 and is not completed by this six-player preview correction.

- [x] **RG-11R2 — Rectangular keypad utilities and number-entry scope.**
  Status: Complete; user-accepted in portrait and compact landscape only.
  Mode: Senior + QA.
  Preserve the accepted digit order
  and explicit limits. Compose editing/preset/Cancel/Done controls as a neat
  rectangle, including plain-number mode without wager presets. Remove the
  tournament Quit button, signal and wiring from the keypad; use Cancel then
  the table/menu Quit route instead. Preserve 20 px copy, 48 px targets,
  transactional drafts, focus and modal guards.
  Done: meaningful rectangle/state/input regressions, required gates, revised
  compact screenshot under `localtmp/gui-elements/`, ready for user review.

- [x] **RG-11R3 — Make Total visibly an input field.** Status:
  Implementation verified; white Total palette superseded by RG-11R4.
  Mode: Senior + QA. Apply sharp-cornered white field styling and dark-green
  text/caret/placeholder, retaining recognizable focus/read-only states and
  existing padding/font/target geometry. Keep Raise and other actions in their
  button family. Touch opening a keypad does not change field styling.
  Done: verify input/action distinction, unchanged editing/keypad behavior and
  layout invariants; capture the revised 1280×720 table for user review.

- [x] **RG-11R4 — Total/Quit styling and orientation-specific acceptance.**
  Status: Complete; subsequent branding/table reviews accepted. Mode: Senior + QA.
  Latest user review accepts the compact
  keypad for landscape only and the table apart from Total's palette/height.
  Restore light-grey text on dark green for Total, retaining sharp corners;
  draw its face slightly shorter and vertically centered beside Raise.
  Keep the 48 px interactive area and normal container geometry, distinguish
  drawn face from hit area, and leave other fields' white palette unchanged.
  Make compact horizontal keypad composition explicitly landscape-only.
  Apply the existing shared rounded/bordered action styles to the actual table
  Quit control in every normal/hover/pressed/focus/disabled state.
  Done: actual field-face/target/center measurements, portrait/landscape flow
  regressions, required gates and a new table capture ready for user review.

- [x] **RG-11R5 — Transparent shared logo, embossed felt and muted Total text.**
  Status: Complete (2026-10-29). Mode: Senior + QA. Produce the transparent PNG without
  overwriting the supplied JPEG. Author one passive reusable `BrandLogo`
  scene/texture, with normal Start-screen and embossed-cloth materials.
  Containers keep the startup form on screen with no scrollbar, adapting
  optional copy/logo allocation; fields/actions retain their font/target floors.
  Table branding is behind game content and affects no component minimums,
  recipient privacy or geometry. Darken Total's grey text relative to actions.
  Use a stable surface diagnostic role
  so decorative child insertion does not rename game-content failures.
  Done: alpha/rendering and startup scroll regressions, required gates,
  explicit reviewed diagnostic-ID migration, and Start/table captures ready
  for user acceptance.

- [x] **RG-11R6 — Rethink phone portrait seats and use the full screen.**
  Status: Implementation and verification complete (2026-10-29); final boundary
  previews await visual review. Mode: Senior + QA. User-selected redesign before RG-12:
  full green background without table border/perimeter margins; coherent
  opponent-seat content rows; community cards, pot and wager directly above
  the human seat/actions. The latest review requires at most two opponent seats
  per phone-portrait row, including reduced-height screens. For an odd opponent
  count, start with one centered seat of the same width as seats in paired
  rows. Preserve 2–7-player scope, exact copy, seat order, public/private
  card rules, complete status footprint and 48 px action targets. Larger-screen
  approved branding/layouts remain outside this portrait-only change.
  Done: portrait count/content/resize regressions and reduced-height fit,
  reviewed characterization changes, required gates and new actual phone
  captures for acceptance. This does not complete the later authored-component
  replacement or device acceptance tasks.

  Latest review: the `rg11-review6-startup` captures are user-accepted. The
  earlier three-column phone captures are superseded by accepted review7 images.
  The two-column implementation now passes 20 focused tests / 3,157
  assertions and 7 independent portrait-contract tests / 128 assertions.
  Five fresh GPU captures are ready in
  `localtmp/gui-elements/rg11-review7-captures.json`, with no captured invariant
  failures. The user accepted all five on 2026-10-29. Final broad gates and
  reviewed characterization changes now pass; see the execution record below.
  The final numeric-boundary fix adds a last vertical-card candidate, restores
  horizontal cards on resize, and uses actual available height. It keeps
  ordinary short-phone seat copy at 20 px when it fits. Updated ordinary and
  seven-way-split captures await review; RG-12 remains untouched.
  Additional requested asset conversion is complete:
  `assets/images/PokahdotAcesIF-transparent.png` (originally saved as
  `Pokahdot_logo2-transparent.png`) removes the checkerboard from the supplied
  logo2 image, now named `PokahdotAcesInFlames.png`. Actual RGBA transparency and
  transparent corners were verified. This separate asset is not yet selected
  as the shared Start/table logo. Prompt and alpha evidence are under
  `localtmp/gui-elements/logo2-transparency-*.json`.

- [x] **RG-11R7 — Keep expected popup diagnostics compatible with LAN builds.**
  Status: Complete (2026-10-29). Mode: Senior + QA. User-selected LAN rebuild regression:
  the native-popup rejection test passes but emits an intentional `ERROR:`
  into `make check`, which the strict LAN builder correctly rejects. Execute
  this negative test in a child Godot process; verify its exact diagnostic and
  unchanged native geometry without emitting the error into the parent log.
  Preserve rejection of unexpected diagnostics, including zero-exit commands.
  Done: focused regressions, full checks, GUI matrices and an actual successful
  `web-lan-rebuild` with ready status. No GUI design or RG-12 work.
  Evidence: popup tests 2/2 (12 assertions), LAN build regressions 9/9,
  full GUT suite 787/787 (115,270 assertions), all four GUI matrices passed.
  Build `01e2e34f1f674f1bb7f2c31d0880505c` is ready; check/import/export logs
  contain no engine/script error lines. Logs and status:
  `localtmp/lan-popup-fix/` and `localtmp/web-lan/builds/01e2e34f1f674f1bb7f2c31d0880505c/`.
  The LAN scanner and production popup guard are unchanged. Tests also verify
  a zero-exit check that emits an unexpected error still blocks export.

- [x] **RG-12 — Define unified `SizeClass` and supported fit policy. [Decision + implementation]**
  Status: Implemented and verified; guidance design user-accepted (2026-10-29).
  Mode: Tech Lead then Senior. Specify width/height
  classes and derived modes over adapter geometry, including medium portrait
  widths. Define invalid-size handling, explicit fixture overrides, feasible
  envelopes and the 8-/9-player phone guidance state. Enforce at most three
  seats in each horizontal row in every layout, with the stricter two-opponent
  portrait-phone cap and centered odd-count apex. Preserve seat IDs and entered
  startup values. Keep measured component-fit decisions distinct from
  global breakpoints; define monotonicity per dimension/orientation.
  Start fit evidence with the constrained seven-player phone cases and
  nine-player wide cases, retaining 2–7 phone / 2–9 tablet/desktop capacity.
  Done: one documented policy, tests at boundaries ±1 and minimum-fit edges,
  with explicit portrait/landscape phone fit envelopes; legacy diagnostic passes
  do not complete the replacement landscape implementation or acceptance.

- [x] **RG-13 — Route composition decisions through unified policy.** Status:
  Implemented and verified through the clean replacement path. Mode: Senior. Replace classification and density branches in
  `GuiTableLayoutPass`, `GuiMobileTableLayout`, `GuiSixSeatDesktopPlan` and
  controller/seat/action helpers. A clean replacement may bypass these legacy
  modules entirely. Pass one typed policy snapshot per operation, preserving
  the current deterministic six-seat footprint/order behavior as a contract.
  Use a small temporary bridge only where current callers require it; do not
  extract more legacy layout/builder helpers. Replacement compositions consume
  this policy directly rather than inheriting the temporary bridge.
  Done: global breakpoints have one owner; a scoped policy check permits local
  measured-fit constraints and ordinary containment checks, but rejects new
  device-specific thresholds in components. Characterization changes are
  explained and supported-size defects are closed rather than masked.

### Phase 2 — Presentation model

- [x] **RG-20 — Create `TableViewModel` and child models.** Status: Implemented
  and verified. Mode: Senior. Move display-name, marker, badge, compact action
  text, status band text, winner display, pot/wager copy, hand summary and
  action availability from the controller and extracted seat/action helpers into
  `scripts/gui/view_models/`. Pure `RefCounted` with typed fields and a
  density parameter. Include typed `CardViewModel` / card-row child models:
  empty, back and authorized face states; rank/suit presentation exists only
  for legitimately visible cards. Reuse pure formatters and core wager helpers;
  never copy poker rules into the model.
  Done: the controller consumes the models; unit tests cover every
  `PlayerAction.Kind`, fold/all-in/busted/acting states, exact large values,
  and privacy (no unrevealed opponent card in any model). Include semantic
  winner emphasis flags for hand/result descriptions from recipient-safe
  main/split/side-pot awards, and one shared recipient-safe event-log model
  independent of whether history is docked or shown in an overlay.

- [x] **RG-21 — Move poker-derived GUI tests to model tests.** Status: Implemented
  and verified; coverage map recorded. Mode: QA. Re-home pot-target, repeated-raise, short-stack and
  winner-text assertions from `test_gui_table_actions.gd` and the
  phone files into view-model tests where they test pure presentation. Keep
  real adapter integration tests for button activation, submitted targets, core
  rejection/no mutation, modality and privacy; retain core rule coverage.
  Done: a repository-owned old → new coverage map records every migrated case;
  scene tests retain meaningful integration behavior and runtime is measured.

### Phase 3 — Theme

- [x] **RG-30 — Build the theme palette and type variations.** Status: Implemented,
  verified and user-accepted (review3, 2026-10-29). Mode: Senior. Move colors and `StyleBox`es from
  `GuiTableStyle`, `FoldedSeatStyle`, extracted factories/controls/overlays,
  the controller and the keypad into
  `resources/gui_theme.tres` with variations (`Felt`, `Zone`, `SeatPanel`,
  `SeatPanelActing`, `SeatPanelFolded`, `HeroPanel`, `PhoneToken`,
  `StatusBand`, `ActionButton`, `PrimaryActionButton`, `OverlayPanel`,
  `KeypadKey`, `InputField`, `NumberField`, `WagerTotalField`, `CardFace`, `CardBack`, `WinningHandText`,
  `EventLogBody`). Log body uses 18 px; its headings/actions retain 20 px. Winning hand/result
  descriptions are bold and bright yellow (`#FFFF00`); use a bold variation
  derived from the built-in font, with no additional font file. Action buttons
  (including Quit, menu/close/cancel and keypad actions) use rounded corners,
  dark-green backgrounds and white enabled text; disabled labels use the
  approved grey exception. Number/text fields use zero-radius
  corners, white backgrounds and dark-green text, with a lighter surface than
  buttons. Focus, hover, pressed, disabled, read-only and validation states
  preserve the button/field distinction.
  Total is the later-approved exception: light-grey/dark-green, sharp corners,
  with a shorter centered face inside a full 48 px interaction allocation.
  Done: the palette and required state distinctions are reviewed; a new visual
  design is allowed and old pixel output is not the acceptance target. Theme
  lint validates defined/inherited fonts; rendered components verify effective
  seat-copy/log-body sizes ≥ 18, card/other GUI text ≥ 20 and actual interactive targets ≥ 48 × 48.
  Folded surfaces and avatars are fully grayscale; the acting frame is bolder
  than the original candidate. Wide human seats reserve more space/type size
  than bot seats, subject to measured fit.

- [x] **RG-31 — Add compact and regular size variants.** Status: Complete
  and verified (2026-10-29). Mode: Senior. Provide font-size/spacing variants per size class,
  applied at the layout root on mode change. Remove `content_scale`-driven
  font multiplication and `_enforce_minimum_gui_text_size_for_node()`.
  Seat text scales with the component within a bounded preferred-to-18 px
  range, including its status band. Card ranks remain at least 20 px even
  inside a seat; other GUI text remains at least 20 px, except 18 px log body.
  All card/seat/status
  minimums include the measured bold-font metrics where applicable.
  Done: one role-aware typography system; displayed font-floor and full-copy
  fit tests pass over the sweep without shrinking touch targets.

### Phase 4 — Component scenes

Build each component as `scenes/gui/components/<Name>.tscn` with a typed
script, `render(model)`, signals, theme variations only, and a component test
that renders all states at its minimum size and runs the snapshot invariants.

- [ ] **RG-39 — Shared `ActionButton` and `InputField` presentation scenes.**
  Status: Not started. Mode: Senior. Author typed reusable controls with public
  render/edit signals and theme variations. Route all visible actions through
  the button family, including startup, Quit, confirmation, menus, Log,
  More/Pots, wagering and keypad keys. Use rounded dark-green buttons with
  white enabled text and grey disabled labels. Number/text inputs and numeric
  draft/value-entry surfaces use
  sharp-cornered white fields with dark-green text; they never masquerade as
  action buttons when touch opens a keypad. Keep normal/focus/disabled/error
  states, including Total's separate light-grey/dark-green shorter-face variant,
  recognizable. Distinguish the drawn field face from its 48 px hit area. Keep
  20 px text and 48×48 interactive targets. Views
  emit UI intent; controllers/adapters own numeric validation, keypad
  transactions and game actions. Tests cover visual/state distinctions,
  keyboard activation/editing, touch dispatch and exact draft preservation.
- [ ] **RG-40 — Reusable card presentation and `CenterBoard`.**
  Status: Not started. Mode: Senior. Author `PlayingCard.tscn` with the public
  `render(CardViewModel)` contract, composed of `CardFace.tscn` and
  `CardBack.tscn`, plus an empty reserved-slot state. Author a reusable
  `CardRow.tscn` container for community, hero and opponent cards; those
  contexts reuse the same card components rather than building card controls
  separately. `CenterBoard` composes the row with pot/wager containers.
  Preserve equal minimum-safe slots across face/back/empty states and measured
  rank/suit constraints, including rank `10`; aspect-ratio containers respect
  actual content minima. Actual face/back/empty allocations must keep width/
  height ≥5:7 or wider; no parent may stretch a card into a narrower shape.
  Value and suit use comparable visual size, the largest measured fitting font
  against visible ink bounds with safe padding, and at least 20 px. Card size
  follows available container space rather than the gallery sample constants. Test rank `10`, all suits and actual
  container-assigned geometry rather than only nominal custom minima.
  Card components render recipient-safe presentation
  models and theme variations only, with no `GameView`, deck, evaluator,
  visibility decisions or poker rules inside the view. Tests render all states
  at minimum sizes, verify reuse across contexts, complete rank/suit fit and
  private-card redaction. This makes the user's 2026-10-28 card-component
  clarification explicit; implementation remains pending.
- [ ] **RG-41 — `SeatPanel` and `HeroPanel`** as complete layout components.
  Their outer container owns the visible framed panel plus a permanently
  reserved band beneath it for the latest active-round action and showdown
  hand text. The drawn panel rectangle is only a sub-region; the component's
  minimum size, allocation, snapshot footprint and clearance include the band,
  even when blank. Keep the band within the component hierarchy rather than
  a separately positioned sibling. Render avatar, marker, winner star and the
  shared `CardRow`/`PlayingCard` components. On larger-screen layouts the
  selected `SeatViewModel.avatar_path` is visible, keeps its aspect ratio and
  remains stable across resize/rotation; constrained phone tokens may omit it.
  Avatar allocation participates in measured fit instead of introducing a
  second screen-size classifier. The folded treatment grayscales the entire
  surface and avatar, not just its background. Where space permits, the human
  component is larger and uses larger identity text/avatar than bot seats;
  complete-footprint measurement still includes its reserved band. Winning hand/result descriptions
  are bold, bright yellow via theme variations, including split/side-pot
  winners and exact `Winner` fold-win copy. Seat copy can scale to 18 px;
  embedded card ranks remain at least 20 px. Migrate or replace
  `GuiTableSeatFactory`/`GuiTableSeatView` with authored typed handles.
  Status: Not started. Mode: Senior.
- [ ] **RG-42 — `SeatToken`** (phone) using a `GridContainer`/box layout with
  finite measured-content rows preserving `GuiPhoneTokenContentPlan` behavior
  and reusing the same card presentation components,
  replacing manual offsets without ellipsis, clipping or hidden required copy.
  Own the reserved action/showdown band within the token's complete measured
  footprint; apply the same 18 px seat-copy floor and bold bright-yellow
  winning-description variation as the full seat components.
  Status: Not started. Mode: Senior.
- [ ] **RG-43 — `ActionBar`** with one or two rows chosen by available width
  (`HFlowContainer` or explicit row model), keypad trigger and inline input by
  modality, phone hero summary as a sub-component, using the shared RG-39
  buttons and distinct input fields. Keep a Log action or a
  reachable menu entry whenever the docked log is hidden, including completed
  hand/Pots states. Status: Not started.
  Mode: Senior.
- [ ] **RG-44 — `EventLog`** as a reusable scrollable presentation component
  over the shared recipient-safe log model. Dock it where space permits and
  reuse it in an accessible log overlay/menu view when the dock is hidden,
  including phones in both orientations. Preserve full public history, empty
  state and exact copy; no hidden-card or bot-private data. Test docked and
  overlay renderings against the same model. Use 18 px log-body text to retain
  more visible lines; headings and controls keep the 20 px floor. Docked log,
  hero panel and action area share top and bottom edges. Status: Not started.
  Mode: Junior.
- [ ] **RG-45 — `OverlayHost`** that owns menu, hand summary, seat detail,
  quit confirmation, event log and keypad on one full-rect layer with a backdrop and
  integrates `GuiModalGuard`. Keep this host outside replaceable layout scenes.
  Prefer in-canvas confirmation across profiles; explicitly record any retained
  native-dialog exception and the draft/focus policy on mode exit before changing
  the current cancel-without-commit behavior. Opening a log from More/Pots or
  another menu remains reachable, blocks underlying actions, pauses progression
  and restores focus on close; hidden docks never discard log data. Reuse or replace
  `GuiTableOverlayViews` ownership. Status: Not started. Mode: Senior.
  Keypad digits retain three ordered columns (`1 2 3 / 4 5 6 / 7 8 9`) and
  centered `0` beneath `8` in every orientation; utility controls reflow
  separately. Fit compact landscape without changing digit order or targets.
  Utility actions form uniform rectangular grids; tournament Quit does not
  belong to the number-entry component. Cancel discards, Done commits, and
  visible limits explain the permitted value range.

Done for Phase 4: every component has a test over all states; components are
tested independently and ready for replacement layouts. Integration into the
legacy tree is optional; do not distort the component API merely to fit it.

### Phase 5 — Layouts and switching

- [ ] **RG-50 — `SeatRingContainer` and `SeatSlotTemplate`.** Status: Not
  started. Mode: Senior. Custom `Container` that reserves the center and
  lower regions and places seat footprints with `fit_child_in_rect()` in
  `NOTIFICATION_SORT_CHILDREN`; slots come from `.tres` templates for 2–9
  players with mirrored construction and hero-at-bottom mapping (preserve the
  behavior of
  `GuiTableSeatLayout.visual_slot_for_seat()`). Cover all recipient seats,
  reordered view arrays, clockwise order and complete footprints. Implement
  content-driven minimum sizes and explicit infeasible plans. Replace or retire
  the position tables in `table_seat_layout.gd`.
  Every horizontal row has at most three player seats, including the hero when
  applicable, for every supported count. Record row/slot membership in pure
  plan tests rather than testing only equal y-coordinates.
  Account for the surrounding felt's rounded corners and border thickness;
  rectangular containment alone is insufficient for upper corner seats.
  Done: pure/property tests and supported-envelope sweeps show no overlap and
  full containment after actual child minima are applied; infeasible allocations
  produce explicit guidance without any collision-resolution pass.

- [ ] **RG-51 — `WideTableLayout.tscn`** for tablet, small desktop and
  desktop, composed of containers, `SeatRingContainer`, `CenterBoard`,
  `HeroPanel`, `ActionBar` and an adaptively docked `EventLog`; a hidden dock
  retains a reachable Log action/menu. Status: Not started. Mode: Senior.
  Done: supported wide fixtures and fit/boundary sweeps pass in the replacement
  scene; infeasible sizes show the defined guidance. A temporary selector may
  expose reference/replacement scenes for comparison.

- [ ] **RG-52 — `PhoneTableLayout.tscn`** using a container-owned phone plan
  (reuse or replace `GuiPhoneSeatLayout`), with `SeatToken`s, `CenterBoard`,
  `ActionBar`,
  More/Pots and reachable Log access, with safe-area margins from `ViewportAdapter`. Phone
  landscape uses a height-aware container composition with the same content
  and input contracts. Opponent/hero rows never exceed three seats. Status:
  Not started. Mode: Senior.
  Done: supported portrait and landscape phone fixtures and fit/boundary sweeps pass in the
  replacement scene; unsupported counts/sizes preserve state and show guidance.

- [ ] **RG-53 — Controller orchestration.** Status: Not started. Mode:
  Senior. Reduce `PokerTableController` to binding, pacing, model building,
  layout-mode switching (free/instantiate on change, never mutate), overlay
  routing and the snapshot API. Apply the explicit RG-45 draft/focus policy
  across switches; update the documented current cancellation rule only after
  that decision. Define ownership/lifetimes for the new component scenes and
  their subcontent; persistent scenes rendering fresh models are permitted.
  Geometry-only resize reuses the active composition where possible. Update the
  old runtime-builder lifetime decision for the new design, with profiling and
  privacy/focus/invalidation tests rather than a requirement to retain churn.
  Done: live-viewport/modal regressions pass; resize reconstruction is counted
  and explained, and the existing native/Web profiler verifies no material
  regression. No blanket cache is introduced merely to meet a node-count test.

### Phase 6 — Tests and tooling

- [ ] **RG-60 — Replace implementation-coupled tests.** Status: Not started.
  Mode: QA. Rewrite or delete internal node-path/name and incidental exact-pixel
  assertions only when snapshot, sweep, component or integration checks replace
  their contract. Rename incident tests to their underlying rule and retain the
  fixtures. Include capture, browser-input and performance harnesses, not only
  unit assertions.
  Done: replacement checks and observers do not depend on internal legacy paths;
  every removed assertion has a repository-owned coverage mapping and deliberate
  defect injection still fails. Scene-loading paths remain legitimate.

- [ ] **RG-61 — Exported Web layout checks.** Status: Not started. Mode: QA.
  Extend the existing `tools/run_web_layout_tests.py` /
  `tools/web_layout_assertions.py` and read-only `tests/web/layout_fixture.gd`
  observer. Retain `run_web_input_tests.py` interaction coverage rather than
  replacing it with geometry tests. Cover phone/iPad/desktop at DPR 1/2/3 and
  fractional 2.625, automatic and explicit classification, usable origins/insets
  and real `Window` stretch. Run strict checks for supported cases and preserve
  report-only diagnostics separately.
  Done: CI runs exported strict layout plus existing input checks with recorded
  source/engine/browser/DPR identity; emulation is not device acceptance.

- [ ] **RG-62 — Default-font metric parity.** Status: Not started. Mode: QA.
  Verify that headless tests and the exported Web build measure text with
  the same built-in default font. Make the text-fit checks in RG-61 cover
  the longest names, exact large chip values and compact action copy. Do
  not add or download any font.
  Done: parity verified or differences recorded; text-fit tests pass in
  both paths using only the default font and the actual allocated rectangles.
  Keep existing rank/name/action regressions; document justified raster/metric
  tolerances rather than replacing the real font with a test substitute.

- [ ] **RG-54 — Cut over and remove the legacy GUI.** Status: Not started.
  Mode: Senior. Depends on RG-60–62 as well as RG-50–53. Make the verified
  replacement default, then remove the legacy scene/factories, old classification
  and geometry helpers, runtime mutation, deferred center reapplication,
  collision passes and temporary selector. Retain pure services or math only
  when they comply with the target design. A complete replacement is acceptable;
  no old GUI implementation is required to survive.
  Done: replacement tests, captures and observers work independently; supported
  sweep failures are closed, unsupported-size behavior is explicit, all required
  gates pass on the identified candidate and Section 5 size/ownership targets
  are met. Record performance and visual review before physical acceptance.

### Phase 7 — Documentation

- [ ] **RG-70 — Update current documentation.** Status: Not started. Mode:
  Documentation Updater. Update the GUI adapter section of
  [ARCHITECTURE.md](ARCHITECTURE.md#gui-adapter),
  [ProvisionalGUILayoutGuidance.md](ProvisionalGUILayoutGuidance.md),
  [GUI_VISUAL_TESTING.md](GUI_VISUAL_TESTING.md), `devdocs/` references and
  `README.md` to describe the viewport adapter, size classes, components,
  theme and snapshot API; run `make docs-check`. Leave other
  `docs/*Tasks.md` files unchanged.
  Done: no stale references to removed scripts in current docs; docs check
  passes.

### Phase 8 — Device acceptance

Record each review with commit SHA, device, OS and browser version, logical
viewport (CSS px), DPR, orientation, player count and screenshots under
`localtmp/restructure_acceptance/`. Mark a task complete only when the user
accepts it. Both phone orientations are part of replacement acceptance.

- [ ] **RG-80 — Phone portrait and landscape review.** Status: Not started. Mode: QA with
  user. Review a hosted build of the default switch (RG-54) on at least one
  physical Android and one iOS phone for representative counts 2, 4, 6 and 7 (automated portrait coverage includes
  every count 2–7). Review both orientations and rotate during a hand: phone
  composition selected, no clipped names/stacks, 18 px seat-copy / 20 px other
  text floors, 48 px targets,
  action rail clear of safe-area insets, More/Pots, hidden-log access, keypad, hand summary and
  quit flows, browser chrome/keyboard changes and actual device/browser Back.
  Done: evidence recorded here; user acceptance noted.

- [ ] **RG-81 — iPad review.** Status: Not started. Mode: QA with user.
  Landscape (primary) and portrait for 2, 6 and 9 players, including
  browser-chrome height changes and rotation during a hand.
  Done: evidence recorded here; user acceptance noted.

- [ ] **RG-82 — Desktop browser review.** Status: Not started. Mode: QA with
  user. Window sizes around 1280 × 720, 1920 × 1080 and a narrow window that
  crosses each size-class boundary, with pointer and keyboard input. Include
  the new nine-player layout and verify the three-seat horizontal-row cap.
  Done: evidence recorded here; user acceptance noted.

- [ ] **RG-83 — Close the backlog.** Status: Not started. Mode:
  Documentation Updater. Summarize accepted scope and remaining limitations
  at the top of this file and move it to `docs/arkiv/` when the user agrees.
  Done: status line updated; index in [README.md](README.md) updated.

## Review evidence and execution status

The 2026-10-27 reconciliation inspected production GUI/scenes, model/geometry
helpers, the product/architecture contracts, invariant support, browser
observers, CI and profiling tools. A headless policy probe confirmed the
650 × 900 / 1250 × 700 classifications and the 1377 × 777 six-seat plan, plus
all four ordered suite counts. Thirteen existing focused profile/component/
suite tests passed with 91 assertions. Logs are local-only under
`localtmp/gui-plan-review/`; these checks are not RG-00 or device acceptance.

### RG-00 executable baseline — 2026-10-28

Source: `4e0879602f61478b9ce33914b1a497731f70f4eb`; clean tracked and
untracked working tree before capture (`dirty_fingerprint: clean`). Engine:
Godot 4.7.2 stable official; macOS / Apple M4; Compatibility / OpenGL 3.
All commands ran from the repository root with
`GODOT=/Applications/Godot.app/Contents/MacOS/Godot`.

- `make docs-check`: six documentation tests; 27 current Markdown files;
  zero link/format errors. Archived relocation links are excluded by the
  current gate; the earlier review's 51 archive errors are historical context.
- `make GODOT=... check`: passed all Python, lint, format and Godot checks;
  103 Godot scripts, 702 tests, 111,943 assertions. The first sandboxed attempt
  failed because loopback socket binding was prohibited; rerunning with local
  socket access passed. This was an environment limitation, not a GUI defect.
- `make GODOT=... gui-current-invariant-gate`: all four matrices passed,
  preserving 348 M3 / 406 phone / 288 iPad / 232 desktop ordered cases.
- Rendered references used the existing visual runner with
  `--development --output`, one run with `--full-m3` and one with
  `--full-phone`. All 348 M3 and 406 phone cases settled and passed invariants.
  Logs and PNGs are in `localtmp/restructure_baseline/`; complete manifests
  are `m3-retry/manifest.json` and `phone/manifest.json`.
  Their SHA-256 values are respectively
  `625ba0fdda4962dfdadfb3ece58d771e018fdc3c55949be7dc5019d11e1a597a`
  and `712ddf4bc93c9a1655883aac469ed9cdda2ba9ca385571d790e9291514d51782`.

Reproduce captures using:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --always-on-top \
  --windowed --resolution 480x270 --position 0,0 \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --audio-driver Dummy --script tests/visual/gui_visual_capture_runner.gd \
  -- --full-m3 --development --output res://localtmp/restructure_baseline/m3-retry
```

Use `--full-phone` and a fresh output directory for phone captures. The first
M3 attempt stopped making rendering progress at 119 staged images; it was
terminated and retained as incomplete evidence in `m3/`. The always-on-top
retry above completed. Do not use that partial run as a baseline.

These development captures are reproducible references, not visual acceptance
or physical-device evidence. No existing visual defect becomes accepted merely
because an invariant passes. The reference phone landscape captures are
diagnostic/deferred evidence; the later user scope clarification adds landscape
to replacement implementation and acceptance.
The completed baseline contains no GUI implementation changes; remaining
redesign tasks are unchecked until their own implementation and checks pass.

### RG-01 snapshot API — 2026-10-28

Implemented `GuiLayoutSnapshot`, typed element/seat/card/startup/overlay values,
reference producers and public table/startup `get_layout_snapshot()` APIs.
Measurements are detached and preserve semantic roles, complete footprints,
actual child/card visibility, local text allocations and transformed geometry.
Unauthorized card text/tooltips are redacted in both semantic and generic
observations. Existing visuals and invariant consumers are unchanged.

Verification: 12 focused tests / 544 assertions, including actual injected
private faces, hidden/missing cards, clipping, line limits, tiny targets,
rank/suit geometry, scaled/nonzero origins, popup controls and detached lifetime.
`make GODOT=... check` passed with 104 scripts / 714 Godot tests / 112,491
assertions; Python/lint/format/docs checks passed. All four current invariant
matrices passed. Final runs used normal local socket/log access and contain
zero engine errors or warnings. Evidence: `localtmp/restructure_rg01/`
(`check-final.log`, `invariants-final.log`) and
`localtmp/restructure_snapshot/focused-tests.log`.

Local content allocations subtract normal theme margins; optional button-icon
space is not separately measured. No current action uses an icon. Font sizes
remain explicitly separated into theme, transformed logical and output units;
CSS/physical parity and safe areas remain RG-10/RG-11 work. Existing invariant
and browser consumers migrate in RG-02; this API alone is not device acceptance.

### RG-02 shared consumers — 2026-10-28

Shared region/content/privacy assertions and the phone contract now consume
semantic snapshots. The harness accepts independent fixture drivers and uses
snapshot readiness/geometry for bounded settling; legacy setup and exact phone
position expectations live only in the reference driver. Snapshot metadata now
includes semantic modal targets, actual focus, exact input values, presence and
text kinds. Both Web observers use these values; the layout report/checker uses
semantic roles and viewport coordinates, including nonzero origins.

Preserved all deliberate rejection fixtures and added detached/no-tree,
integrated-status, independent-driver, timeout, extra private-face and hidden
card/rank/suit/faded-face checks. The numeric-bound test explicitly declares its
intentional menu for its content observation. No blanket overlay exception was
added. Capture provenance now fingerprints the reference driver and both
snapshot assertion helpers; original ordered matrix identities remain intact.

Final verification: `make GODOT=... check` passed 104 scripts / 720 Godot tests /
112,534 assertions plus Python/lint/format/docs checks. All four invariant
matrices passed. Fresh exported Chromium 140.0.7339.16 checks passed five input
cases (pointer/touch startup/table plus phone showdown) and five strict layout
resize observations (1280×720, 1369×724, 1920×1080 and return stream, DPR 1).
Browser identity/source/pack hashes and screenshots are recorded under
`localtmp/restructure_rg02/web-input-final/` and `web-layout-final/`;
full logs are `check-final.log` and `invariants-final.log`. No engine errors
or warnings in final gates. Broader DPR/device coverage remains RG-61/Phase 8.

Playwright 1.55.0 was installed from `requirements-web-test.txt`; its matching
Chromium is session-local under `localtmp/playwright-browsers/`. Reproduce with
`PLAYWRIGHT_BROWSERS_PATH="$PWD/localtmp/playwright-browsers"` for browser
commands. An earlier export completed before the browser download and could
not launch Chromium; the final fresh export/runs above passed. No visual
redesign or device acceptance is claimed by this task.

### RG-03 policy/fit characterization — 2026-10-28

Implemented inclusive pure sweeps across all counts 2–9, boundary ±1 and
orientation/aspect transitions, ordinary/large variants where the plans differ,
and 110 bounded scene/resize cases. Full recipient-safe view fingerprints and
seat IDs survive the same-widget streams. Actual root minima, text, modal,
card and target observations come from rendered controls; injected pure minima
are explicitly marked primitive evidence.

Canonical registry: `tests/fixtures/gui_layout_sweep_known_failures.json`,
schema 1, step 80, 9,994 unique inputs / 1,101 observed failing probe inputs.
The pure subset has 9,884 inputs / 1,070 failures (468 rejected alternative
six-seat plans, 94 raw ring-order observations, 508 phone plan failures).
The rendered/resize subset has 110 inputs / 31 failures. Review confirmed exact
signatures/input lists, matching source checksums and no category exemptions.
650×900 fails at every sampled count; tested 1250×700 cases pass; eight-player
1920×1080 has seat/status overlaps. Unsupported phone counts and deferred
landscape retain distinct diagnostic scopes. These records do not accept defects
or define the final support envelope.

Measured canonical runtime: approximately 0.5 s pure + 2.8 s scenes; the exact
characterization target now runs in `check`, after its existing Godot import.
`make gui-layout-sweep` measured 73,537 inputs / 4,991 failing probes in about
3.9 s pure + 2.8 s scenes; it explicitly labels 63,543 additional step-20
samples and remains diagnostic. Reports/raw details live under
`localtmp/restructure_rg03/`, `localtmp/gui-layout-characterization/` and
`localtmp/gui-layout-sweep/`.

Registry mutation tests reject new failures, unexpected passes, duplicate or
missing IDs, input/matrix drift and changed policy observations. Final
`make GODOT=... check` passed 107 scripts / 732 Godot tests / 112,751 assertions
plus Python, lint, format, docs and the exact registry comparison. All four
current invariant matrices passed; no engine errors or warnings. Logs:
`localtmp/restructure_rg03/check-final.log` and `invariants.log`.

### RG-04 consolidated matrix verification — 2026-10-28

Verified the existing shared runner and declarative definitions, four unchanged
thin manual entry points and original Make aliases. Ordered capture IDs match
the RG-00 manifests exactly: all 348 M3 and 406 phone IDs. The preserved iPad
288 and desktop 232 identity hashes also match their historical contract tests.
Capture provenance includes the reference driver and both snapshot assertion
helpers; original suite versions/ordering remain intact. RG-03 additional
coverage is independently versioned by registry schema/step/matrix hash.

All four snapshot-backed diagnostic gates passed on the current source.
Read-only identity audit completed with zero engine errors; evidence is
`localtmp/restructure_rg04/identity-report.json` and `identity.log`. No second
runner or replacement matrix infrastructure was created for this task.

### RG-10 logical geometry decision — 2026-10-28

Recorded the unit/conversion, scaling, input-modality and content-driven
minimum-feasibility contract in `ARCHITECTURE.md`. Per the user's clarification,
old dimensions are regression samples; responsive Godot containers and measured
content drive fit. Replacement phone landscape is now explicitly in RG-12,
RG-52 and RG-80 scope alongside portrait and both tablet orientations.

Measured 24 actual native Window records/screenshots across scale-1 and Retina
scale-2 displays, preserving the product settings in all experiments. Native
client/screen-scale normalization restores a 20 UI-unit font floor and 48-unit
targets; the fixed base shrinks output at smaller windows. Derived OS-point
sizes use the reported platform scale; independent OS frame bounds were
unavailable. All records settled and image writes succeeded, with zero engine
errors or warnings. Read-only fixture:
`tests/performance/gui_geometry_fixture.gd` / `.tscn`; evidence in
`localtmp/restructure_rg10/native/` and `native/retina/`.

Exported Web measurements cover 12 combinations of CSS size and DPR 1/2/2.625/3.
A fractional phone canvas differs from requested dimensions (389×843 actual CSS
for a requested 390×844); inferred normalization shrinks 20-pixel text to about
19.95 CSS pixels and a target to 47.94 CSS pixels. An isolated exported-copy
actual-CSS normalization prototype restored 20/48 across ten rotation/resize
observations, with zero browser/engine errors or logical invariant failures.
Per-axis metrics avoid falsely combining unrelated scalar minima. Reports,
source/pack hashes, prototype patch and screenshots are in
`localtmp/restructure_rg10/web/` and `web-candidate/`.

A separate 64-case fit probe passed all counts 2–9, ordinary/large preflop and
showdown content at two representative logical sizes. These demonstrate
feasible allocations; the decision defines component-derived minimum functions
rather than fixed supported screen dimensions. No production geometry change
was made in RG-10. RG-11 implements the adapter and closes the measured Web gap;
RG-12/40–52 implement the responsive fit/composition contract.

Final `make GODOT=... check` passed 107 scripts / 732 Godot tests / 112,751
assertions plus Python/lint/format/docs/characterization checks. All four current
invariant matrices passed; final logs contain no engine errors or warnings.
Evidence: `localtmp/restructure_rg10/check.log` and `invariants.log`.

### RG-11 shared viewport implementation — 2026-10-29

`Main/ViewportAdapter` now owns real GUI Window normalization and immutable
usable geometry for startup and table. Platform code lives under
`scripts/gui/platform/`; the pure geometry value, DOM probe and embedded-popup
placement have separate responsibilities. Web uses actual canvas CSS extent,
not backing-size/DPR inference. Native maps safe-area edges through the client
origin and paired logical/backing ratios. Nonzero origins and visual/safe-area
intersections apply once. Resize, rotation, DPI/screen moves and invalid-size
recovery invalidate readiness; headless/SubViewport fixtures inject geometry
without changing the host Window. Export metadata enables `viewport-fit=cover`;
native sensor orientation permits rotation.

GUI popups explicitly use embedded subwindows, sharing the app's logical units.
A forced separate-native PopupPanel experiment clipped its children and is
unsupported/unaccepted; its original capture remains diagnostic evidence only.
The incorrect native-sizing branch was removed. A guard rejects unsupported
native popups without leaving an invisible modal input block. Fresh supported
embedded captures across screen 0→1→0 contain every child; the compact Retina
618×302 logical keypad retains 20 px text, 48 px targets, draft and focus.
Evidence: `localtmp/restructure_rg11/native/embedded-verified.json`.

Final verification passed: `make check` (110 scripts, 754 Godot tests,
112,950 assertions plus Python/lint/format/docs/characterization), all four
current invariant matrices (348/406/288/232), exported input (5), strict quick
layout (5), and exported geometry (24 across DPR 1/2/2.625/3). Geometry export
verification compared 400 production files with no copy mismatch or source
changes. Browser gates reported no errors; the unit suite includes one
explicitly asserted expected unsupported-popup diagnostic. Logs/reports:
`localtmp/restructure_rg11/check-final.log`, `invariants-final.log`,
`web-input-policy-final/`, `web-layout-policy-final/` and
`web-geometry-policy-final/` (including `source-verification.json`).

Review captures under `localtmp/gui-elements/` include
`rg11-web-table-1280x720.png`, `rg11-native-normalized-table-retina.png` and
`rg11-embedded-compact-keypad-retina.png`. These demonstrate viewport/fit
infrastructure with the legacy presentation, not completed shared card/seat/
button/field components. Their owning tasks remain unchecked. User visual
acceptance is pending; stop before RG-12 with the current code organization,
Godot/responsive-layout rationale and remaining legacy work explained.

### RG-11R preview corrections — 2026-10-29

Implemented the selected review corrections without introducing new production
files. The actual event-log body uses 18 logical/CSS px. Snapshot collection
retains that node's semantic identity; only `event` + rich-text observations
receive the 18 px exception in GDScript and paired-axis Web output checks.
Unrelated rich text, labels, cards, keypad text and touch targets retain their
existing floors. Smaller copy shows more history in the same docked height;
scroll-following may leave a partial older line at the top.

The compact six-seat plan reserves measured rounded-felt corner clearance for
the upper side seats and checks complete seat/status footprints before use.
Its lower log, human and action rectangles are unchanged and retain common top
and bottom edges. No collision pass or new layout helper was added.

The keypad uses a permanent three-column digit grid, with placeholders around
the single `0` below `8`. Separate utility and footer containers keep digit
order independent of available space. A `BoxContainer` selects horizontal or
vertical composition from measured minima. Public action/focus handles replace
private-path coupling in production and six existing test files; transaction,
wager, visibility and modal assertions remain intact. Tests cover long exact
Min/Pot values, portrait→618×302→portrait, child containment, digit positions,
20 px keypad text, 48 px targets, draft and focus preservation.

Final checks passed: `make check` (112 scripts, 761 Godot tests, 113,199
assertions plus Python/lint/format/docs/characterization), all four current
invariant matrices (348/406/288/232), exported geometry 24, strict quick layout
5 and exported input 5. There were no unexpected errors; the unsupported-popup
unit test deliberately asserts its diagnostic. Evidence lives in
`localtmp/restructure_rg11_review/` (`check.log`, `invariants.log`,
`web-geometry/`, `web-layout/`, `web-input/`). Focused migration evidence is
also in `localtmp/restructure_retirement/keypad-callers.log`.
`source-verification.json` compares 400 production files for each browser gate
with zero mismatches. The actual compact Retina capture also records its
matching keypad source hash and zero escaped children in
`localtmp/gui-elements/rg11-revised-keypad-review.json`.

The universal three-seat-row requirement is mandatory for the new layouts.
Known reference conflicts remain in small-desktop counts 5–9
(`table_seat_layout.gd`), nine-seat compact-tablet/full-ring paths
(`table_seat_layout.gd`, `gui_table_seat_layout.gd`) and the unsupported 8/9-phone
fallback (`gui_phone_seat_layout.gd`). These old positions do not constrain
replacement design or require further legacy redesign before RG-12/42/50–52.
The reviewed six-player sample has an independent horizontal-band capacity
check, including an anti-stagger rejection; it does not certify all layouts.

Revised review files: `localtmp/gui-elements/rg11-revised-table-1280x720.png`
and `rg11-revised-keypad-618x302.png`, with session metadata alongside them.
Both are implementation previews, not final replacement/device acceptance.
User visual acceptance remains pending; stop before RG-12.

### RG-11R2/RG-11R3 keypad utilities and Total field — 2026-10-29

The user accepted the number arrangement and explicit wager limits, requested
rectangular utility controls, and rejected tournament Quit within numeric
entry. The revised table layout was accepted apart from the Total field;
this is not acceptance of the forthcoming replacement or physical devices.

Removed the keypad's tournament-exit signal, button, configuration API and
controller wiring. One two-column grid now owns equal measured utility cells:
Clear/Back, Min/Pot, Cancel/Done for wager entry; Clear/Back, Cancel/Done for
plain numbers. Wager presets remain visible across layout profiles; plain
number mode alone omits them. Shared cell widths derive from visible content
minima and normal expansion flags. The approved 3×3+centered-0 digit grid and
explicit wager limits remain. Cancel preserves the exact committed value;
Done commits the draft for the owning adapter's validation. Tournament exit
remains in the table/menu after closing entry. Modal tests retain confirmation,
focus, Escape/back and no-game-mutation coverage through that route.

The actual Total `LineEdit` now has a white surface and zero-radius corners
in normal, focus and read-only states, with dark-green text/caret/placeholder
and contrasting selection. Existing padding, border widths and geometry are
preserved; Raise retains its action-button styling. This bounded correction
does not complete the authored shared theme/control work in RG-30/RG-39.

Combined final verification: `make check` passed 112 scripts / 762 Godot tests /
113,324 assertions plus Python/lint/format/docs/characterization checks. All
four final invariant matrices passed (348/406/288/232). Fresh final exported
geometry 24, strict quick layout 5 and input 5 passed without browser/export
errors. The GUT suite retains one deliberately asserted unsupported-popup
diagnostic. Final evidence is in `localtmp/restructure_rg11_keypad_review/`:
`check-final.log`, `invariants-final.log`, `web-geometry-final/`,
`web-layout-final/` and `web-input-final/`. Earlier unsuffixed reports there
cover the keypad revision before Total-field styling, not the combined final
candidate. Focused field evidence: `localtmp/restructure_retirement/total-field.log`.
Final `source-verification.json` compares 400 production files per browser
gate with zero mismatches. The clean native capture batch is `capture-final.log`;
an initial capture-only texture-bootstrap diagnostic remains in `capture.log`
and is not acceptance evidence. Final compact, number and wager captures all
report no Quit control, no escaped children, no font/target/text-fit failures
and uniform utility cells, with matching live source hashes.

Review images under `localtmp/gui-elements/`:
`rg11-keypad-rectangle-618x302.png`,
`rg11-keypad-rectangle-wager-portrait.png`,
`rg11-keypad-rectangle-number-portrait.png`, and
`rg11-table-input-field-1280x720.png`, with metadata/source identity alongside.
User visual acceptance of these revisions remains pending; stop before RG-12.

Partial visual acceptance (2026-10-29): the user accepted
`rg11-keypad-rectangle-number-portrait.png` and
`rg11-keypad-rectangle-wager-portrait.png`. The remaining current review images
are `rg11-keypad-rectangle-618x302.png` (compact utility rectangle) and
`rg11-table-input-field-1280x720.png` (updated Total field). Their acceptance is
still pending before RG-12; older captures are superseded reference evidence.

### RG-11R4 Total appearance, Quit border and keypad acceptance — 2026-10-29

The user accepted `rg11-keypad-rectangle-618x302.png` for landscape aspect ratios
only; both portrait keypad previews were already accepted. The keypad now has
an explicit landscape guard for horizontal composition in addition to measured
fit. Actual-rectangle tests verify utilities below digits in portrait and
beside them in compact landscape. Accepted keypad geometry is unchanged.

The user revised Total to light-grey (`#D6DED8`) text on dark green, with sharp
corners and a shorter face vertically centered beside Raise. All three field
states use -4 top/bottom StyleBox expansion: the 80×48 input hit rectangle at
(1037,567) paints an 80×40 face at (1037,571); Raise is 56×48 at (1121,567),
sharing center y=591. Content padding, container allocation and typography
remain unchanged. Generic fields retain their white/dark-text palette; the
future theme/control tasks preserve the Total-specific variation.

The actual table Quit control joins the existing action-style loop, using the
same normal/hover/pressed/focus/disabled styles as Raise. Its normal border is
1 px with 4 px corner radii. Tournament Quit remains outside numeric entry.
No production file, wrapper or manual child-position adjustment was added.

Final combined `make check` passed 112 scripts / 762 Godot tests / 113,361
assertions plus Python/lint/format/docs/characterization checks. All four final
invariant matrices passed (348/406/288/232), as did fresh exported geometry 24,
strict quick layout 5 and input 5, without browser/export errors. One unit test
continues to assert the expected unsupported-popup diagnostic. Evidence:
`localtmp/restructure_rg11_total_final/check-final.log`, `invariants-final.log`,
`web-geometry-final/`, `web-layout-final/`, `web-input-final/` and
`source-verification.json` (400 production files per gate, zero mismatches).
Unsuffixed reports in that directory predate the final Quit-border revision.

Review screenshot: `localtmp/gui-elements/rg11-total-dark-inset-1280x720.png`.
Its `rg11-total-dark-inset-review.json` records matching source hashes and
independent PNG evidence: painted rows 571–610, 40 px high, with 4 px unpainted
hit strips above/below. `total-hit-edge-proof.json` records browser pointer
focus at both strips and successful keyboard entry/submission of 250, without
opening a keypad. Style measurements and focused evidence are in
`total-style-measurements.json` and
`localtmp/restructure_retirement/total-inset.log` / `quit-family.log`.

At that review checkpoint, keypad previews were accepted for their respective
orientations and the latest Total/Quit appearance remained pending. Subsequent
branding/phone acceptance and final verification are recorded below.


### RG-11R5/R6 final execution record (2026-10-29)

The no-scroll Start captures and all five review7 phone captures were accepted
by the user. Final boundary verification found and fixed a seven-way winner
summary overlap at 360×640. A last measured seat candidate stacks the two
revealed 46×30 cards vertically while preserving ranks, names, chip values,
roles and the two-line status band. Direct resize/rebind regressions verify
horizontal card positions and typography restore on landscape/wider layouts.
The layout uses the shared actual community/hero height budget; ordinary
short-phone copy can stay at 20 px instead of unnecessarily falling to 18 px.
Four of five review7 captures remain pixel-identical.

Final verification against the frozen implementation:

- `make GODOT=/Applications/Godot.app/Contents/MacOS/Godot check`: passed;
  118 GUT scripts, 787 tests, 115,267 assertions, plus all Make prerequisite
  checks, lint and formatting. Log:
  `localtmp/restructure_rg11_review7final/check-final.log`.
- `gui-current-invariant-gate`: all four matrices passed (348 / 406 / 288 /
  232 cases). Log: `localtmp/restructure_rg11_review7final/invariants-final.log`.
- Exported browsers: 24 geometry, 5 input and 5 strict layout cases passed;
  415 production/asset files compared per export with zero mismatches.
  Evidence: `localtmp/restructure_rg11_postfit/`, including
  `source-verification.json` and `capture-verification.json`.
- Characterization retains all 9,994 inputs and its policy hash: 1,098 known
  failure cases, zero unexpected deltas. Only unsupported nine-player phone
  records were reviewed and changed; no supported two-to-seven-player waiver
  was added. Exact audits:
  `localtmp/restructure_rg11_branding/r6-max2-registry-migration-audit.json`
  and `r6-extreme-registry-migration-audit.json`. A passing unsupported sample
  does not expand phone startup capacity.

Final additional review images:
`localtmp/gui-elements/rg11-review8probe-table-360x640-p7-human-turn-preflop.png`
and
`localtmp/gui-elements/rg11-review8-extreme-table-360x640-p7-showdown-long.png`.
Their metadata records matching source hashes and no invariant failures.
These two additions await visual review; all prior user acceptances remain
recorded. No RG-12 implementation or replacement-component/device acceptance
is claimed. Stop here as requested.


### RG-12 unified size and fit policy — 2026-10-29

Implemented the replacement-only pure `GuiSizeClass`, `GuiFitMetrics`,
`GuiFitCandidate`, `GuiSeatRows` and `GuiFitPolicy` under `scripts/gui/layout/`.
The architecture records the axis classes, derived modes, fixture override,
finite measured envelopes, capacity guidance and per-axis/orientation monotonicity.
Explicit rows cap wide seats at three and portrait opponents at two with a
centered odd apex. Landscape opponents also use two per band so a hero rail
cannot create a four-seat row. Clockwise IDs and caller input are retained.

Seven-player portrait/landscape and nine-player wide edge tests use explicitly
marked primitive minima; they certify the solver, not final component fit.
Tests cover all recipients/counts, invalid inputs, threshold ±1, usable extent,
minimum-fit edges, density fallback and growing space across preferences.
The passive authored `SpaceGuidance.tscn` reuses the transparent brand scene,
measures actual wrapped text at 20 px and takes no input or game ownership.
Its rendered containment/font tests cover portrait and short landscape.
The running legacy GUI is unchanged; routing remains RG-13.

Session outputs were cleared at the user's request before work. Historical
`localtmp/` filenames above remain historical references, not fresh evidence.
New review images under `localtmp/gui-elements/`:
`rg12-capacity-portrait.png`, `rg12-capacity-landscape.png` and
`rg12-space-portrait.png`, with `rg12-guidance.json` metadata. The seven-player
space warning uses deliberately oversized primitive minima to demonstrate its
state; it does not declare 360×640 unsupported for the forthcoming components.
Guidance visual review is pending; stop before RG-13 for user acceptance.


Verification: `make GODOT=/Applications/Godot.app/Contents/MacOS/Godot check`
passed 120 GUT scripts / 800 tests / 118,379 assertions plus Python, lint,
formatting, docs and exact characterization checks. All four current GUI
invariant matrices passed. Final logs contain no engine/script errors or
warnings: `localtmp/restructure_rg12/check-final.log` and
`invariants-final.log`. The new policy/guidance coverage adds 13 tests.
Rendered captures completed with zero save errors; source and image hashes are
in `localtmp/gui-elements/rg12-source-verification.json`. Documentation links
and formatting were checked after updating this completion record.
RG-12 implementation is checked; new guidance acceptance remains pending.
RG-13 and all subsequent tasks remain untouched.


### RG-12 guidance acceptance — 2026-10-29

The user accepted the guidance design shown in the RG-12 portrait/landscape
previews and authorized continuation. This accepts that component's appearance;
it does not accept final table layouts, device support or production integration.
RG-13 is the next ordered task.


### RG-13 replacement routing execution — 2026-10-29

Used the explicitly permitted clean replacement path: `CompositionHost.tscn`
registers authored scenes by selected fit mode and passes `GuiCompositionState`
to their `apply_policy()` API. Density/action flow now belong to measured
candidates. Real independent container fixtures verify seven-player phone
orientations and nine-player wide routing, fallback selection, stable IDs for
every recipient, origin application once, same-mode reuse, mode replacement,
invalid/missing registrations and actual content-minimum recovery.

The host bypasses the named reference modules rather than extracting another
legacy geometry helper. Finished table scene registrations remain RG-51/52;
match/model/overlay orchestration remains RG-53 and default cutover RG-54.
No reference positions, six-seat expectations, known-failure records or product
state were changed. The scope guard runs in default checks and has mutation
coverage for forbidden imports/reclassification/viewport thresholds versus
allowed measured fit, containment and target-floor validation.

Final verification passed: `make check` (121 GUT scripts / 807 tests /
118,499 assertions plus Python/lint/format/docs/policy/characterization checks)
and all four reference GUI matrices. No engine/script errors or warnings in
`localtmp/restructure_rg13/check-final.log` and `invariants-final.log`.
The registry and deterministic six-seat tests are unchanged. Focused routing
coverage passes seven tests / 118 assertions; five policy-guard mutation tests
pass. This task introduces no new table design; accepted guidance is reused.
The owner must defer remeasurement until the current presentation completes.
RG-20 follows next.


### RG-20 presentation model execution — 2026-10-29

Implemented pure typed card/card-row, seat, center, action-bar, table, hand-summary
and event-log models. The controller and reference seat/action adapters consume
them; source poker rules and GameView are unchanged. Models detach all visible
card values and retain no core or scene objects. Identity-free backs/empty slots,
all action kinds, exact values, densities, active/retained action lifetimes and
main/split/side/fold-winner emphasis have focused coverage. History is one model
independent of docked/overlay use. Pre-tree binding/rebinding is tested.

Focused model/adapter batch passed 76 tests / 3,098 assertions before the final
pre-tree regression was added. Final `make check` passed 126 GUT scripts /
836 tests / 119,776 assertions, plus Python/lint/format/docs/policy and exact
characterization checks. All four GUI matrices passed; final logs contain no
engine/script errors or warnings. Evidence: `localtmp/restructure_rg20/`
(`check-final.log`, `invariants-final.log`, `focused-final.log`). The
previous task's verified checkpoint is committed as `122f344`, using
`git add --all` as the user requested, before any RG-20 implementation.


### RG-21 presentation-test migration — 2026-10-29

The [coverage map](GuiModelCoverage.md) records every moved action/summary case,
the exact replacement model tests and retained adapter responsibilities. Pure
Pot boundary evaluation now runs without a scene. Real core-derived views feed
repeated-raise, short-stack and closed-rights model coverage. Exact phone
fold/split/side-pot names/shares moved to summary tests; actual overlay button
activation, bound text, privacy, input/modals and submitted/rejected wagers remain
in scene tests. Core rule tests, matrix definitions and characterization are
unchanged. Single-case before/after timing is recorded without a speedup claim.
Final `make check` passed 127 GUT scripts / 841 tests / 119,817 assertions
plus Python/lint/format/docs/policy and exact characterization checks. All four
GUI matrices passed. No engine/script errors or warnings in the final logs
under `localtmp/restructure_rg21/` (`check-final.log`, `invariants-final.log`).
The coverage map records the before/after timings and limitations. RG-30 is next.


### RG-30 shared-theme review candidate — 2026-10-29

Authored the replacement palette/type variations in `resources/gui_theme.tres`,
including button/field state distinctions, sharp light fields, the approved
Total exception and bold bright-yellow winner text. All use Godot's built-in
default font; no font file or SystemFont is introduced. Effective inheritance,
role fonts, actual control allocations, default bold-font metrics, validation
focus and Total face/target geometry pass six focused tests / 380 assertions.

The independent native gallery is
`localtmp/gui-elements/rg30-theme-palette-1280x980.png`; matching source hashes,
zero image-save error and zero escaped controls are recorded in
`rg30-theme-palette.json`. It shows at most three seat samples per row and
reserved status bands beneath panel surfaces. Fixture-only simultaneous
hover/pressed/focus simulations make authored states comparable in one image.
These are theme samples, not completed card/seat/action scenes or device support.
The legacy default remains unchanged until replacement components/cutover.

Final `make check` passed 128 GUT scripts / 847 tests / 120,197 assertions
plus Python/lint/format/docs/policy and exact characterization checks. All four
GUI matrices passed. Final logs contain no engine/script errors or warnings:
`localtmp/restructure_rg30/check-final.log` and `invariants-final.log`. The
current screenshot/source hashes match the final resource; capture reports
zero escaped controls and zero save errors. Documentation checks passed after
updating this record. The palette must be user-reviewed before checking RG-30
or proceeding to RG-31. No RG-31 implementation has started.
The user permits visual polish while retaining functionality and the single
font constraint.


### RG-30 review refinement: disabled labels, avatars and card proportions — 2026-10-29

The user generally liked the palette and requested grey disabled-button text,
avatars on larger-screen seats and broader cards with large, balanced value/
suit glyphs. The revised theme sets disabled action text to `#A8A8A8`. Four
wide/human gallery seats display existing assigned avatar samples; the compact
phone sample omits one. Reserved status bands and the three-seat row cap remain.

The gallery now gives face/back samples fixed 120×168 allocations (5:7) with
vertical shrink alignment so the surrounding row cannot stretch them narrower.
Black `10♠` and red `A♥` show equal value/suit font sizes chosen from actual
default-font metrics and the padded content area. The next size is checked
against independent Label/Container minima. This fitting script is a review
fixture, not early completion of RG-40; the future reusable components inherit
these contracts. The actual running reference table has not been redesigned.

Eight focused theme tests / 421 assertions pass, including avatar identity,
aspect preservation, actual card proportions, glyph fit and largest fitting
size. Revised review image:
`localtmp/gui-elements/rg30-theme-review2-1280x980.png`, with matching source
hashes and measured card/font records in `rg30-theme-review2.json`.
Final `make check` passed 128 GUT scripts / 849 tests / 120,238 assertions
plus Python/lint/format/docs/policy and exact characterization checks. All four
GUI matrices passed. No engine/script errors or warnings appear in the final
logs under `localtmp/restructure_rg30_review/` (`check-final.log`,
`invariants-final.log`, `capture-final.log`). Native metadata confirms all
three cards are 120×168 and both face samples use equal 55 px value/suit fonts;
no controls escape the capture and the image saves successfully. Source/image
hashes are verified in `rg30-theme-review2-source-verification.json`.
Documentation checks pass. RG-30 stays unchecked pending review of these
refinements; RG-31 is not started.


### RG-30 review3: grayscale, human prominence, stronger acting frame and card ink — 2026-10-29

The revised gallery applies the authored `gui_grayscale_material.tres` to the
complete folded sample and inherits it through every descendant, including its
avatar. The folded surface/border are neutral grays. Human sample allocation
is 403×112 versus 350×84 bot faces, with 22 px identity text and an 80×80 avatar
versus 18 px / 64×64. The acting frame is six pixels wide rather than three;
legacy reference styling remains unchanged until component cutover.

Card samples retain 120×168 proportions and positive six-pixel content margins.
The review fixture measures shaped glyph ink with the default font, chooses a
fitting size and draws at the corrected baseline, avoiding unused line leading.
Native samples now use 90/91 px instead of 55 px. Independent saved-PNG checks
find 65–80 px-high value/suit ink, wholly within the safe padding; folded
surface/avatar pixels have zero RGB channel difference while the active avatar
retains color. The fixed review dimensions/fonts do not constrain scalable
RG-40 components. The user's scaling question is answered by the existing
container-fit contract; smaller sizes must retain the 20 px text floor.

Final `make check` passed 128 GUT scripts / 850 tests / 120,268 assertions plus
Python/lint/format/docs/policy and exact characterization checks. All four GUI
matrices passed; final logs have no engine/script errors or warnings. Evidence:
`localtmp/restructure_rg30_review3/check-final.log`, `invariants-final.log`,
`theme-focused.log` (9 tests / 449 assertions), `capture-final.log` and
`pixel-verification.log`. The review image is
`localtmp/gui-elements/rg30-theme-review3-1280x980.png`, with matching metadata
and independent pixel/source verification JSON alongside it. These are palette
and sample-rendering checks, not completed RG-40/41 or device acceptance.
RG-30 remains unchecked pending review3 acceptance; RG-31 remains not started.


### RG-30 review3 acceptance — 2026-10-29

The user explicitly accepted the latest theme: full grayscale folded surfaces/
avatars, larger human seat, stronger acting frame and ink-fitted cards, and
authorized continuation. RG-30 is checked off. This accepts the theme/sample
appearance, not unfinished replacement components or device support. RG-31 is
the next ordered task; independent Rules/Profile Hover plans remain unstarted.

### RG-31 implementation and marker review — 2026-10-29

Compact/regular metric Themes now apply at the replacement composition root
from the selected candidate density. Native inheritance retains palette styles
and bold metrics. `GuiSeatTextFit` measures complete normal/bold runs, including
blank status bands, with an explicit failure below the 18 px floor. Focused
tests exercise same-root density changes, fallback selection, exact fit edges,
invalid measurements and seven/nine-seat typography groups. These group
fixtures do not complete the future phone/wide table sweep. The replacement
policy guard rejects content scaling and recursive font repair.

The requested separate white circular D, SB/BB badges and all-winner stars are
authored theme roles and independent gallery samples. Heads-up D + SB are
separate; side-pot and fold winners also show stars. Preview:
`localtmp/gui-elements/rg31-markers-winners-1280x980.png`, with matching capture
metadata. Visual acceptance is pending. Production component binding remains
in RG-41/42. RG-31 stays unchecked: reference scaling/helper removal and its
full completion criteria remain outstanding. The user requests committing all
changes on the current branch and pushing after RG-31 is complete and verified,
before continuing to the next task.

Verification of this intermediate candidate: `make check` passed 129 GUT scripts,
856 tests and 120,465 assertions, together with documentation, Python, lint,
format and characterization checks. All four GUI invariant matrices passed.
Logs: `localtmp/restructure_rg31/check-after.log`, `invariants-after.log` and
`focused.log` (29 tests / 1,021 assertions). These passes verify the current
candidate; they do not mark RG-31's outstanding criteria complete.

### RG-31 marker review2 — 2026-10-29

The user accepted the white dealer button and SB/BB badge appearance, requested
their placement in the upper-right corner, and requested a larger winner star
independent of a single text line. The gallery now places markers at the
upper-right inset and a separate 44 px star at the lower right. Bot/human face
heights are 108/124 to keep markers, stars and identity copy separate. The
human retains larger type and avatar. This reviews independent state samples;
production seat rendering remains in RG-41/42.

Focused palette/typography tests pass (15 tests / 645 assertions), including
corner placement, separate heads-up D/SB, star size and non-overlap with badges.
Native capture reports no escaped controls or engine errors. Review image:
`localtmp/gui-elements/rg31-markers-winners-review2-1280x980.png`, with matching
JSON metadata. Revised placement/star acceptance is pending; RG-31 stays open
and its requested commit/push checkpoint has not been reached.

Full `make check` passed for review2: 129 GUT scripts / 856 tests / 120,467
assertions, plus documentation, Python, lint, format and characterization
checks. Log: `localtmp/restructure_rg31/review2-check.log`.

### RG-31 marker acceptance and status alignment — 2026-10-29

The user explicitly accepted the winner-star, dealer and SB/BB placement.
This acceptance covers the revised gallery appearance; RG-31's remaining
implementation criteria and the later production seat components stay open.

Status labels previously filled a grid column while bot seat boxes were
narrower and centered. They now share the seat box width and centered
allocation, so last-action/result copy starts at the box's left edge. The
human's wider box and matching status width are retained. Focused tests verify
both edges for all five samples (15 tests / 655 assertions). Native review3
capture has no escaped controls or engine errors:
`localtmp/gui-elements/rg31-markers-winners-review3-1280x980.png` and matching
JSON metadata. Full `make check` passed: 129 GUT scripts / 856 tests / 120,481
assertions plus documentation, Python, lint, format and characterization gates.
Log: `localtmp/restructure_rg31/review3-check.log`.

### RG-31 completion and commit checkpoint — 2026-10-29

The user accepted the final gallery and authorized continuation. To resolve the
retirement timing conflict, the user explicitly selected removing reference
font scaling now. RG-31 therefore applies shared metric Themes to both paths:
replacement composition roots, reference TableSurface, startup Form and keypad
popup. Content/portrait/seat scale no longer multiplies font sizes. Geometry
scales remain for avatars/cards, popup allocations and targets. The table's
recursive font-floor repair and startup's recursive font traversal are removed.

Native inheritance preserves the palette and single built-in font. Seat text
is bounded to 18, cards/other text to 20 and log body to 18. Normal/bold native
Label minimums agree with the bounded fitter across preferred sizes 18–26 and
multiple available rectangles, including a blank reserved band. Role tests
cover every inherited label, button, field and log font. Reference fit/identity,
privacy, keypad transactions, modal behavior and stable-footprint tests remain.
Native dialog Theme constants keep internal OK/Cancel buttons at 48×48; the
Fold allocation also retains that floor after its text becomes smaller.

The exact characterization update preserves 9,994 ordered inputs, the matrix
hash and the same 1,098 failing inputs. Typography/semantic-role changes alter
25 already-failing scene/resize diagnostic sets. Pure cases are unchanged and
no newly failing input is registered. The audit and previous registry are under
`localtmp/restructure_rg31/characterization-migration-audit.json` and
`characterization-registry-before.json`. This records reference defects rather
than accepting them or completing later replacement-composition work.

Final `make check` passes 129 GUT scripts / 860 tests / 120,901 assertions, plus
Python, documentation, lint, formatting and exact characterization checks.
All four GUI matrices pass, with their case definitions unchanged. Read-only
review identified the native dialog target regression; it is fixed and the
matrices were rerun. Logs: `localtmp/restructure_rg31/check-final3.log`,
`invariants-final2.log`, `floors-focused.log` and `startup-keypad-after.log`.
RG-31 is checked off. The requested checkpoint stages all accumulated changes,
commits them on `gui-restructure` and pushes that branch before RG-39.

Development captures under `localtmp/gui-elements/rg31-reference-desktop/`,
`rg31-reference-phone/` and `rg31-reference-startup/` show the reference GUI's
typography after scaling removal; their manifests report passing invariants.
These still use reference layouts/cards/markers, not completed replacement
components or device acceptance. Show these visible typography changes for
review before proceeding to RG-39. The accepted replacement gallery remains
`localtmp/gui-elements/rg31-markers-winners-review3-1280x980.png`.
