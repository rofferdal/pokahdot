class_name GuiFitPolicy
extends RefCounted

## Expected unsupported states are values; adapters present guidance and retain
## configuration/tournament state. Only fixture callers supply a mode override.
enum Status { NOT_READY, INVALID_INPUT, NEEDS_MEASUREMENTS, PHONE_CAPACITY, TOO_SMALL, FIT }

var status: Status = Status.NOT_READY
var size_class: GuiSizeClass
var selected: GuiFitCandidate
var guidance: String = "Waiting for available space."


static func resolve(
	geometry: GuiViewportGeometry,
	ids: PackedInt32Array,
	recipient: int,
	candidates: Array[GuiFitCandidate],
	fixture_override: int = GuiSizeClass.AUTOMATIC
) -> GuiFitPolicy:
	var result := GuiFitPolicy.new()
	result.size_class = GuiSizeClass.classify(Vector2.ZERO)
	if geometry == null or not geometry.valid:
		return result
	result.size_class = GuiSizeClass.classify(geometry.usable_rect.size, fixture_override)
	if not GuiSeatRows.compose(ids, recipient, false).valid:
		result.status = Status.INVALID_INPUT
		result.guidance = "Player seats are unavailable."
		return result
	if result.size_class.is_phone() and ids.size() > 7:
		result.status = Status.PHONE_CAPACITY
		result.guidance = (
			"Eight or nine players require a larger layout. "
			+ "Enlarge the window or use a larger screen."
		)
		return result
	result.status = Status.NEEDS_MEASUREMENTS
	result.guidance = "Waiting for component measurements."
	# Prefer the requested mode, but keep other fitting candidates. No feasible
	# composition is lost at a global breakpoint within the same orientation.
	for preferred: bool in [true, false]:
		for candidate: GuiFitCandidate in candidates:
			if not _eligible(candidate, ids, recipient):
				continue
			if (candidate.mode == result.size_class.mode) != preferred:
				continue
			if candidate.mode == GuiSizeClass.LayoutMode.PHONE and result.size_class.landscape:
				continue
			if (
				candidate.mode == GuiSizeClass.LayoutMode.PHONE_LANDSCAPE
				and not result.size_class.landscape
			):
				continue
			result.status = Status.TOO_SMALL
			result.guidance = "More space is needed. Enlarge the window or rotate the screen."
			if _contains(result.size_class.usable_size, candidate.minimum):
				result.status = Status.FIT
				result.selected = candidate
				result.guidance = ""
				return result
	return result


static func _eligible(candidate: GuiFitCandidate, ids: PackedInt32Array, recipient: int) -> bool:
	if candidate == null or not candidate.valid or candidate.seats == null:
		return false
	var expected: GuiSeatRows = GuiSeatRows.compose(
		ids,
		recipient,
		candidate.mode in [GuiSizeClass.LayoutMode.PHONE, GuiSizeClass.LayoutMode.PHONE_LANDSCAPE]
	)
	return expected.valid and candidate.seats.clockwise_ids == expected.clockwise_ids


static func _contains(available: Vector2, minimum: Vector2) -> bool:
	return available.x >= minimum.x and available.y >= minimum.y
