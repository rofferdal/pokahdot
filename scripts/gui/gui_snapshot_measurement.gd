class_name GuiSnapshotMeasurement
extends RefCounted

## Presentation-only measurement shared by GUI producers and reusable components.
## The returned values never retain controls or font resources.


static func profile_for_mode(mode: GuiSizeClass.LayoutMode) -> int:
	# Diagnostic enum compatibility only; geometry classification stays in policy.
	match mode:
		GuiSizeClass.LayoutMode.PHONE:
			return GuiLayoutProfile.Kind.PHONE_PORTRAIT
		GuiSizeClass.LayoutMode.PHONE_LANDSCAPE:
			return GuiLayoutProfile.Kind.PHONE_LANDSCAPE
		GuiSizeClass.LayoutMode.WIDE_COMPACT:
			return GuiLayoutProfile.Kind.SMALL_DESKTOP
		GuiSizeClass.LayoutMode.WIDE:
			return GuiLayoutProfile.Kind.DESKTOP
	return -1


static func rect(control: Control, root: Control) -> Rect2:
	return _control_transform(control, root) * Rect2(Vector2.ZERO, control.size)


static func local_rect(control: Control, root: Control, local: Rect2) -> Rect2:
	return _control_transform(control, root) * local


static func _control_transform(control: Control, root: Control) -> Transform2D:
	var transform: Transform2D = control.get_global_transform_with_canvas()
	if control.get_viewport() != root.get_viewport():
		var popup := control.get_viewport() as Window
		if popup != null:
			transform = _popup_transform(popup, root) * transform
	return transform


static func _popup_transform(popup: Window, root: Control) -> Transform2D:
	var offset := Transform2D(0.0, Vector2(popup.position))
	if popup.is_embedded():
		return offset * popup.get_final_transform()
	var parent_window: Window = root.get_window()
	if parent_window != null:
		offset.origin -= Vector2(parent_window.position)
	return (
		root.get_viewport().get_final_transform().affine_inverse()
		* offset
		* popup.get_final_transform()
	)


static func element(
	control: Control, root: Control, role: StringName, redact: bool = false
) -> GuiLayoutElement:
	var value := GuiLayoutElement.new()
	value.role = role
	if not is_instance_valid(control):
		return value
	value.present = true
	value.focused = control.has_focus()
	value.rect = rect(control, root)
	value.allocated_size = control.size
	var content: Rect2 = _local_content_rect(control)
	value.content_rect = _control_transform(control, root) * content
	value.local_content_size = content.size
	value.visible = control.is_visible_in_tree()
	value.interactive = control is BaseButton or control is LineEdit
	value.enabled = not (control is BaseButton and (control as BaseButton).disabled)
	if control is LineEdit:
		value.enabled = (control as LineEdit).editable
	value.clip_contents = control.clip_contents
	value.opacity = control.self_modulate.a
	var ancestor: Node = control
	while ancestor is CanvasItem:
		value.opacity *= (ancestor as CanvasItem).modulate.a
		ancestor = ancestor.get_parent()
	value.privacy_redacted = redact
	if control is TextureRect:
		var texture: Texture2D = (control as TextureRect).texture
		value.texture_present = texture != null
		if texture != null and texture.get_height() > 0:
			value.texture_aspect_ratio = float(texture.get_width()) / texture.get_height()
	if not redact:
		value.tooltip = control.tooltip_text
	_measure_text(control, value, redact)
	var scale: Vector2 = _control_transform(control, root).get_scale().abs()
	value.logical_scale = scale
	value.effective_font_size = value.font_size * minf(scale.x, scale.y)
	var output_scale: Vector2 = root.get_viewport().get_final_transform().get_scale().abs()
	value.output_font_size = value.effective_font_size * minf(output_scale.x, output_scale.y)
	return value


