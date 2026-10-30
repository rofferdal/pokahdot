# Responsive GUI implementation guidance

This guide describes the current Godot GUI and its scene/container design in
[`RestructureGuiTasks.md`](RestructureGuiTasks.md). The
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
same geometry snapshot. `GuiPhoneLayoutPlan` and `GuiPhoneSeatLayout` supply
current phone geometry; preserve tournament state and core seat IDs on resize.
Do not add a competing container or controller for those rectangles.

## Typography, input, and assets

Use the shared passive `BrandLogo.tscn` and transparent PNG on Start and under
the table content. Start uses the original logo on its dark background without
a light rectangle. The table's shader applies subtle alpha-derived relief;
branding may be obscured by game content and must not intercept input or
change layout minimums. No Start-screen scrolling is allowed: measured header
fit yields optional copy/logo allocation before essential controls, retaining
font/target floors and normal container geometry.

RG-31 applies shared compact/regular metric Themes to reference startup/table/
keypad roots and replacement compositions. Fonts do not multiply by geometry
scale, and no recursive font repair is used. Both paths permit seat copy
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
enabled text; disabled labels use grey (`#A8A8A8` in the current candidate).
Number/text fields have sharp corners, white backgrounds and dark-green
text. Keep this distinction through focus, disabled/read-only and error states,
including touch fields that open a keypad. RG-30/RG-39 implement these styles.
Total wager entry is the later user-approved exception: light-grey text on a
dark-green field, sharp corners, and a slightly shorter face vertically centered
beside Raise. Preserve its full 48 px interactive height; RG-11R4 draws a
40 px face inside that allocation through -4 px top/bottom StyleBox expansion.
Other fields retain the white/dark-text palette. Future theme variations own
this distinction rather than global field recoloring.
Total's latest text grey is `#B8C3BB`, slightly darker than the button labels.

The theme is `resources/gui_theme.tres`. Keep the plain non-serif face across
startup, table, keypad, and overlays. Avoid post-render scaling of desktop
text; adapt owned geometry and source font sizes instead.

Sixteen avatar PNGs have 64 × 64 source pixels. Full seat panel base display
regions are 112 × 112 logical pixels for opponents and 128 × 128 for the human,
with layout adaptation; phone tokens omit avatars. These are reference sizes;
replacement larger-screen seat surfaces must display their assigned avatar
using measured aspect-preserving allocation (the theme gallery uses 64×64).
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
Replacement layouts contain no more than three player seats in any horizontal
row, on every screen and orientation. Phone portrait has the stricter maximum
of two opponent seats per row, including short portrait screens. An odd
opponent count starts with one centered, equal-width seat above paired rows.
Preserve clockwise seat identities;
some existing small-desktop/nine-seat reference paths still violate this new
contract. RG-12 defines capped rows; RG-42/50–52 must allocate them in the
replacement compositions.
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
an active tournament when its viewport changes. Phone densities are standard
for 2–4, compact for 5–6, and minimal for 7 players.

Keep supported chip totals exact, including accumulated stacks up to seven
million on phones. Numeric overflow reflows portrait tokens and the center
rather than shrinking text below 20 px; ordinary values restore compact rows.
Compact larger layouts keep Min/Pot presets visible and open free wager entry
through the keypad when large values need the action space. See the
[implemented numeric layout contract](ARCHITECTURE.md).

Retain each seat's assigned name, numeric stack, role/state, two card fields,
and latest public action within the owned token regions. More/detail and
summary overlays expose recipient-safe details. Completed phone hands name all
pot winners in the existing status region; Pots opens exact award details
without navigating More. Keep the revealed cards visible and return the button
to More on the next hand. The reference phone omits event history; the
replacement provides a reachable Log action/menu whenever its dock is hidden,
including phones and completed-hand states. Docked and overlay log views share
one recipient-safe history model. One table overlay is
active at a time. Modal input blocks underlying actions, focus stays inside,
and advancement waits until the overlay closes. Close/Cancel remains reachable;
tournament Quit is reached outside number entry, after cancelling/closing the
keypad. See the [modal contract](ARCHITECTURE.md#gui-adapter) for focus,
Escape, engine-back and browser-history distinctions.

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
the reference layout's three-pixel treatment. Wide human seats should receive
more reading space and larger identity copy/avatar than bot seats where measured
fit permits. Card glyph fitting must consider visible ink rather than unused
line leading: scale size with container space, keep positive padding and the
20 px text floor, and preserve 5:7-or-wider actual allocations. The gallery's
403×112 human face and 90/91 px card samples illustrate this preference; RG-40/41
implement the responsive reusable components.
