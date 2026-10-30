class_name GuiSummaryTextRenderer
extends RefCounted


# Renders detached summary lines as literal text with winner emphasis.
static func render(body: RichTextLabel, model: HandSummaryViewModel) -> void:
	body.clear()
	if model != null:
		if model.lines.is_empty():
			body.add_text(model.text)
		else:
			for index: int in model.lines.size():
				var line: HandSummaryLineViewModel = model.lines[index]
				if line.winner_emphasis:
					body.push_bold()
					body.push_color(Color.YELLOW)
				body.add_text(line.text)
				if line.winner_emphasis:
					body.pop()
					body.pop()
				if index < model.lines.size() - 1:
					body.add_text("\n")
