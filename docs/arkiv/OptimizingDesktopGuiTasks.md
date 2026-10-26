# Optimizing the Desktop GUI

Status: Active — new browser typography cropping requires remediation; exact browser evidence and visual acceptance remain
Evidence baseline: desktop-browser screenshots supplied by the user on 2026-10-25 and 2026-10-26

## Scope

This backlog records desktop-browser presentation defects separately from the
active phone work. The user resumed desktop GUI work on 2026-10-26. Desktop
changes must retain the phone composition, recipient privacy, poker behavior,
and tournament state.

The supplied image is a 1853 x 916 raster of a six-player preflop human turn.
It does not show browser chrome, so its raster dimensions must not yet be treated
as the measured CSS viewport. The deployed commit, browser/OS versions, browser
zoom, device-pixel ratio, and canvas dimensions have not been recorded.

The follow-up `desktop01.png` evidence is a 1489 x 912 raster of a six-player
turn state. Several opponent and human stack lines lose the final `s` in
`chips`, while the action controls are crowded and their labels sit close to
the button edges. `Quit` is no longer covering the human seat, but its text is
oversized relative to its reserved control. This raster also lacks the CSS
viewport and browser measurements needed for an exact fixture.

## Screenshot assessment

Verdict: **desktop remediation required**. The overall table is recognizable
and most required information is present, but a primary command obscures the
human identity region and violates the documented non-overlap contract.

| Area | Observation | Assessment |
| --- | --- | --- |
| Human seat and Quit | `Quit` is drawn across the upper edge of the human panel and covers the `Human` name. | Blocker: unintended control/content overlap and lost identity text. |
| Human acting state | The thick white frame identifies the acting human, and the cards, stack, blind marker, and status band are present. | Partly passes; the obscured name prevents acceptance. |
| Action panel | Legal actions are reachable, but seven controls are tightly packed into two rows with very small gaps and weak primary/secondary hierarchy. | Needs focused readability and interaction review at the measured viewport. |
| Seat status bands | Actions such as `Raise 20`, `Fold`, and `Big blind 10` appear below their seats, but some look visually detached because the reserved band has no visible association with its panel. Folded-state text also has weak contrast. | Needs ownership, alignment, and contrast verification before changing styling. |
| Center information | Community-card slots, pot/blind level, and wager/active-player information remain visible and separated. Empty preflop card marks are extremely dark against their slots. | Geometry mostly passes; placeholder contrast/meaning needs review. |
| Event history | The non-phone event log is present and readable, as required for larger layouts. Its last visible row sits against the lower boundary and the scrollbar is visually dominant. | Preserve the log, but verify padding, clipping, and scroll behavior. |
| Opponent seats | Names, stacks, avatars, markers, hidden cards, and fold treatment are present without obvious panel intersections. | No blocker visible in this one state; broader player-count/state coverage is still required. |

## Tasks

- [x] **Give desktop Quit an owned, continuously available rectangle.** Place
  the standalone desktop Quit control in a reserved region managed by the same
  layout pass as the center, event log, human seat, action panel, and status
  bands. Keep confirmation behavior and core quit semantics unchanged.
  Acceptance: Quit remains visible and operable without covering any table
  content at desktop and small-desktop viewports.
- [x] **Restore an unobstructed human identity region.** Keep the full `Human`
  label, numeric stack, position marker, private cards, acting frame, and status
  band readable at once. Do not reduce player-facing text below 20 px.
  Acceptance: long bot names and the human label pass clipping and intersection
  assertions through ordinary, folded, all-in, showdown, and winner states.
- [x] **Review and improve desktop action-control composition.** Verify every
  legal-action combination, free-entry wager field, disabled state, focus ring,
  and pointer/keyboard path. Reflow or space controls where needed so labels do
  not crowd borders and primary decisions remain visually distinct. Acceptance:
  no text wraps or clips, controls do not intersect, disabled controls remain
  understandable, and every legal action is reachable.
- [x] **Strengthen seat-owned status presentation.** Verify that every latest
  action, durable `Fold`, showdown summary, and `Winner` result is clearly
  associated with the correct fixed seat footprint. Correct alignment or
  contrast without moving seat/status rectangles between states. Acceptance:
  status ownership is unambiguous and folded text remains readable.
- [x] **Review center placeholders and event-log boundaries.** Decide whether
  unrevealed community slots should be blank or use a deliberately legible
  neutral placeholder, then verify event-log padding, final-row visibility,
  scrollbar behavior, and recipient-safe content. Acceptance: these regions
  are clear without competing with current-decision information.

## Automated verification — 2026-10-26

- `make check`: 514/514 GUT tests and 17,304 assertions; 72 Python tests;
  GDScript lint and formatting pass.
- Historical, phone, iPad, and desktop invariant gates pass.
- The dedicated desktop gate is `make gui-desktop-invariant-gate`.
- Unchecked tasks still require exact hosted-browser measurements or user visual
  acceptance; the 1853 x 916 screenshot raster is not treated as CSS geometry.
