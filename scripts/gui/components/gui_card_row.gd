class_name GuiCardRow
extends BoxContainer

## Active cards are selected from fixed scene-owned board or hole-card slots.
var cards: Array[GuiPlayingCard] = []
var _slots: Array[GuiPlayingCard] = []


func render(model: CardRowViewModel) -> void:
	if _slots.is_empty():
		for child: Node in get_children():
			if child is GuiPlayingCard:
				_slots.append(child as GuiPlayingCard)
	if model == null:
		push_error("CardRow requires a presentation model.")
		model = CardRowViewModel.new()
	if model.cards.size() > _slots.size():
		push_error("CardRow model exceeds its authored slot capacity.")
		model = CardRowViewModel.new()
	cards.clear()
	for index: int in _slots.size():
		var card: GuiPlayingCard = _slots[index]
		if index < model.cards.size():
			card.render(model.cards[index])
			card.show()
			cards.append(card)
		else:
			card.render(CardViewModel.empty())
			card.hide()
