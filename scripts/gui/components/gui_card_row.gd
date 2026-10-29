class_name GuiCardRow
extends BoxContainer

const CardScene := preload("res://scenes/gui/components/PlayingCard.tscn")
var cards: Array[GuiPlayingCard] = []


func render(model: CardRowViewModel) -> void:
	if model == null:
		push_error("CardRow requires a presentation model.")
		model = CardRowViewModel.new()
	while cards.size() > model.cards.size():
		var old: GuiPlayingCard = cards.pop_back()
		remove_child(old)
		old.queue_free()
	while cards.size() < model.cards.size():
		var card: GuiPlayingCard = CardScene.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(card)
		cards.append(card)
	for index: int in cards.size():
		cards[index].render(model.cards[index])
