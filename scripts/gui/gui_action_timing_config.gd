class_name GuiActionTimingConfig
extends Resource

## Presentation-only pacing after a rendered player action.

@export_range(0.0, 10.0, 0.1, "suffix:s") var default_pause_seconds: float = 2.0
@export var pause_seconds_by_seat: Dictionary[int, float] = {}
@export_range(0.0, 10.0, 0.1, "suffix:s") var showdown_pause_seconds: float = 5.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var phone_action_badge_seconds: float = 2.0


func pause_for_seat(seat: int) -> float:
	var configured_pause: float = pause_seconds_by_seat.get(seat, default_pause_seconds)
	return maxf(0.0, configured_pause)


func showdown_pause() -> float:
	return maxf(0.0, showdown_pause_seconds)


func phone_action_badge_duration() -> float:
	return maxf(0.0, phone_action_badge_seconds)
