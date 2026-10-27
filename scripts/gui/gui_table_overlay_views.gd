class_name GuiTableOverlayViews
extends RefCounted

## Owns modal view construction and geometry, independent of match advancement.
## Callbacks cross the component boundary only for user dismissal and quit.
const GuiTableStyleScript := preload("res://scripts/gui/gui_table_style.gd")

var showdown: PanelContainer
var menu: PanelContainer
var quit_panel: PanelContainer
var detail_overlay: PanelContainer
var detail_close_button: Button
var detail_seat: int = Table.NO_SEAT
var switching: bool = false


func configure(root: Control) -> void:
	showdown = root.get_node("%PhoneShowdownOverlay") as PanelContainer
	menu = root.get_node("%PhoneOverflowMenu") as PanelContainer
	quit_panel = root.get_node("%PhoneQuitConfirmation") as PanelContainer
	for overlay: PanelContainer in [showdown, menu, quit_panel]:
		overlay.add_theme_stylebox_override(
			"panel", GuiTableStyleScript.box(Color("062516fa"), Color("e7d39b"), 2, 10)
		)


func rebuild_detail(
	player_view: PlayerView,
	factory: GuiTableSeatFactory,
	surface: Control,
	close_detail_callback: Callable,
	quit_callback: Callable
) -> void:
	if is_instance_valid(detail_overlay):
		detail_overlay.free()
	detail_overlay = PanelContainer.new()
	detail_overlay.name = "SeatDetailOverlay"
	detail_overlay.z_index = 500
	detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_overlay.add_theme_stylebox_override(
		"panel", GuiTableStyleScript.box(Color("062516f7"), Color("e7d39b"), 2, 10)
	)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 4)
	detail_overlay.add_child(content)
	var heading := factory.phone_token_label("Name", factory.seat_title(player_view))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var stack := factory.phone_token_label("Stack", "%d chips" % player_view.stack)
	stack.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(stack)
	var state_text: String = factory.phone_seat_badge_text(player_view)
	var state := factory.phone_token_label("State", state_text.strip_edges())
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(state)
	var cards := factory.create_opponent_hole_cards(player_view)
	cards.name = "DetailHoleCards"
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(cards)
	detail_close_button = Button.new()
	detail_close_button.name = "CloseButton"
	detail_close_button.text = "Close"
	detail_close_button.custom_minimum_size = Vector2(96, 48)
	detail_close_button.add_theme_font_size_override(
		"font_size", GuiTableSeatFactory.GUI_MINIMUM_FONT_SIZE
	)
	detail_close_button.pressed.connect(close_detail_callback)
	content.add_child(detail_close_button)
	add_quit_button(content, quit_callback)
	surface.add_child(detail_overlay)


func close_detail() -> void:
	detail_seat = Table.NO_SEAT
	if is_instance_valid(detail_overlay):
		detail_overlay.hide()


func switch_modal(keypad: WagerKeypad, quit_dialog: ConfirmationDialog, keep_keypad: bool) -> void:
	switching = true
	showdown.hide()
	menu.hide()
	quit_panel.hide()
	quit_dialog.hide()
	close_detail()
	# Reopening the same popup must not cancel a newly opened draft.
	if not keep_keypad:
		keypad.cancel()
	switching = false


func finish_if_closed(
	guard: GuiModalGuard, keypad: WagerKeypad, quit_dialog: ConfirmationDialog
) -> void:
	if guard == null or switching:
		return
	if not (
		showdown.visible
		or menu.visible
		or quit_panel.visible
		or quit_dialog.visible
		or keypad.visible
		or (is_instance_valid(detail_overlay) and detail_overlay.visible)
	):
		guard.finish()


func layout(plan: GuiPhoneLayoutPlan) -> void:
	showdown.position = plan.overlay_rect.position
	showdown.size = plan.overlay_rect.size
	menu.position = plan.menu_rect.position
	menu.size = plan.menu_rect.size
	if is_instance_valid(detail_overlay) and detail_overlay.visible:
		detail_overlay.position = plan.seat_detail_rect.position
		detail_overlay.size = plan.seat_detail_rect.size
	if quit_panel.visible:
		quit_panel.position = plan.phone_quit_rect.position
		quit_panel.size = plan.phone_quit_rect.size


static func add_quit_button(content: Node, quit_callback: Callable) -> void:
	var button := Button.new()
	button.name = "ModalQuitButton"
	button.text = "Quit"
	button.custom_minimum_size.y = 48.0
	button.add_theme_font_size_override("font_size", GuiTableSeatFactory.GUI_MINIMUM_FONT_SIZE)
	button.pressed.connect(quit_callback)
	content.add_child(button)
