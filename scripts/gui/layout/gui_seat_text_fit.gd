class_name GuiSeatTextFit
extends RefCounted

## Bounded seat-copy measurement only. Cards and other text never use this
## exception; components retain their own geometry and interactive allocation.
enum Status { INVALID, TOO_SMALL, FIT }
const MAX_PREFERRED: int = 64

var status: Status = Status.INVALID
var font_size: int = 0
var minimum := Vector2.ZERO


static func resolve(
	runs: Array[GuiSeatTextRun],
	normal: Font,
	bold: Font,
	available: Vector2,
	preferred: int,
	gap: float = 0.0
) -> GuiSeatTextFit:
	var result := GuiSeatTextFit.new()
	if (
		runs.is_empty()
		or normal == null
		or bold == null
		or not available.is_finite()
		or available.x <= 0.0
		or available.y <= 0.0
		or preferred < GuiTypography.SEAT_FLOOR
		or preferred > MAX_PREFERRED
		or not is_finite(gap)
		or gap < 0.0
	):
		return result
	for run: GuiSeatTextRun in runs:
		if run == null:
			return result
	result.status = Status.TOO_SMALL
	for size: int in range(preferred, GuiTypography.SEAT_FLOOR - 1, -1):
		var minimum: Vector2 = measure(runs, normal, bold, size, gap)
		result.minimum = minimum
		if minimum.x <= available.x and minimum.y <= available.y:
			result.status = Status.FIT
			result.font_size = size
			return result
	return result


static func measure(
	runs: Array[GuiSeatTextRun], normal: Font, bold: Font, size: int, gap: float
) -> Vector2:
	var result := Vector2.ZERO
	for run: GuiSeatTextRun in runs:
		var font: Font = bold if run.emphasized else normal
		var extent: Vector2 = (
			font.get_multiline_string_size(run.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).ceil()
		)
		if run.text.is_empty():
			extent.y = ceilf(font.get_height(size))
		result.x = maxf(result.x, extent.x)
		result.y += extent.y
	result.y += maxf(0.0, (runs.size() - 1) * gap)
	return result
