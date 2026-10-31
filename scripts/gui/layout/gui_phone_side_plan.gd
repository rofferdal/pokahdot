class_name GuiPhoneSidePlan
extends RefCounted


## Only short phone landscape may substitute a top triple for apex plus pair.
static func resolve(
	ids: PackedInt32Array,
	hero: int,
	minima: Dictionary[int, Vector2],
	board: Vector2,
	actions: Vector2,
	available: Vector2,
	gap: float
) -> GuiPhoneLandscapePlan:
	return GuiPhoneLandscapePlan._symmetric(
		ids, hero, minima, board, actions, available, gap, 7, true
	)
