class_name TableViewModel
extends RefCounted

## Detached recipient presentation. State lifetime and input submission stay in
## the adapter; this model contains no nodes, CardData or retained GameView.
var valid: bool = false
var error: String = ""
var density: GuiFitCandidate.Density = GuiFitCandidate.Density.FULL
var hero_seat: int = Table.NO_SEAT
var seats: Array[SeatViewModel] = []
var center: CenterViewModel
var actions: ActionBarViewModel
var summary: HandSummaryViewModel
var history: EventLogViewModel
var _by_id: Dictionary[int, SeatViewModel] = {}


static func build(
	view: GameView,
	names: Dictionary[int, String],
	avatars: Dictionary[int, String],
	latest_actions: Dictionary[int, PublicActionRecord],
	retained_folds: Dictionary[int, PublicActionRecord],
	event_lines: Array[String],
	copy_density: GuiFitCandidate.Density = GuiFitCandidate.Density.FULL
) -> TableViewModel:
	var result := TableViewModel.new()
	result.density = copy_density
	if view == null:
		result.error = "A table model requires a recipient-safe view."
		return result
	if copy_density not in GuiFitCandidate.Density.values():
		result.error = "A table model requires a supported copy density."
		return result
	result.hero_seat = view.hero_seat
	for player: PlayerView in view.seats:
		if player == null:
			result.error = "A table model requires public player values."
			return result
		if result._by_id.has(player.seat):
			result.error = "A table model requires unique seat IDs."
			return result
		var seat: SeatViewModel = SeatViewModel.build(
			player,
			view,
			names,
			avatars,
			latest_actions.get(player.seat),
			retained_folds.get(player.seat),
			copy_density
		)
		result.seats.append(seat)
		result._by_id[player.seat] = seat
	if not result._by_id.has(view.hero_seat):
		result.error = "A table model requires the recipient seat."
		return result
	result.center = CenterViewModel.build(view, copy_density)
	result.actions = ActionBarViewModel.build(view, names, copy_density)
	result.summary = HandSummaryViewModel.build(view, names)
	result.history = EventLogViewModel.from_lines(event_lines)
	result.valid = true
	return result


func seat_for(id: int) -> SeatViewModel:
	return _by_id.get(id)
