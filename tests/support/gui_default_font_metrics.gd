extends RefCounted

## Platform-neutral measurements from Godot's built-in default font.

const SPECIMENS: Array[Dictionary] = [
	{"id": "longest_name", "text": "Annalise", "font_size": 18},
	{"id": "large_stack", "text": "1000000", "font_size": 18},
	{"id": "compact_action", "text": "Call 1000000", "font_size": 20},
	{"id": "card_rank", "text": "10", "font_size": 20},
]


static func capture(font: Font) -> Dictionary:
	if font == null:
		return {"built_in": false, "error": "The default font is unavailable.", "specimens": []}
	var specimens: Array[Dictionary] = []
	for specimen: Dictionary in SPECIMENS:
		var text: String = specimen.text
		var font_size: int = specimen.font_size
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		(
			specimens
			. append(
				{
					"id": specimen.id,
					"text": text,
					"font_size": font_size,
					"width": width,
					"height": font.get_height(font_size),
				}
			)
		)
	return {
		"built_in": font.resource_path.is_empty(),
		"font_class": font.get_class(),
		"resource_path": font.resource_path,
		"specimens": specimens,
	}
