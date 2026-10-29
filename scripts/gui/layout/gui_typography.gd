class_name GuiTypography
extends RefCounted

## Metric layers inherit the approved palette from the composition host.
## Selected content density owns this choice; geometry is never reclassified.
const Compact := preload("res://resources/gui_typography_compact.tres")
const Regular := preload("res://resources/gui_typography_regular.tres")
const SEAT_FLOOR: int = 18
const TEXT_FLOOR: int = 20
const TOUCH_FLOOR: int = 48


static func for_density(density: GuiFitCandidate.Density) -> Theme:
	return Regular if density == GuiFitCandidate.Density.FULL else Compact
