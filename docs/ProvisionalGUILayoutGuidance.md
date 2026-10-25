# Godot GUI & Font Scaling: Best Practices Guide

This document summarizes best practices for creating responsive, accessible, and adaptive user interfaces in Godot across various device form factors (Desktop PCs, Tablets/iPads, and Phones).

---

## 1. Project-Wide Display & Stretch Setup

To prevent Godot from simply squishing or uniformly shrinking your UI into unreadable tiny elements on smaller screens, configure your Project Settings properly:

* **Stretch Mode:** `canvas_items`  
  Scales 2D Control layouts while respecting layout anchors and containers. It does not by itself guarantee crisp rendering; font and texture quality also depends on the viewport configuration and source assets.
* **Stretch Aspect:** `expand`  
  Provides extra screen real estate on wide desktop displays while cleanly adapting to square-ish iPad or tall phone aspect ratios without letterboxing or distortion.
* **Base Design Resolution:** Pick a standard baseline (e.g., `1280x720` or `1920x1080`) to design your default layouts around.

---

## 2. Layouts, Anchors & Touch Targets

### Prefer containers and anchors; allow one explicit layout owner

Use Godot's `Control` layout system by default:

* **Containers:** Rely on `VBoxContainer`, `HBoxContainer`, `GridContainer`,
  `MarginContainer`, and `PanelContainer` for ordinary structure.
* **Anchors and offsets:** Use anchor presets such as `Full Rect`, `Center`,
  and `Bottom Wide` so regions respond to viewport bounds.

Specialized table regions may require calculated rectangles. In that case,
document one layout owner that atomically assigns the parent region and all
child rectangles from the current viewport. Do not place those children under
a `Container` or let a second controller assign their bounds. Pokahdot's
central community-card/pot/wager region follows this exception; it is not a
general license for scattered hardcoded coordinates.

### Touch Target Minimums
Fingers on a mobile touchscreen require significantly larger touch targets than mouse cursors.
* Set `custom_minimum_size` on buttons and interactive UI elements.
* **Recommended Minimum Size:** At least **48x48 px** (or `160x50 px` for horizontal text buttons) on mobile devices to ensure reliable tapping.
* Increase spacing inside containers (`theme_override_constants/separation`) on mobile layouts to prevent accidental mis-taps.

---

## 3. Font Sizing Strategies

Godot uses **integer pixels (`px`)** for native font sizes. To simulate relative scaling (`em` units):

### A. Dynamic Font Scaling Script
Attach a script to your root UI node or custom scale manager to adjust font sizes proportionally based on current viewport width:

```gdscript
extends Control

@export var base_font_size: int = 20
@export var reference_width: float = 1280.0
@export var ui_theme: Theme

func _ready() -> void:
    get_viewport().size_changed.connect(_update_font_scaling)
    _update_font_scaling()

func _update_font_scaling() -> void:
    var current_width: float = get_viewport().get_visible_rect().size.x
    var scale_factor: float = clamp(current_width / reference_width, 1.0, 2.0)
    
    var scaled_size: int = int(base_font_size * scale_factor)
    ui_theme.set_default_font_size(scaled_size)
```

### B. Theme Management
* Prefer managing font sizes through a global `Theme` resource rather than per-label `Theme Overrides`.
* Define clear hierarchy tiers in your theme:
  * `Default / Body`: $1.0\times$ baseline (e.g., 20px)
  * `Sub-Header`: $1.5\times$ baseline (e.g., 30px)
  * `Header / Title`: $2.25\times$ baseline (e.g., 45px)

All player-facing text must remain at least 20 px at every supported viewport size. If a design needs to fit more content on a small screen, reflow or simplify the layout instead of reducing the font below this minimum.

---

## 4. Device Form-Factor Detection

Choose layout modes primarily from the visible viewport size and aspect ratio.
OS feature flags may supplement input or platform behavior, but must not be
the only mobile-layout signal: desktop windows can be phone-sized, and Web
canvases on mobile devices may expose large logical dimensions.

