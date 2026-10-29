class_name GuiPlayingCard
extends AspectRatioContainer

var _state: CardViewModel.State = CardViewModel.State.EMPTY


func render(model: CardViewModel) -> void:
	if model == null:
		push_error("PlayingCard requires a presentation model.")
		model = CardViewModel.empty()
	_state = model.state
	var face: GuiCardFace = get_node("Face")
	var back: GuiCardBack = get_node("Back")
	face.render(model if _state == CardViewModel.State.FACE else CardViewModel.empty())
	back.render(CardViewModel.back())
	face.visible = _state == CardViewModel.State.FACE
	back.visible = _state == CardViewModel.State.BACK
	get_node("Empty").visible = _state == CardViewModel.State.EMPTY
	tooltip_text = ""
	accessibility_name = (
		model.rank_text + model.suit_text
		if _state == CardViewModel.State.FACE
		else ("Hidden card" if _state == CardViewModel.State.BACK else "Empty card slot")
	)
	_update_slot_minimum()


func _ready() -> void:
	_update_slot_minimum()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_update_slot_minimum()


func _update_slot_minimum() -> void:
	custom_minimum_size = _minimum_card_size()
	for path: String in ["Face", "Back", "Empty"]:
		var surface := get_node_or_null(path) as Control
		if surface != null:
			surface.custom_minimum_size = custom_minimum_size


func _minimum_card_size() -> Vector2:
	var content: Vector2 = GuiCardInk.minimum_content(
		get_theme_font("font", &"CardRank"), get_theme_constant("glyph_separation", &"CardGlyphs")
	)
	var minimum: Vector2 = content + get_theme_stylebox("panel", &"CardFace").get_minimum_size()
	var width: float = ceilf(maxf(minimum.x, minimum.y * ratio))
	return Vector2(width, ceilf(width / ratio))


func get_card_snapshot(
	root: Control, role: StringName, authorized: bool = false
) -> GuiCardSnapshot:
	var result := GuiCardSnapshot.new()
	# Enum values differ between the detached presentation and snapshot contracts.
	match _state:
		CardViewModel.State.FACE:
			result.kind = GuiCardSnapshot.Kind.FACE
		CardViewModel.State.BACK:
			result.kind = GuiCardSnapshot.Kind.BACK
		_:
			result.kind = GuiCardSnapshot.Kind.EMPTY
	result.authorized = authorized
	var surface: Control = get_node(
		(
			"Face"
			if _state == CardViewModel.State.FACE
			else ("Back" if _state == CardViewModel.State.BACK else "Empty")
		)
	)
	result.element = GuiSnapshotMeasurement.element(surface, root, role, not authorized)
	result.rank = GuiLayoutElement.new()
	result.suit = GuiLayoutElement.new()
	if _state == CardViewModel.State.FACE:
		var glyphs: GuiCardGlyphs = get_node("Face/Glyphs")
		var fields: Array[GuiLayoutElement] = glyphs.get_layout_elements(root, role, not authorized)
		if fields.size() == 2:
			result.rank = fields[0]
			result.suit = fields[1]
	return result
