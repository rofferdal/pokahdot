# Responsive GUI implementation guidance

This guide describes the current Godot GUI and its scene/container design.
The [archived restructuring record](arkiv/RestructureGuiTasks.md) preserves its
implementation and acceptance history. The
[product specification](ProjectDescription.md) owns player-facing requirements,
[architecture](ARCHITECTURE.md#gui-adapter) owns component boundaries, and
[visual testing contract](GUI_VISUAL_TESTING.md#current-support-and-acceptance)
owns supported profiles and evidence status. Historical milestones are not
blanket acceptance of the current build.

## Display geometry and layout ownership

The project uses Compatibility rendering, `canvas_items` stretch and `expand`
aspect, retaining its default 1920 × 1080 client window. `GuiViewportAdapter`
owns the runtime virtual base: actual canvas CSS extent on Web and client
pixels/current-window UI scale on native platforms. The old startup-owned
backing/DPR inference is no longer the app's normalization path.

Immutable `GuiViewportGeometry` snapshots preserve the usable origin and size.
Canvas/layout/visual rectangles and CSS safe-area insets intersect once;
native mobile safe rectangles convert through the client origin and actual
logical/backing ratios. Startup, table and popups consume the same rectangle.
Headless/SubViewport/explicit fixture roots inject local geometry and never
normalize the host Window. Sensor orientation enables native rotation; the
replacement uses measured portrait and landscape compositions.

Historical dimensions are regression samples. Component/container minimums
determine feasible layouts, with explicit guidance when space cannot fit them.
Physical browser/device acceptance remains separate from these measurements.
See the [geometry contract](ARCHITECTURE.md#gui-adapter).

`GuiSizeClass` selects a preferred phone portrait, phone landscape, compact
wide or wide mode from the adapter's usable rectangle. Explicit overrides are
for fixtures or recorded device evidence; OS flags do not choose layout.
Container/content minimums determine fit, and physical keyboard and touch
handling remain independent of size and orientation.

The replacement policy is implemented under `scripts/gui/layout/` (RG-12).
`GuiSizeClass` selects a preferred mode from the adapter's usable extent;
`GuiFitPolicy` selects finite measured envelopes independently. The
[architecture](ARCHITECTURE.md#gui-adapter) records thresholds, explicit seat
rows, primitive fit evidence and monotonicity. The `CompositionHost` consumes this policy and routes registered scenes directly.
The replacement table compositions and controller own production play. The isolated
`SpaceGuidance` appearance is user-accepted.

The shared replacement palette/type variations are now authored in
`resources/gui_theme.tres` and support the replacement compositions. New controls should use those
variations. The theme gallery is a review fixture, not a table layout.
Do not introduce another font file or SystemFont; WinningHandText derives its
bold appearance from the built-in font.

Pure `TableViewModel` and child values now own card states, seat copy, winner
emphasis, action flags, center/summary copy and the shared log body. The current
replacement controller consumes them. Components render these values and emit intents
instead of reading GameView or calculating poker-derived text themselves.

Use containers and anchors for ordinary content. Calculated table regions
must have one layout owner that assigns parent and child rectangles from the
same geometry snapshot. `GuiPhoneTablePlan` supplies portrait envelopes;
`GuiPhoneLandscapePlan` supplies symmetric landscape geometry and owns the
permitted top-triple fallback when the ordinary arrangement cannot fit.
`GuiTabletTablePlan` supplies compact tablet geometry with actions beside the
centered human or below when the symmetric width budget does not fit.
Preserve tournament state and core seat IDs on resize. Seats use available
space within the measured center/action constraints; community cards grow as
one aspect-preserving group. On compact tablets the community-card group
matches the human panel width and centers its slots on both screen axes where
possible, using the nearest clear vertical band otherwise. Pot/Wager and
blind/level copy sit directly below. Side actions align to the
human's visual bottom, subject to clearance from other seat/status footprints.
Narrow tablets put the board in its own band above the human when the shared
side corridor is too narrow. Tablet compositions retain assigned opponent and
human avatars in both orientations. The
[current layout principles](ARCHITECTURE.md#gui-adapter) supersede older gallery
proportions and reference geometry.
Do not add a competing container or controller for those rectangles.

On Web, compare settled canvas and visual-viewport metrics as well as handling
resize events; late rotation metrics must replace the previous landscape height
without a page reload. Phone portrait winner stars share the stack row so long
winner names do not widen both columns at settlement. Phone-landscape hole
cards use the same lower-right allocation owner as tablet cards, with a reserved
marker band on unmarked seats too. Their short horizontal glyph layout does
not force community cards to use that same shape.

## Typography, input, and assets

Use the shared passive `BrandLogo.tscn` and transparent PNG on Start and under
the table content. Start uses the original logo on its dark background without
a light rectangle. The table's shader applies subtle alpha-derived relief;
branding may be obscured by game content and must not intercept input or
change layout minimums. No Start-screen scrolling is allowed: measured header
fit yields optional copy/logo allocation before essential controls, retaining
font/target floors and normal container geometry.

Shared compact/regular metric Themes apply to startup, table, keypad and overlay
roots. The reference table is retired. Fonts do not multiply by geometry
scale, and no recursive font repair is used. The current GUI permits seat copy
(names, stacks, markers and action/showdown band) to scale to 18 logical/CSS px;
card ranks and other GUI text retain 20 px, except event-log body text at
18 px (preview feedback, 2026-10-29). Log headings/actions still use 20 px.
Touch targets remain at least
48 × 48 logical pixels. Measure the complete seat footprint, including the
permanently reserved band beneath the visible panel. Winning hand/result
copy uses bold, bright yellow emphasis. Reflow when space is tight. Required content must pass text-fit
checks, including ellipsis and overlay text. Passing a matrix is evidence for
its fixtures, not proof that every device is clear. The ordinary numeric-bound
regressions supplement canonical layout coverage.

The replacement uses reusable action-button and input-field components.
Buttons, including Quit, have rounded corners, dark-green backgrounds and white
enabled text; disabled labels use grey (`#A8A8A8`).
Number/text fields have sharp corners, white backgrounds and dark-green
text. Keep this distinction through focus, disabled/read-only and error states,
including touch fields that open a keypad. RG-30/RG-39 implement these styles.
Total wager entry is the later user-approved exception: light-grey text on a
dark-green field, sharp corners, and a slightly shorter face vertically centered
beside Raise. Preserve its full 48 px interactive height; RG-11R4 draws a
40 px face inside that allocation through -4 px top/bottom StyleBox expansion.
Other fields retain the white/dark-text palette. Shared theme variations own
this distinction.
Total's latest text grey is `#B8C3BB`, slightly darker than the button labels.

The theme is `resources/gui_theme.tres`. Keep the plain non-serif face across
startup, table, keypad, and overlays. Avoid post-render scaling of desktop
text; adapt owned geometry and source font sizes instead.

Sixteen avatar PNGs have 64 × 64 source pixels. `GuiSeatContentRow` displays
assigned avatars at the upper left in full human/bot panels and tablet tokens,
targeting half the visual panel height while preserving aspect and sibling
content space. Intrinsic minima remain independent of allocation, so growth
does not prevent later shrinking. Older fixed display/gallery sizes are
historical samples; phone tokens omit avatars.
Resize/rotation must not reselect an avatar. Assignment is GUI-owned,
unique per tournament, and independent of game RNG. Physical output also
depends on DPR; source dimensions are not a browser display measurement.

Input follows event modality. Touch opens the in-canvas keypad; mouse/pointer
focus retains physical-keyboard editing even in a phone-sized desktop window.
Opening and draft edits preserve the original field text, including invalid,
blank and whitespace input. Cancel/dismissal keeps it unchanged; only Done
commits. Startup and wager entry share this transaction behavior.

Keep keypad digits in three ordered columns (`1 2 3 / 4 5 6 / 7 8 9`) with
`0` directly below `8`, including compact landscape. Place utility controls
separately instead of changing digit columns. Preserve 48 px targets and draft
transactions. Docked event log, human panel and action area share both top and
bottom edges. Seat allocation also clears the curved felt border; a rectangle
inside the felt's bounding box can still intersect a rounded corner.
Replacement layouts contain at most two bot seats per horizontal row, except
the top row on small-phone landscape may contain three. The human occupies
a separate centered row with comparable proportions to bots. An odd
opponent count starts with one centered, equal-width seat above mirrored pairs,
subject to the short-landscape top-triple exception. Compact seats place
D/SB/BB at the upper right above lower-right hole cards. Cards scale toward
two-thirds of the visual seat box height, excluding the status band, while
preserving marker clearance, aspect and readable rank/suit ink. Tablet tokens
implement this through `GuiSeatCardsColumn`; the ratio is not a fixed pixel size.
Preserve clockwise seat identities and complete status footprints. Reference
paths with four-seat bands were retired in RG-54 and are historical defects.
The accepted compact side-by-side keypad is landscape-only; portrait stacks
utilities below digits even if a future theme's minima could fit them beside.

Keypad utility buttons form an aligned rectangle with uniform cells in both
orientations and entry modes. Preserve the approved digit grid and explicit
wager limits. Cancel discards the draft, Done commits the draft for adapter validation. Tournament
Quit is outside number entry; cancel/close the keypad and use table/menu Quit.

## Phone composition and acceptance

Phone startup supports 2–7 players, defaults to 6, and may recommend 4.
Treat seven-player phone fit in both orientations as an early design stress
case, preserving readability and 48×48 action targets. Tablet/desktop layouts
must also verify nine players; phone geometry is not a scaled desktop layout.
Tablet, small-desktop, desktop, CLI, and core retain 2–9 support. Never clamp
an active tournament when its viewport changes. Choose content density and composition from measured fit rather than fixed
player-count tiers. Touch input selects keypad entry independently.

Keep supported chip totals exact, including accumulated stacks up to seven
million on phones. Numeric overflow reflows portrait tokens and the center
rather than shrinking seat copy below 18 px or other text below 20 px; ordinary values restore compact rows.
Expose Min and Pot directly when the complete measured action/table budget
fits them; keyboard/keypad choice must not hide otherwise fitting presets.
Keep a reachable wager-entry fallback on smaller allocations. See the
[implemented numeric layout contract](ARCHITECTURE.md).

Retain each seat's assigned name, numeric stack, role/state, two card fields,
and latest public action within the owned token regions. More/detail and
summary overlays expose recipient-safe details. Completed hands keep recipient-safe winning descriptions in the reserved
seat bands. More / Pots opens the menu, where Pots / Summary exposes exact
award details. Keep revealed cards visible through the completed-hand pause.
The retired reference phone's direct Pots behavior is historical. The
replacement provides a reachable Log action/menu whenever its dock is hidden,
including phones and completed-hand states. Docked and overlay log views share
one recipient-safe history model. One table overlay is
active at a time. Modal input blocks underlying actions, focus stays inside,
and advancement waits until the overlay closes. Close/Cancel remains reachable;
tournament Quit is reached outside number entry, after cancelling/closing the
keypad. See the [modal contract](ARCHITECTURE.md#gui-adapter) for focus,
Escape, engine-back and browser-history distinctions.

On supported phone browsers, a valid Start gesture requests document
fullscreen. **More / Pots → Fullscreen** retries after browser exit. Do not
require fullscreen to start a tournament or force orientation; browser refusal
leaves normal browser play available subject to measured fit. Verify actual
browser usable geometry, fullscreen exit/re-entry, and state/draft preservation.

Run `make check gui-current-invariant-gate` after layout changes and review
rendered captures under the visual testing contract. Historical physical acceptance
evidence remains in the archived [phone review](arkiv/OptimizingPhoneGuiTasks.md); leave deferred
landscape tasks unchecked. Historical iPad sign-off, incomplete desktop
measurements, and accepted LAN resolution limitations remain separate records
linked by the current documentation index.


Replacement card proportions follow the 2026-10-29 review: actual card width/
height is at least 5:7 or wider. Prevent a containing row from stretching cards
vertically into a narrow strip. Face/back/empty slots share their allocation.
Value and suit have comparable visual size; maximize the fitting font inside
positive content padding, including rank `10` and all suits. Keep both at least
20 logical/CSS px and use the built-in default font. RG-40 owns the reusable
implementation; theme-gallery measurements are preview evidence only.


The latest RG-30 review requires fully grayscale folded surfaces, including
avatars/text/borders; reuse the authored grayscale shader/material and preserve
its descendant inheritance. The new acting border is six pixels, stronger than
the reference layout's three-pixel treatment. The historical gallery preference
for a more prominent human identity does not permit a wide human strip: the
current table rule requires a centered human with proportions comparable to bots. Card glyph fitting must consider visible ink rather than unused
line leading: scale size with container space, keep positive padding and the
20 px text floor, and preserve 5:7-or-wider actual allocations. The gallery's
403×112 human face and 90/91 px card samples illustrate this preference; RG-40/41
implement the responsive reusable components.
