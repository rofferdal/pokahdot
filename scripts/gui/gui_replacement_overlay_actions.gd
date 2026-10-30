class_name GuiReplacementOverlayActions
extends RefCounted

# Owns replacement table overlay interactions.
var detail_seat: int = -1
var detail_authorization: Array[bool] = []


func open_number(
	overlay: GuiOverlayHost, fallback: Control, actions: ActionBarViewModel, value: String
) -> void:
	var model := NumberEntryViewModel.new()
	model.title = actions.wager_text + " total"
	model.value = value
	model.minimum = actions.minimum_total
	model.maximum = actions.maximum_total
	model.show_presets = true
	model.minimum_preset = str(actions.minimum_total)
	model.pot_preset = str(actions.pot_total)
	model.pot_display_value = str(actions.pot_contribution)
	model.pot_enabled = actions.pot_enabled
	overlay.set_fallback_focus(fallback)
	overlay.open_number(model)


func render_detail(overlay: GuiOverlayHost, model: SeatViewModel) -> void:
	detail_authorization.clear()
	for card: CardViewModel in model.cards.cards:
		detail_authorization.append(card != null and card.state == CardViewModel.State.FACE)
	overlay.open_seat(model)
