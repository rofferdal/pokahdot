class_name GuiEventLogMeasurement
extends RefCounted


# Measures a log dock against its themed text and component minimum.
static func minimum_dock_width(log: GuiEventLog, characters: int) -> float:
	var body: RichTextLabel = log.get_body()
	var copy_width: float = (
		body
		. get_theme_font("normal_font")
		. get_string_size(
			"0".repeat(characters),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			body.get_theme_font_size("normal_font_size")
		)
		. x
	)
	return maxf(log.get_combined_minimum_size().x, ceilf(copy_width))
