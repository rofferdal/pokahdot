class_name GuiHeroActionSummary
extends PanelContainer


func render(model: SeatViewModel) -> void:
	if model == null or not model.valid or model.cards == null:
		for path: String in [
			"Body/Copy/Identity/Name", "Body/Copy/Identity/Stack", "Body/Copy/Wager"
		]:
			(get_node(path) as Label).text = ""
		(get_node("Body/Cards") as GuiHoleCards).render(CardRowViewModel.new())
		return
	(get_node("Body/Copy/Identity/Name") as Label).text = model.display_name
	(get_node("Body/Copy/Identity/Stack") as Label).text = model.stack_value_text
	(get_node("Body/Copy/Wager") as Label).text = model.wager_text
	(get_node("Body/Cards") as GuiHoleCards).render(model.cards)
