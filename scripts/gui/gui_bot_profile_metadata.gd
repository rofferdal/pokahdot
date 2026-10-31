class_name GuiBotProfileMetadata
extends RefCounted


## Validates public plain-text identity without retaining a profile Resource.
static func is_valid_name(value: String) -> bool:
	if value.is_empty() or value != value.strip_edges():
		return false
	for index: int in value.length():
		var codepoint: int = value.unicode_at(index)
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159):
			return false
		if codepoint == 0x2028 or codepoint == 0x2029:
			return false
	return true
