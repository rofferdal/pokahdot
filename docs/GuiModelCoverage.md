# GUI presentation-model coverage map

RG-21, 2026-10-29. The models own pure recipient presentation; real adapter
checks still own activation, submission, modal/input behavior and rendered
privacy. Core rule tests are unchanged. No scene timing improvement is claimed.

## Migrated action cases

Old scene cases are in `tests/unit/test_gui_table_actions.gd`; new pure cases
are in `tests/unit/test_gui_action_bar_view_model.gd`.

| Old case | New model case | Retained scene evidence |
| --- | --- | --- |
| `test_pot_wager_shortcut_respects_legal_action_and_inclusive_total_bounds` | Same name; the entire 7-assert case now runs without a scene. | Real pot bet/raise, below-minimum, short-stack and exact-boundary button/submission tests remain. |
| `test_live_repeated_raise_uses_existing_wager_and_reopens_action` | `test_core_repeated_raise_and_short_stack_views_supply_exact_model_pot_and_bounds`: pre-submit call/minimum/maximum observations. | Actual button copy, pot target, submitted raise, chip movement and reopened action remain. |
| `test_live_repeated_raise_refreshes_minimum_and_rejects_obsolete_input_across_profiles` | Same core-derived repeated-raise model case: refreshed minimum/call observations. | Four-profile button/input/keypad state, draft/bounds, obsolete-target rejection and no mutation remain. |
| `test_live_short_stack_disables_exact_pot_without_clamping_to_all_in` | Same core-derived repeated-raise model case, 100-chip stack: exact maximum and unavailable Pot. | Actual disabled button activation, unchanged state and separate minimum/all-in controls remain. |
| `test_core_short_all_in_views_keep_raise_controls_aligned_with_recipient_rights` | `test_core_short_all_in_views_present_open_and_closed_raise_rights`: exact call/minimum and model flags from real BettingRound views. | Four-profile UI enablement/editability, keypad gating and visible legal bounds remain. |

The repeated-raise model case uses real TournamentMatch views at 500- and
100-chip starting stacks. Closed-rights coverage uses real BettingRound views
with 100/50-chip unacted seats. These cases consume authoritative core results;
they do not calculate betting rules inside the model.

## Migrated phone result copy

Old cases remain in `tests/unit/test_gui_phone_secondary_overlays.gd`; new pure
cases are in `tests/unit/test_gui_hand_summary_view_model.gd`.

| Old case | New model case | Retained scene evidence |
| --- | --- | --- |
| `test_phone_summary_names_fold_winner_without_revealing_cards` | `test_summary_names_fold_winner_with_exact_share_and_no_revealed_cards`: exact assigned name/share/result copy and semantic emphasis. | Opened overlay binds the model body; unrevealed opponent cards remain absent. |
| `test_phone_summary_reports_each_split_and_side_pot_share_and_assigned_winner` | `test_summary_reports_every_split_and_side_pot_share_and_assigned_winner`: exact pot names/shares, ordered winners, assigned tournament-winner copy and emphasis. | The real Pots button opens the overlay; visible body/status bind the corresponding models. |
| `test_phone_showdown_summary_uses_only_recipient_safe_results` | `test_summary_descriptions_are_public_and_ordered_without_private_card_identity`: direct public-result formatting coverage added. | The original overlay privacy, open/close and hidden-seat exclusions remain because rendered disclosure is an integration concern. |

Actual hand progression and winner pauses remain in
`test_gui_phone_winner_flow.gd` and the table-actions integration cases. The
seat/card model tests independently cover exact `Winner`, all main/split/side
award recipients, status variants, hidden backs and authorized faces. Seven-way
winner wrapping, typography, target bounds and layout tests remain rendered.

## Measurement and verification

The relocated single Pot case preserved 1 test / 7 assertions: scene-before
GUT time 0.381 s; model-after 0.425 s. These are single startup-dominated runs,
not a controlled performance benchmark. The model avoids creating a scene;
these measurements establish no speedup. Focused retained table-actions:
38 tests / 595 assertions, 2.054 s; action models: 11 tests / 246 assertions,
0.416 s. Phone-summary model/overlay batch: 9 tests / 70 assertions, 0.667 s.
Logs live under ignored `localtmp/restructure_rg21/`.

Full default checks and all four GUI matrices are required before RG-21 is
checked off in [the owning backlog](RestructureGuiTasks.md). The exact legacy
characterization registry and matrix definitions were not changed.


## RG-41 seat-state extension

`SeatViewModel.state_text` supplies marker-free Turn/Fold/All In/Out copy;
the reviewed full panels use only name/stack/wager inside the box, with state
and action/result information in their status band. Legacy `badge_text` and
token formatting retain their existing contracts. `test_gui_seat_components.gd` verifies this field from real
model builds with dealer/small-blind flags, along with full typed panel snapshots,
reserved bands, card redaction, state rebinding and inherited typography.
No RG-21 cases were removed or reclassified by this component work.


## RG-50S full-panel reconciliation

Wide bot panels consume the existing stack_value_text for numeric stack copy,
falling back to stack_text for detached manual fixtures; the human retains full
stack_text. No rules or visibility decisions moved into rendering. Semantic
get_field handles and the typed seat snapshot remain stable across the authored
hierarchy correction. Regressions cover the fixed corners, human/bot typography,
seven-digit layout reserve, all states, grayscale and unauthorized child-card
mutations at native minima and after resizing.


## RG-51 replacement diagnostics

`ActionBarViewModel.legal_actions` and `action_roles` copy core availability into
detached diagnostic values. The model tests verify that mutating those values
cannot change the recipient view. Rendering and schema-2 snapshot validation
check actual semantic controls, native content minima, legal-action reachability,
menu routes and per-card privacy. Schema-1 reference observations and the exact
historical characterization registry remain unchanged. This adds replacement
coverage without removing or reclassifying the earlier model/scene cases.


## RG-53 session and orchestration coverage

`GuiTableSession` delegates action construction and submission to the existing
core APIs and uses the existing public-event formatter. Its tests cover exact
Pot contribution/total pairing, overflow and rejection feedback, street/fold
history, short-blind runouts, completed-hand pacing, modal holds, recipient
changes and stale callback epochs. An accepted wager invalidates an old modal-held
callback before publishing its fresh pause; rejected wagers retain prior
progression. The core retains betting/progression rules.

Replacement-controller tests cover native mode/fit selection, safe-origin
placement, generation invalidation, persistent modals, exact draft/caret/selection
and focus reconstruction, guidance cancellation and ordinary-action probe reuse.
Startup tests verify one selected controller and adoption of the existing match.
Four independent lifetime cases cover transactions/private details on rebind,
invalid binding and destruction during measurement. Component destruction tests
reproduce and prevent deferred callbacks resuming freed scripts.

Numeric entry carries the visible Pot contribution separately from its exact
street-total preset. A component test verifies caption 45 with payload 55 and
preserves the payload fallback for generic callers. Controller integration checks
native preset selection and cancellation. No historical RG-21 mapping or schema-1
reference matrix was removed or reclassified.


The RG-53 exported-browser check exposed unavailable suit glyphs in the embedded
font. Conditional SVG rendering preserves the same `CardViewModel` identity and
permission decisions. Card tests exercise all 52 faces with system fallback
disabled, verify actual ink and theme tint, and preserve empty/back/redacted
snapshot contracts. Decoration and keypad-caption fallbacks add no rules or
recipient data to the rendering layer.
