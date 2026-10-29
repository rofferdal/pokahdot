class_name GuiFitMetrics
extends RefCounted

## Detached measurements for one finite density/action-flow candidate.
## Callers measure complete Controls, including blank status bands and copy.
## No device dimensions, text scaling or inferred font sizes enter the solver.
var opponent := Vector2.ZERO
var board := Vector2.ZERO
var hero := Vector2.ZERO
var actions := Vector2.ZERO
var event_log := Vector2.ZERO
var gap: float = 0.0
var margin := Vector2.ZERO
var evidence: StringName = &"unmeasured"


func valid() -> bool:
	for minimum: Vector2 in [opponent, board, hero, actions]:
		if not minimum.is_finite() or minimum.x <= 0.0 or minimum.y <= 0.0:
			return false
	return (
		event_log.is_finite()
		and event_log.x >= 0.0
		and event_log.y >= 0.0
		and margin.is_finite()
		and margin.x >= 0.0
		and margin.y >= 0.0
		and is_finite(gap)
		and gap >= 0.0
		and evidence != &"unmeasured"
	)
