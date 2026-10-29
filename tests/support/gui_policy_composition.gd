extends GuiTableComposition

## Independent container fixture, not a replacement poker-table design.


func apply_policy(value: GuiCompositionState) -> void:
	super.apply_policy(value)
	var label: Label = %PolicyLabel
	label.text = (
		"%s · %s"
		% [
			GuiFitCandidate.Density.keys()[value.density],
			GuiFitCandidate.ActionFlow.keys()[value.action_flow],
		]
	)
	var rows := PackedStringArray()
	for row: PackedInt32Array in value.seats.rows:
		rows.append(str(row))
	var seats: Label = %SeatRows
	seats.text = "\n".join(rows)