For the full-window Web export, distinguish the high-resolution canvas backing
store from CSS layout pixels. The Godot loader sizes the backing canvas from
the CSS window size multiplied by the device pixel ratio. Pokahdot's GUI
composition root converts `DisplayServer.window_get_size()` back to CSS-pixel
geometry with `DisplayServer.screen_get_scale()` and assigns it to the root
Window's `content_scale_size`. Keep the backing canvas high resolution; do not
classify its raw dimensions or disable HiDPI rendering to make a phone fit.

```gdscript
const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")

func get_layout_profile() -> GuiLayoutProfile.Kind:
    var usable_size: Vector2 = get_viewport().get_visible_rect().size
    return GuiLayoutProfileScript.classify(usable_size)
```

The shared classifier returns one of five profiles: phone portrait, phone
landscape, tablet, small desktop, or desktop. Pass geometry after safe-area and
browser-chrome reductions. Use an explicit profile override only for recorded
device evidence whose usable geometry is otherwise ambiguous.

Use `OS.has_feature("mobile")` separately only when a platform-specific input
or browser workaround is required. It does not override viewport classification.

---

## 5. Principles for Content Simplification on Small Screens

When scaling down to a phone viewport, space is at a premium. Rather than forcing desktop complexity onto a small screen, follow these progressive disclosure and simplification principles:

Phone startup has an explicit 2–7 participant limit while continuing to resolve
an omitted participant count to 6 on every device. A phone startup screen may
recommend 4 participants as non-binding guidance, but must not preselect or
silently substitute it. Counts 8–9 remain valid on tablet, small-desktop, and
desktop layouts. Preserve entered values and active tournament state across
profile changes, and explain that a larger layout is required. Use these
presentation tiers:

* **2–4 players:** standard phone density.
* **5–6 players:** compact phone density.
* **7 players:** minimal phone density.

The minimal tier must retain seven distinct, tappable seat identities around a
reserved center table region, with the human position anchored at the bottom.
Every bot token keeps the full assigned display name, numeric chip stack, and
two hole-card fields visible at once; short-lived action feedback may replace
only the compact state-badge cell. Additional details may move behind
deliberate interaction; the underlying seat identity and recipient-safe state
remain unchanged. Do not render event history as a phone field, drawer, menu
entry, or fixture. Preserve it in recipient-safe game state and retain the
existing event log on larger profiles.

Choose numeric input from the input event, not the layout profile. A touch
press opens the shared transactional in-canvas keypad on phone, tablet, or
desktop. A pointer click keeps the native field focused for physical-keyboard
digits and editing keys, including in a phone-sized desktop window. Canceling
a touch draft preserves the last committed field value.

### A. Progressive Disclosure
* **Collapse Sidebars into Modals/Drawers:** Replace fixed desktop sidebars or multi-column inspectors with slide-out hamburger menus or overlay drawers (`AcceptDialog` / `Window` / animated `Panel`).
* **Tabbed Navigation:** Convert complex multi-pane viewports into bottom tab bars (`TabBar` or `TabContainer`).

### B. Contextual Visibility Control
* **Hide Decorative Graphics:** Hide non-essential visual fluff (background decorations, secondary icon labels, descriptive subtext) using Godot's `.visible` property or custom visibility groups.
* **Icon-Only Buttons:** On phone viewports, toggle buttons to display icons only, reserving text labels for tablet and desktop viewports.

### C. Prioritize Primary Actions
* Limit the visible interface to **one primary call-to-action (CTA)** and a maximum of 2–3 secondary actions per screen.
* Move secondary commands or debugging shortcuts inside overflow menus (e.g., a "..." `OptionButton` or `PopupMenu`).

### D. Re-orient Layout Axis
* Dynamically switch container orientations:
  * Desktop / Tablet: `HBoxContainer` (horizontal split).
  * Phone: `VBoxContainer` (vertical stack) or scrolling container (`ScrollContainer`).
```gdscript
# Example layout re-orientation
if current_device == DeviceType.PHONE:
    $MainContainer.alignment = BoxContainer.ALIGNMENT_CENTER
    # Convert horizontal layout to vertical
```
