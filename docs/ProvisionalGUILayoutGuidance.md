# Responsive GUI implementation guidance

This guide describes the current Godot GUI. The
[product specification](ProjectDescription.md) owns player-facing requirements,
[architecture](ARCHITECTURE.md#gui-adapter) owns component boundaries, and
[visual testing contract](GUI_VISUAL_TESTING.md#current-support-and-acceptance)
owns supported profiles and evidence status. Historical milestones are not
blanket acceptance of the current build.

## Display geometry and layout ownership

The project uses Compatibility rendering, `canvas_items` stretch, `expand`
aspect, and a 1920 × 1080 native base viewport. On Web,
`GuiWebViewportGeometry` normalizes backing-window dimensions using screen
scale; `StartupConfigController` applies the logical size to the root window.
Actual usable CSS geometry, DPR, safe-area insets, browser chrome, and keyboard
behavior still require device evidence (GUI-05). Do not infer them from a
screenshot raster or assume safe areas were measured automatically.

`GuiLayoutProfile.classify()` selects phone portrait, phone landscape, tablet,
small desktop, or desktop from usable size/aspect. Explicit overrides require
recorded device evidence. OS flags do not determine layout by themselves.
Phone landscape remains deferred despite diagnostic regression fixtures.

Use containers and anchors for ordinary content. Calculated table regions
must have one layout owner that assigns parent and child rectangles from the
same geometry snapshot. `GuiPhoneLayoutPlan` and `GuiPhoneSeatLayout` supply
current phone geometry; preserve tournament state and core seat IDs on resize.
Do not add a competing container or controller for those rectangles.

## Typography, input, and assets

All player-facing text has a 20 px minimum and touch targets a 48 × 48 logical
pixel minimum. Reflow when space is tight. Required content must pass text-fit
checks, including ellipsis and overlay text. Passing a matrix is evidence for
its fixtures, not proof that every supported numeric value or device is clear;
GUI-02 owns the remaining large-value readability work.

The theme is `resources/gui_theme.tres`. Keep the plain non-serif face across
startup, table, keypad, and overlays. Avoid post-render scaling of desktop
text; adapt owned geometry and source font sizes instead.

Sixteen avatar PNGs have 64 × 64 source pixels. Full seat panel base display
regions are 112 × 112 logical pixels for opponents and 128 × 128 for the human,
with layout adaptation; phone tokens omit avatars. Assignment is GUI-owned,
unique per tournament, and independent of game RNG. Physical output also
depends on DPR; source dimensions are not a browser display measurement.

Input follows event modality. Touch opens the in-canvas keypad; mouse/pointer
focus retains physical-keyboard editing even in a phone-sized desktop window.
Cancel is intended to preserve the exact committed value; GUI-03 owns the
known invalid-text cancellation defect. Do not claim that edge case is fixed.

## Phone composition and acceptance

Phone startup supports 2–7 players, defaults to 6, and may recommend 4.
Tablet, small-desktop, desktop, CLI, and core retain 2–9 support. Never clamp
an active tournament when its viewport changes. Phone densities are standard
for 2–4, compact for 5–6, and minimal for 7 players.

Retain each seat's assigned name, numeric stack, role/state, two card fields,
and latest public action within the owned token regions. More/detail and
summary overlays expose recipient-safe details. Phone layouts have no event
history surface; non-phone layouts retain the event log. GUI-01 and GUI-04
own remaining winner clarity and modal/pacing work.

Run `make check gui-current-invariant-gate` after layout changes and review
rendered captures under the visual testing contract. Keep physical acceptance
in [OptimizingPhoneGuiTasks.md](OptimizingPhoneGuiTasks.md); leave deferred
landscape tasks unchecked. Historical iPad sign-off, incomplete desktop
measurements, and accepted LAN resolution limitations remain separate records
linked by the current documentation index.
