class_name GuiTableComposition
extends MarginContainer

## Shared replacement interface. The owning host alone applies usable origins.
signal policy_changed(state: GuiCompositionState)
signal action_requested(intent: StringName)
signal wager_edited(text: String)
signal wager_submitted(text: String)
signal entry_requested(draft: String)
signal menu_requested
signal seat_detail_requested(seat: int)

var policy: GuiCompositionState


func apply_policy(state: GuiCompositionState) -> void:
	theme = GuiTypography.for_density(state.density)
	theme_type_variation = &"TableComposition"
	policy = state
	policy_changed.emit(state)


func render(_model: TableViewModel) -> bool:
	push_error("The registered composition does not implement model rendering.")
	return false


func set_wager_draft(_text: String) -> void:
	pass


func get_wager_draft() -> String:
	return ""


func use_keypad(_enabled: bool) -> void:
	pass


func get_seat_controls() -> Dictionary[int, Control]:
	return {}


func get_control(_role: StringName) -> Control:
	return null


func get_layout_snapshot(_root: Control) -> GuiLayoutSnapshot:
	return GuiLayoutSnapshot.new()


func get_fit_candidate(
	_mode: GuiSizeClass.LayoutMode,
	_density: GuiFitCandidate.Density,
	_flow: GuiFitCandidate.ActionFlow
) -> GuiFitCandidate:
	return GuiFitCandidate.new()
