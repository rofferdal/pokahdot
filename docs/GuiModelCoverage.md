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
