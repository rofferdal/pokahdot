extends RefCounted

## Development-only serialization of detached semantic measurements.


static func encode(snapshot: GuiLayoutSnapshot) -> Dictionary:
	var regions: Dictionary = {}
	for role: StringName in snapshot.elements:
		var value: GuiLayoutElement = snapshot.elements[role]
		regions[role] = rect(value.rect) if value.visible else rect(Rect2())
	var seats: Array[Dictionary] = []
	var labels: Array[Dictionary] = []
	for seat_id: int in snapshot.seats:
		var seat: GuiSeatSnapshot = snapshot.seats[seat_id]
		(
			seats
			. append(
				{
					"seat": seat_id,
					"rect": rect(seat.panel.rect),
					"status_rect": rect(seat.status.rect),
					"footprint": rect(seat.footprint),
				}
			)
		)
		for value: GuiLayoutElement in seat.fields.values():
			if value.visible and value.font_size > 0:
				labels.append(element(value))
	var measured: Array[Dictionary] = []
	for value: GuiLayoutElement in snapshot.measured:
		measured.append(element(value))
	return {
		"schema_version": snapshot.schema_version,
		"profile": snapshot.profile,
		"root_rect": rect(snapshot.root_rect),
		"surface_rect": rect(snapshot.surface_rect),
		"surface_size": [snapshot.surface_size.x, snapshot.surface_size.y],
		"usable_rect": rect(snapshot.usable_rect),
		"layout_generation": snapshot.generation,
		"pending": snapshot.pending,
		"ready": snapshot.ready,
		"regions": regions,
		"seats": seats,
		"labels": labels,
		"measured": measured,
	}


static func element(value: GuiLayoutElement) -> Dictionary:
	return {
		"role": String(value.role),
		"rect": rect(value.rect),
		"visible": value.visible,
		"enabled": value.enabled,
		"focused": value.focused,
		"text": value.text,
		"font_size": value.font_size,
		"effective_font_size": value.effective_font_size,
		"logical_scale": [value.logical_scale.x, value.logical_scale.y],
		"output_font_size": value.output_font_size,
		"required_size": [value.required_size.x, value.required_size.y],
		"allocated_size": [value.allocated_size.x, value.allocated_size.y],
		"clip_text": value.clip_text,
		"overrun": value.overrun,
		"max_lines": value.max_lines,
		"privacy_redacted": value.privacy_redacted,
	}


static func rect(value: Rect2) -> Array[float]:
	return [value.position.x, value.position.y, value.size.x, value.size.y]
