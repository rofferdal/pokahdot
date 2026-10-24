class_name GuiNameCatalog
extends RefCounted

## Stored visual-only first names for GUI tournaments.

const REQUIRED_NAME_COUNT := 50
const MAX_CODE_POINT_COUNT := 8

var _names: PackedStringArray


static func default_names() -> PackedStringArray:
	# The groups deliberately span Africa and the Middle East, South and East
	# Asia, Europe, the Americas, and Oceania. They are presentation data only;
	# they are not inferred from or associated with player data.
	return PackedStringArray(
		[
			"Amina",
			"Youssef",
			"Layla",
			"Omar",
			"Adaeze",
			"Kwame",
			"Zuri",
			"Thabo",
			"Nandi",
			"Chidi",
			"Priya",
			"Arjun",
			"Kavya",
			"Ayaan",
			"Mira",
			"Mei",
			"Wei",
			"Haruto",
			"Yui",
			"Minseo",
			"Jisoo",
			"Linh",
			"Bao",
			"Sofia",
			"Mateo",
			"Luca",
			"Ines",
			"Aoife",
			"Einar",
			"Freja",
			"Ana",
			"Tiago",
			"João",
			"Luz",
			"Diego",
			"Leilani",
			"Moana",
			"Tama",
			"Aroha",
			"Inti",
			"Nayra",
			"Amaru",
			"Noa",
			"Yael",
			"Lior",
			"Elif",
			"Deniz",
			"Anahit",
			"Nino",
			"Olena",
		]
	)


func _init(names: PackedStringArray = PackedStringArray()) -> void:
	_names = default_names() if names.is_empty() else names.duplicate()


func get_names() -> PackedStringArray:
	return _names.duplicate()


func validation_error() -> String:
	if _names.size() != REQUIRED_NAME_COUNT:
		return "GUI name catalog must contain exactly 50 names; found %d." % _names.size()

	var letter_pattern := RegEx.new()
	var compile_error: Error = letter_pattern.compile("\\A\\p{L}+\\z")
	if compile_error != OK:
		return "GUI name catalog Unicode-letter validation could not be initialized."

	var used_names: Dictionary[String, bool] = {}
	for display_name: String in _names:
		if letter_pattern.search(display_name) == null:
			return "GUI name catalog entry %s must contain only Unicode letters." % display_name
		if display_name.length() > MAX_CODE_POINT_COUNT:
			return "GUI name catalog entry %s exceeds eight Unicode code points." % display_name
		if used_names.has(display_name):
			return "GUI name catalog contains duplicate name: %s." % display_name
		used_names[display_name] = true
	return ""
