class_name GuiTableComposition
extends MarginContainer

## Base for authored replacement compositions. Children consume this same value;
## they measure local fit without reclassifying the viewport or core state.
signal policy_changed(state: GuiCompositionState)

var policy: GuiCompositionState


func apply_policy(state: GuiCompositionState) -> void:
	theme = GuiTypography.for_density(state.density)
	theme_type_variation = &"TableComposition"
	policy = state
	policy_changed.emit(state)
