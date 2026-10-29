class_name CardRowViewModel
extends RefCounted

## Fixed slot rows copy only authorized rank/suit values, never core objects.
var cards: Array[CardViewModel] = []


static func board(view: GameView) -> CardRowViewModel:
	var result := CardRowViewModel.new()
	var visible_cards: Array[CardData] = []
	if view != null:
		visible_cards = view.community_cards
	for index: int in 5:
		result.cards.append(
			(
				CardViewModel.face(visible_cards[index])
				if index < visible_cards.size()
				else CardViewModel.empty()
			)
		)
	return result


static func for_seat(view: GameView, seat: int) -> CardRowViewModel:
	var result := CardRowViewModel.new()
	var player: PlayerView = null
	if view != null:
		for candidate: PlayerView in view.seats:
			if candidate.seat == seat:
				player = candidate
				break
	var empty_slots: bool = player == null or player.folded or player.busted
	var visible_cards: Array = []
	if not empty_slots:
		visible_cards = (
			view.hero_hole_cards
			if seat == view.hero_seat
			else view.revealed_hole_cards.get(seat, [])
		)
		if seat != view.hero_seat and visible_cards.size() != 2:
			visible_cards = []
	for index: int in 2:
		if empty_slots:
			result.cards.append(CardViewModel.empty())
		elif index < visible_cards.size():
			result.cards.append(CardViewModel.face(visible_cards[index] as CardData))
		elif seat == view.hero_seat:
			result.cards.append(CardViewModel.empty())
		else:
			result.cards.append(CardViewModel.back())
	return result
