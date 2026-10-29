class_name GuiCardFace
extends PanelContainer


func render(model: CardViewModel) -> void:
	(get_node("Glyphs") as GuiCardGlyphs).render(model)
