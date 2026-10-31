class_name GuiSeatPanel
extends VBoxContainer

## Complete passive seat footprint: panel plus permanently reserved status band.
const Grayscale := preload("res://resources/gui_grayscale_material.tres")
@export var hero_presentation: bool = false

var _seat: int = -1
var _folded: bool = false
var _busted: bool = false
var _fit_queued: bool = false
var _bound: bool = false
var _avatar_path: String = ""
var _status_emphasis: bool = false
var _last_preferred: int = 0
var _authorized_faces: Array[bool] = []
var _required_badge_text: String = ""


func _ready() -> void:
	_inherit_material(self)
	for path: String in ["%Name", "%Stack", "%Wager", "Status"]:
		(get_node(path) as Label).resized.connect(_queue_fit)
	_refresh_metrics()
	_queue_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_refresh_metrics()
		_queue_fit()
	elif what == NOTIFICATION_RESIZED:
		_queue_fit()


func render(model: SeatViewModel) -> void:
	if model == null or not model.valid:
		push_error("SeatPanel requires a valid presentation model.")
		_clear()
		return
	_bound = true
	_seat = model.seat
	_folded = model.folded
	_busted = model.busted
	_status_emphasis = model.winner_emphasis
	material = Grayscale if model.folded else null
	var panel: PanelContainer = get_node("Panel")
	panel.theme_type_variation = (
		&"SeatPanelFolded"
		if model.folded
		else (
			&"HeroPanelActing"
			if hero_presentation and model.acting
			else (
				&"SeatPanelActing"
				if model.acting
				else (&"HeroPanel" if hero_presentation else &"SeatPanel")
			)
		)
	)
	_reset_copy_fonts()
	(get_node("%Name") as Label).text = model.display_name
	var badge_parts: Array[String] = []
	if model.is_small_blind:
		badge_parts.append("SB")
	if model.is_big_blind:
		badge_parts.append("BB")
	_required_badge_text = " ".join(badge_parts)
	(get_node("%Stack") as Label).text = (
		model.stack_value_text
		if not hero_presentation and not model.stack_value_text.is_empty()
		else model.stack_text
	)
	(get_node("%Wager") as Label).text = model.wager_text
	(get_node("Status") as Label).text = model.status_text
	(get_node("Status") as Label).theme_type_variation = (
		(&"HeroWinningHandText" if hero_presentation else &"WinningHandText")
		if model.winner_emphasis
		else (&"HeroStatusBand" if hero_presentation else &"StatusBand")
	)
	_bind_avatar(model.avatar_path)
	_authorized_faces.clear()
	if model.cards != null:
		for card: CardViewModel in model.cards.cards:
			_authorized_faces.append(card != null and card.state == CardViewModel.State.FACE)
	(get_node("%Cards") as GuiHoleCards).render(model.cards)
	(get_node("%Dealer") as Control).modulate.a = (1.0 if model.is_dealer else 0.0)
	(get_node("%SB") as Label).visible = model.is_small_blind
	(get_node("%BB") as Label).visible = model.is_big_blind
	(get_node("%Dealer") as Control).visible = model.is_dealer
	(get_node("%SB").get_parent() as Control).visible = (model.is_small_blind or model.is_big_blind)
	(get_node("%Winner") as Control).modulate.a = (1.0 if model.winner_emphasis else 0.0)
	_refresh_metrics()
	_inherit_material(self)
	_queue_fit()


func _clear() -> void:
	_bound = false
	_authorized_faces.clear()
	_required_badge_text = ""
	_seat = -1
	_folded = false
	_busted = false
	_status_emphasis = false
	material = null
	for path: String in ["%Name", "%Stack", "%Wager", "Status"]:
		(get_node(path) as Label).text = ""
	_bind_avatar("")
	(get_node("%Cards") as GuiHoleCards).render(CardRowViewModel.new())
	(get_node("%Dealer") as Control).modulate.a = 0.0
	(get_node("%SB") as Label).visible = false
	(get_node("%BB") as Label).visible = false
	(get_node("%Dealer") as Control).visible = false
	(get_node("%SB").get_parent() as Control).visible = false
	(get_node("%Winner") as Control).modulate.a = 0.0
	(get_node("Panel") as PanelContainer).theme_type_variation = (
		&"HeroPanel" if hero_presentation else &"SeatPanel"
	)
	_refresh_metrics()


func _bind_avatar(path: String) -> void:
	var avatar: TextureRect = get_node("%Avatar")
	if path == _avatar_path and (path.is_empty() or avatar.texture != null):
		return
	_avatar_path = path
	avatar.texture = null
	if path.is_empty():
		return
	if not ResourceLoader.exists(path, "Texture2D"):
		push_error("SeatPanel avatar texture does not exist: %s" % path)
		return
	avatar.texture = load(path) as Texture2D
	if avatar.texture == null:
		push_error("SeatPanel avatar is not a texture: %s" % path)


func _preferred() -> int:
	var ancestor := get_parent() as Control
	var role: StringName = &"HeroText" if hero_presentation else &"SeatText"
	return maxi(18, (ancestor if ancestor != null else self).get_theme_font_size("font_size", role))


