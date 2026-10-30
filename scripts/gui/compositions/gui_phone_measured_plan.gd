class_name GuiPhoneMeasuredPlan
extends RefCounted


# Collects native component minima for the pure phone table planner.
static func resolve(
	seats: Dictionary[int, Control],
	hero: int,
	center: Control,
	actions: Control,
	landscape: bool,
	available: Vector2,
	gap: float
) -> GuiPhoneTablePlan:
	var ids := sorted_ids(seats)
	var minima: Dictionary[int, Vector2] = {}
	for id: int in seats:
		minima[id] = seats[id].get_combined_minimum_size()
	return GuiPhoneTablePlan.resolve(
		ids,
		hero,
		minima,
		center.get_combined_minimum_size(),
		actions.get_combined_minimum_size(),
		landscape,
		available,
		gap
	)


static func sorted_ids(seats: Dictionary[int, Control]) -> PackedInt32Array:
	var ids := PackedInt32Array(seats.keys())
	ids.sort()
	return ids
