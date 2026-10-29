class_name CenterViewModel
extends RefCounted

## Detached board, pot and blind-level copy; layout decides its local allocation.
var valid: bool = false
var error: String = ""
var board: CardRowViewModel
var board_title: String = "Community cards"
var pot_text: String = ""
var phone_pot_text: String = ""
var wager_text: String = ""
var phone_wager_text: String = ""
var blind_level_text: String = ""
var large_values: bool = false
var wager_count: int = 0
var current_wager: int = 0


static func build(
	view: GameView, _density: GuiFitCandidate.Density = GuiFitCandidate.Density.FULL
) -> CenterViewModel:
	var result := CenterViewModel.new()
	if view == null:
		result.error = "A center model requires a recipient-safe view."
		return result
	result.valid = true
	result.board = CardRowViewModel.board(view)
	result.large_values = uses_large_values(view)
	for player: PlayerView in view.seats:
		result.current_wager = maxi(result.current_wager, player.bet_this_round)
		if player.bet_this_round > 0:
			result.wager_count += 1
	result.pot_text = (
		(
			"Pot: %d | L%d\nSB %d BB %d"
			% [view.pot_amount, view.blind_level, view.small_blind, view.big_blind]
		)
		if result.large_values
		else (
			"Pot: %d | SB %d BB %d | L%d"
			% [view.pot_amount, view.small_blind, view.big_blind, view.blind_level]
		)
	)
	result.phone_pot_text = "Pot: %d" % view.pot_amount
	result.wager_text = "Wagers  •  %d active" % result.wager_count
	result.phone_wager_text = "Current wager: %d" % result.current_wager
	result.blind_level_text = (
		"Blinds %d / %d  ·  Level %d  ·  %d hands to next level"
		% [view.small_blind, view.big_blind, view.blind_level, view.hands_until_next_level]
	)
	return result


static func uses_large_values(view: GameView) -> bool:
	if view == null:
		return false
	if view.pot_amount >= 1000000 or view.big_blind >= 100000:
		return true
	for player: PlayerView in view.seats:
		if player.stack >= 100000 or player.bet_this_round >= 100000:
			return true
	return false
