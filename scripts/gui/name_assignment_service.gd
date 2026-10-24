class_name NameAssignmentService
extends RefCounted

## Assigns tournament-local GUI labels without mutating core player identity.

const RNG_STREAM_ID := "gui_names"
const HUMAN_LABEL := "Human"
const MIN_PLAYER_COUNT := 2
const MAX_PLAYER_COUNT := 9

var _catalog: GuiNameCatalog


func _init(catalog: GuiNameCatalog = null) -> void:
	_catalog = GuiNameCatalog.new() if catalog == null else catalog


func assign_for_tournament(
	seat_count: int,
	human_seat: int,
	rng: RandomNumberGenerator,
) -> NameAssignmentResult:
	var validation_error: String = _catalog.validation_error()
	if not validation_error.is_empty():
		return NameAssignmentResult.new({}, validation_error)
	if seat_count < MIN_PLAYER_COUNT or seat_count > MAX_PLAYER_COUNT:
		return (
			NameAssignmentResult
			. new(
				{},
				"GUI name assignment requires between 2 and 9 seats; received %d." % seat_count,
			)
		)
	if human_seat < 0 or human_seat >= seat_count:
		return (
			NameAssignmentResult
			. new(
				{},
				"Human seat %d is outside the %d-seat table." % [human_seat, seat_count],
			)
		)
	if rng == null:
		return NameAssignmentResult.new({}, "The gui_names RNG stream is required.")

	var shuffled_names: Array[String] = []
	for display_name: String in _catalog.get_names():
		shuffled_names.append(display_name)
	for index: int in range(shuffled_names.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var swap_value: String = shuffled_names[index]
		shuffled_names[index] = shuffled_names[swap_index]
		shuffled_names[swap_index] = swap_value

	var assignments: Dictionary[int, String] = {}
	var name_index: int = 0
	for seat: int in range(seat_count):
		if seat == human_seat:
			assignments[seat] = HUMAN_LABEL
			continue
		assignments[seat] = shuffled_names[name_index]
		name_index += 1
	return NameAssignmentResult.new(assignments)