func _refresh_metrics() -> void:
	if _preferred() != _last_preferred:
		_last_preferred = _preferred()
		_reset_copy_fonts()
	var status: Label = get_node("Status")
	var normal: Font = get_theme_font("font", &"HeroText" if hero_presentation else &"SeatText")
	var bold: Font = get_theme_font("font", &"WinningHandText")
	var reserved: Vector2 = GuiSeatTextFit.measure(
		[GuiSeatTextRun.new(), GuiSeatTextRun.new("", true)],
		normal,
		bold,
		_preferred(),
		status.get_theme_constant("line_spacing")
	)
	# Model status may contain two explicit lines; blank and filled share this band.
	status.custom_minimum_size.y = reserved.y
	var body: GuiSeatContentRow = get_node("%Body")
	body.custom_minimum_size.y = (
		ceilf(normal.get_height(_preferred())) * 3.0
		+ 2.0 * (get_node("%Copy") as VBoxContainer).get_theme_constant("separation")
	)
	for path: String in ["%Name", "%Stack", "%Wager"]:
		(get_node(path) as Label).theme_type_variation = (
			&"HeroText" if hero_presentation else &"SeatText"
		)
	# Fixed name/star and amount groups reserve preferred theme metrics for
	# both presentations; fitting cannot latch a prior allocation's minimum.
	for path: String in ["%Name", "%Stack", "%Wager", "Status"]:
		var label: Label = get_node(path)
		label.custom_minimum_size.x = (
			GuiSeatTextFit
			. measure(
				[GuiSeatTextRun.new(label.text, path == "Status" and _status_emphasis)],
				normal,
				bold,
				18 if path == "Status" else _preferred(),
				0.0
			)
			. x
		)
	if not hero_presentation:
		var digits: int = maxi(0, get_theme_constant("amount_digits", &"SeatPanel"))
		var amount: String = "8".repeat(digits)
		for name: String in ["Stack", "Wager"]:
			var label: Label = get_node("%" + name)
			var reserve: String = "Bet " + amount if name == "Wager" else amount
			var reserve_width: float = (
				GuiSeatTextFit
				. measure([GuiSeatTextRun.new(reserve)], normal, bold, _preferred(), 0.0)
				. x
			)
			label.custom_minimum_size.x = maxf(label.custom_minimum_size.x, reserve_width)
	for name: String in ["Name", "Stack", "Wager"]:
		var label: Label = get_node("%" + name)
		label.custom_minimum_size.y = ceilf(normal.get_height(_preferred()))
	body.queue_sort()
	_queue_fit()


func _reset_copy_fonts() -> void:
	for path: String in ["%Name", "%Stack", "%Wager", "Status"]:
		(get_node(path) as Label).add_theme_font_size_override("font_size", 18)


func _queue_fit() -> void:
	if not _fit_queued and is_inside_tree():
		_fit_queued = true
		call_deferred("_fit_copy")


func _fit_copy() -> void:
	_fit_queued = false
	if not is_inside_tree() or not _bound:
		return
	var normal: Font = get_theme_font("font", &"HeroText" if hero_presentation else &"SeatText")
	var bold: Font = get_theme_font("font", &"WinningHandText")
	for path: String in ["%Name", "%Stack", "%Wager", "Status"]:
		var label: Label = get_node(path)
		var fit: GuiSeatTextFit = GuiSeatTextFit.resolve(
			[GuiSeatTextRun.new(label.text, path == "Status" and _status_emphasis)],
			normal,
			bold,
			label.size,
			_preferred()
		)
		if fit.status == GuiSeatTextFit.Status.FIT:
			if label.get_theme_font_size("font_size") != fit.font_size:
				label.add_theme_font_size_override("font_size", fit.font_size)


func get_field(role: StringName) -> Control:
	var names: Dictionary[StringName, String] = {
		&"name": "Name",
		&"stack": "Stack",
		&"action": "Wager",
		&"avatar": "Avatar",
		&"cards": "Cards",
		&"marker": "D",
		&"badge_row_2": "SB",
		&"badge_row_3": "BB",
		&"winner": "Winner",
		&"markers": "Markers",
		&"dealer": "Dealer",
		&"body": "Body",
		&"copy": "Copy",
		&"status": "Status"
	}
	return get_node("%" + names[role]) as Control if names.has(role) else null


func get_seat_snapshot(root: Control) -> GuiSeatSnapshot:
	var value := GuiSeatSnapshot.new()
	value.seat_id = _seat
	value.hero = hero_presentation
	value.folded = _folded
	value.busted = _busted
	value.face_authorized = _authorized_faces.has(true)
	value.required_badge_text = _required_badge_text
	value.panel = GuiSnapshotMeasurement.element(
		get_node("Panel"), root, StringName("seat/%d" % _seat)
	)
	value.status = GuiSnapshotMeasurement.element(
		get_node("Status"), root, StringName("status/%d" % _seat)
	)
	value.footprint = GuiSnapshotMeasurement.rect(self, root)
	var paths: Dictionary[StringName, String] = {
		&"name": "%Name",
		&"stack": "%Stack",
		&"action": "%Wager",
		&"avatar": "%Avatar",
		&"cards": "%Cards",
		&"marker": "%D",
		&"badge_row_2": "%SB",
		&"badge_row_3": "%BB",
	}
	for role: StringName in paths:
		value.fields[role] = GuiSnapshotMeasurement.element(
			get_node(paths[role]), root, StringName("seat/%d/%s" % [_seat, role])
		)
	for card: GuiPlayingCard in (get_node("%Cards") as GuiHoleCards).cards:
		value.cards.append(
			card.get_card_snapshot(
				root,
				StringName("seat/%d/cards/%d" % [_seat, value.cards.size()]),
				(
					_authorized_faces[value.cards.size()]
					if value.cards.size() < _authorized_faces.size()
					else false
				)
			)
		)
	return value


static func _inherit_material(node: CanvasItem) -> void:
	for child: Node in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).use_parent_material = true
			_inherit_material(child)
