# GUI presentation-model coverage map

RG-21, 2026-10-29. The models own pure recipient presentation; real adapter
checks still own activation, submission, modal/input behavior and rendered
privacy. Core rule tests are unchanged. No scene timing improvement is claimed.

## Current replacement coverage

`test_gui_action_bar_view_model.gd` checks legal-action presentation, exact Pot
contribution and street totals, repeated raises, short stacks and full-raise
rights from authoritative core views. `test_gui_table_session.gd` exercises live
submission, invalid drafts, pacing, modal holds and recipient-safe state;
`test_product_roster_cross_interface.gd` compares seeded GUI and CLI outcomes.
Exported browser input checks cover pointer, touch, keyboard, modal and keypad
transactions through the replacement canvas.

`test_gui_hand_summary_view_model.gd` checks assigned winner names, split/side
pot shares and public descriptions. `test_gui_replacement_winner_flow.gd`
drives real settlements, fold wins, pauses, guidance recovery and card privacy.
The replacement snapshot contracts and native composition matrices validate
rendered roles, complete text, seat footprints and authorized card visibility.

## Historical RG-21 measurements

The earlier reference Pot-case migration retained one test / seven assertions;
single startup-dominated runs measured 0.381 s before and 0.425 s after. These
are not a controlled benchmark. The historical reference action suite ran 38
tests / 595 assertions in 2.054 s; the action-model batch ran 11 / 246 in
0.416 s, and the phone-summary batch 9 / 70 in 0.667 s. Ignored logs under
`localtmp/restructure_rg21/` are session evidence only. The reference scene
suites have since been retired; their recorded measurements do not certify the
replacement.


## RG-41 seat-state extension

`SeatViewModel.state_text` supplies marker-free Turn/Fold/All In/Out copy;
the reviewed full panels use only name/stack/wager inside the box, with state
and action/result information in their status band. Legacy `badge_text` and
token formatting retain their existing contracts. `test_gui_seat_components.gd` verifies this field from real
model builds with dealer/small-blind flags, along with full typed panel snapshots,
reserved bands, card redaction, state rebinding and inherited typography.
This records the RG-41 change; the reference scene suites were retired later.


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
historical characterization registry remain unchanged. This recorded the RG-51 change; the reference scene suites were retired later.


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
native preset selection and cancellation. At RG-53 the historical RG-21 mapping and schema-1 reference matrix still existed;
the reference implementation was retired later.


The RG-53 exported-browser check exposed unavailable suit glyphs in the embedded
font. Conditional SVG rendering preserves the same `CardViewModel` identity and
permission decisions. Card tests exercise all 52 faces with system fallback
disabled, verify actual ink and theme tint, and preserve empty/back/redacted
snapshot contracts. Decoration and keypad-caption fallbacks add no rules or
recipient data to the rendering layer.
