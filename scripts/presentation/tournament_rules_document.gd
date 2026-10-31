class_name TournamentRulesDocument
extends Resource

## Fixed product reference. No game state, rule calculations or adapter dependencies.

const EXPECTED_SECTION_IDS: Array[StringName] = [
	&"tournament", &"sizing", &"short_all_ins", &"pot_shortcut", &"blinds", &"ending"
]

@export var title: String
@export var sections: Array[TournamentRulesSection] = []


class RenderResult:
	extends RefCounted

	var text: String = ""
	var errors: PackedStringArray = []

	func is_valid() -> bool:
		return errors.is_empty()


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if title.strip_edges().is_empty():
		errors.append("Document title must not be blank.")
	if sections.size() != EXPECTED_SECTION_IDS.size():
		errors.append("Document must contain all six ordered sections.")
	var seen: Array[StringName] = []
	for index: int in sections.size():
		var section: TournamentRulesSection = sections[index]
		if section == null:
			errors.append("Section %d must not be null." % index)
			continue
		if str(section.id).strip_edges().is_empty():
			errors.append("Section %d ID must not be blank." % index)
		if section.id in seen:
			errors.append("Section ID '%s' is duplicated." % section.id)
		seen.append(section.id)
		if index >= EXPECTED_SECTION_IDS.size() or section.id != EXPECTED_SECTION_IDS[index]:
			errors.append("Section %d has an unexpected ID or order." % index)
		if section.title.strip_edges().is_empty():
			errors.append("Section %d title must not be blank." % index)
		if section.body.strip_edges().is_empty():
			errors.append("Section %d body must not be blank." % index)
	return errors


func render_plain_text() -> RenderResult:
	var result := RenderResult.new()
	result.errors = validate()
	if not result.is_valid():
		return result
	var blocks := PackedStringArray([title])
	for section: TournamentRulesSection in sections:
		blocks.append("%s\n%s" % [section.title, section.body])
	result.text = "\n\n".join(blocks)
	return result