static func _local_content_rect(control: Control) -> Rect2:
	var value := Rect2(Vector2.ZERO, control.size)
	if not control.has_theme_stylebox("normal"):
		return value
	var style: StyleBox = control.get_theme_stylebox("normal")
	var margins := Vector2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP))
	value.position += margins
	value.size -= margins + Vector2(style.get_margin(SIDE_RIGHT), style.get_margin(SIDE_BOTTOM))
	value.size = value.size.max(Vector2.ZERO)
	return value


static func _measure_text(control: Control, value: GuiLayoutElement, redact: bool) -> void:
	var text: String = ""
	if control is Label:
		value.text_kind = &"label"
		var label := control as Label
		text = label.text
		value.font_size = label.get_theme_font_size("font_size")
		value.max_lines = label.max_lines_visible
		value.clip_text = label.clip_text
		value.overrun = label.text_overrun_behavior
		var paragraph := TextParagraph.new()
		paragraph.add_string(text, label.get_theme_font("font"), value.font_size)
		paragraph.break_flags = TextServer.BREAK_MANDATORY
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			paragraph.width = label.size.x
			paragraph.break_flags |= label.autowrap_trim_flags
			match label.autowrap_mode:
				TextServer.AUTOWRAP_ARBITRARY:
					paragraph.break_flags |= TextServer.BREAK_GRAPHEME_BOUND
				TextServer.AUTOWRAP_WORD:
					paragraph.break_flags |= TextServer.BREAK_WORD_BOUND
				TextServer.AUTOWRAP_WORD_SMART:
					paragraph.break_flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		value.required_size = paragraph.get_size()
		value.line_count = paragraph.get_line_count()
		value.required_size.y += (
			maxi(0, value.line_count - 1) * label.get_theme_constant("line_spacing")
		)
	elif control is Button or control is LineEdit:
		value.text_kind = &"button" if control is Button else &"input"
		text = (control as Button).text if control is Button else (control as LineEdit).text
		if control is LineEdit and text.is_empty():
			text = (control as LineEdit).placeholder_text
		value.font_size = control.get_theme_font_size("font_size")
		value.required_size = control.get_theme_font("font").get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, value.font_size
		)
		value.line_count = 1 if not text.is_empty() else 0
		if control is Button and "\n" in text:
			var paragraph := TextParagraph.new()
			paragraph.break_flags = TextServer.BREAK_MANDATORY
			paragraph.add_string(text, control.get_theme_font("font"), value.font_size)
			value.required_size = paragraph.get_size()
			value.line_count = paragraph.get_line_count()
			value.required_size.y += (
				maxi(0, value.line_count - 1) * control.get_theme_constant("line_spacing")
			)
	elif control is RichTextLabel:
		value.text_kind = &"rich_text"
		var rich := control as RichTextLabel
		text = rich.get_parsed_text()
		value.font_size = rich.get_theme_font_size("normal_font_size")
		value.required_size = Vector2(rich.get_content_width(), rich.get_content_height())
		value.line_count = rich.get_line_count()
	if not redact:
		value.text = text
		value.value_text = (control as LineEdit).text if control is LineEdit else text


static func descendants(
	node: Node,
	root: Control,
	role: StringName,
	result: Array[GuiLayoutElement],
	redacted_roots: Array[Node] = [],
	redact: bool = false,
	excluded_roots: Array[Node] = [],
	semantic_nodes: Dictionary[Node, StringName] = {},
) -> void:
	redact = redact or node in redacted_roots
	for index: int in range(node.get_child_count(true)):
		var child: Node = node.get_child(index, true)
		if child is Window or child in excluded_roots:
			continue
		var child_role: StringName = semantic_nodes.get(
			child, StringName("%s/child/%d" % [role, index])
		)
		if child is Control:
			var value := element(
				child as Control, root, child_role, redact or child in redacted_roots
			)
			value.parent_role = role
			result.append(value)
		descendants(
			child, root, child_role, result, redacted_roots, redact, excluded_roots, semantic_nodes
		)


