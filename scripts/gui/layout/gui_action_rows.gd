class_name GuiActionRows
extends RefCounted

## Contiguous one/two-row packing over complete measured action units.
var valid: bool = false
var minimum_width: float = 0.0
var reserved_height: float = 0.0
var split: int = 0
var row_count: int = 0


static func resolve(
	widths: Array[float], heights: Array[float], available: float, gap: float = 4.0
) -> GuiActionRows:
	var result := GuiActionRows.new()
	if (
		widths.is_empty()
		or widths.size() != heights.size()
		or not is_finite(available)
		or available <= 0.0
		or not is_finite(gap)
		or gap < 0.0
	):
		return result
	var total: float = 0.0
	var maximum_height: float = 48.0
	for index: int in widths.size():
		if (
			not is_finite(widths[index])
			or widths[index] <= 0.0
			or not is_finite(heights[index])
			or heights[index] <= 0.0
		):
			return result
		total += widths[index] + (gap if index > 0 else 0.0)
		maximum_height = maxf(maximum_height, heights[index])
	result.reserved_height = maximum_height * 2.0 + gap
	result.minimum_width = total
	result.split = widths.size()
	var prefix: float = 0.0
	for index: int in range(1, widths.size()):
		prefix += widths[index - 1] + (gap if index > 1 else 0.0)
		var suffix: float = total - prefix - gap
		var required: float = maxf(prefix, suffix)
		if required < result.minimum_width:
			result.minimum_width = required
			result.split = index
	result.valid = result.minimum_width <= available
	result.row_count = 1 if total <= available else 2
	if result.row_count == 1:
		result.split = widths.size()
	return result
