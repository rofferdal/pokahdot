class_name CliRulesReference
extends RefCounted

## Renders the same fixed reference used by the GUI, without match or history access.

const DOCUMENT := preload("res://resources/presentation/tournament_rules.tres")


static func write_to(io: CliIO, document: TournamentRulesDocument = DOCUMENT) -> void:
	if document == null:
		io.write_line("Unable to display tournament rules: document is missing.")
		return
	var result: TournamentRulesDocument.RenderResult = document.render_plain_text()
	if not result.is_valid():
		io.write_line("Unable to display tournament rules: %s" % "; ".join(result.errors))
		return
	io.write_line(result.text)
