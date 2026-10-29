class_name GuiSizeClass
extends RefCounted

## Preferred composition only. Fit is independently resolved from content minima.
enum Width { NARROW, MEDIUM, EXPANDED }
enum Height { SHORT, MEDIUM, TALL }
enum LayoutMode { NOT_READY, PHONE, PHONE_LANDSCAPE, WIDE_COMPACT, WIDE }

const AUTOMATIC: int = -1
const MEDIUM_WIDTH: float = 600.0
const EXPANDED_WIDTH: float = 1100.0
const MEDIUM_HEIGHT: float = 600.0
const TALL_HEIGHT: float = 760.0

var ready: bool = false
var width_class: Width = Width.NARROW
var height_class: Height = Height.SHORT
var mode: LayoutMode = LayoutMode.NOT_READY
var usable_size := Vector2.ZERO
var landscape: bool = false


static func classify(size: Vector2, fixture_override: int = AUTOMATIC) -> GuiSizeClass:
	var result := GuiSizeClass.new()
	if not size.is_finite() or size.x <= 0.0 or size.y <= 0.0:
		return result
	result.ready = true
	result.usable_size = size
	result.landscape = size.x > size.y
	result.width_class = (
		Width.NARROW
		if size.x < MEDIUM_WIDTH
		else Width.MEDIUM if size.x < EXPANDED_WIDTH else Width.EXPANDED
	)
	result.height_class = (
		Height.SHORT
		if size.y < MEDIUM_HEIGHT
		else Height.MEDIUM if size.y < TALL_HEIGHT else Height.TALL
	)
	if fixture_override >= LayoutMode.PHONE and fixture_override <= LayoutMode.WIDE:
		result.mode = fixture_override
	elif result.landscape and result.height_class == Height.SHORT:
		result.mode = LayoutMode.PHONE_LANDSCAPE
	elif result.width_class == Width.NARROW:
		result.mode = LayoutMode.PHONE
	elif result.width_class == Width.MEDIUM or result.height_class != Height.TALL:
		result.mode = LayoutMode.WIDE_COMPACT
	else:
		result.mode = LayoutMode.WIDE
	return result


func is_phone() -> bool:
	return mode == LayoutMode.PHONE or mode == LayoutMode.PHONE_LANDSCAPE