static func cards(
	container: Control, root: Control, role: StringName, authorized: bool
) -> Array[GuiCardSnapshot]:
	var result: Array[GuiCardSnapshot] = []
	if not is_instance_valid(container):
		return result
	for index: int in range(container.get_child_count()):
		var child := container.get_child(index) as Control
		if child == null:
			continue
		var value := GuiCardSnapshot.new()
		value.authorized = authorized
		var card_role := StringName("%s/%d" % [role, index])
		value.element = element(child, root, card_role, not authorized)
		var rank := child.find_child("Rank", true, false) as Control
		var suit := child.find_child("Suit", true, false) as Control
		if rank != null or suit != null or String(child.name).begins_with("ShowdownCard"):
			value.kind = GuiCardSnapshot.Kind.FACE
		elif String(child.name).begins_with("CardBack"):
			value.kind = GuiCardSnapshot.Kind.BACK
		elif child is Label or String(child.name).begins_with("HoleCardField"):
			value.kind = GuiCardSnapshot.Kind.EMPTY
		value.rank = element(rank, root, StringName("%s/rank" % card_role), not authorized)
		value.suit = element(suit, root, StringName("%s/suit" % card_role), not authorized)
		result.append(value)
	return result


static func overlay(
	node: Node, root: Control, kind: StringName, redacted_roots: Array[Node] = []
) -> GuiOverlaySnapshot:
	var result := GuiOverlaySnapshot.new()
	result.kind = kind
	result.element = GuiLayoutElement.new()
	result.element.role = StringName("overlay/%s" % kind)
	if not is_instance_valid(node):
		return result
	if node is Control:
		result.element = element(node as Control, root, result.element.role)
	elif node is Window:
		var window := node as Window
		result.window_based = true
		result.native_window = not window.is_embedded()
		result.element.visible = window.visible
		result.element.present = true
		result.element.rect = (_popup_frame_rect(window, root))
		result.element.content_rect = result.element.rect
	descendants(node, root, result.element.role, result.measured, redacted_roots)
	result.elements = _overlay_elements(node, root, kind)
	return result


static func _popup_frame_rect(window: Window, root: Control) -> Rect2:
	if window.is_embedded():
		return Rect2(Vector2(window.position), Vector2(window.size))
	var frame := Rect2(Vector2(window.position - root.get_window().position), Vector2(window.size))
	return root.get_viewport().get_final_transform().affine_inverse() * frame


static func _overlay_elements(
	node: Node, root: Control, kind: StringName
) -> Dictionary[StringName, GuiLayoutElement]:
	var names: Dictionary[StringName, String] = {}
	match kind:
		&"keypad":
			names = {
				&"clear": "KeyClear",
				&"back": "KeyBack",
				&"done": "Done",
				&"cancel": "Cancel",
				&"value": "Value",
				&"title": "Title",
				&"range": "Range",
				&"minimum": "KeyMin",
				&"pot": "KeyPot",
			}
			for digit: int in range(10):
				names[StringName("key/%d" % digit)] = "Key%d" % digit
		&"menu":
			names = {
				&"close": "PhoneMenuCloseButton",
				&"quit": "PhoneMenuQuitButton",
				&"summary": "PhoneMenuShowdownButton",
				&"blinds": "PhoneBlindLevelDetail",
			}
		&"quit":
			names = {&"continue": "PhoneQuitContinueButton", &"confirm": "PhoneQuitConfirmButton"}
		&"summary":
			names = {&"text": "PhoneShowdownSummary", &"close": "PhoneShowdownCloseButton"}
		&"seat_detail":
			names = {&"close": "CloseButton", &"name": "Name", &"stack": "Stack", &"state": "State"}
	var result: Dictionary[StringName, GuiLayoutElement] = {}
	for role: StringName in names:
		result[role] = element(
			node.find_child(names[role], true, false) as Control,
			root,
			StringName("overlay/%s/%s" % [kind, role])
		)
	if kind == &"quit" and node is ConfirmationDialog:
		var dialog := node as ConfirmationDialog
		result[&"continue"] = element(dialog.get_cancel_button(), root, &"overlay/quit/continue")
		result[&"confirm"] = element(dialog.get_ok_button(), root, &"overlay/quit/confirm")
	return result
