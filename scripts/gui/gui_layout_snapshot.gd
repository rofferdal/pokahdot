class_name GuiLayoutSnapshot
extends RefCounted

## Values only: no scene nodes, core objects, textures or card resources survive capture.
## Rectangles share the owning root's viewport logical space, including popup origins.
## Font size is in theme units; effective size includes Control transforms and output
## size additionally includes the viewport final transform. Neither claims CSS parity.
var schema_version: int = 1
var profile: int = -1
var root_rect := Rect2()
var viewport_rect := Rect2()
var surface_rect := Rect2()
var surface_size := Vector2.ZERO
var surface_transform := Transform2D.IDENTITY
var usable_rect := Rect2()
var generation: int = 0
var pending: bool = false
var ready: bool = false
var elements: Dictionary[StringName, GuiLayoutElement] = {}
var seats: Dictionary[int, GuiSeatSnapshot] = {}
var board_cards: Array[GuiCardSnapshot] = []
var overlays: Array[GuiOverlaySnapshot] = []
var startup: GuiStartupSnapshot
var measured: Array[GuiLayoutElement] = []
var actions: Dictionary[int, Array] = {}
var legal_actions: Array[int] = []
var expected_board_card_count: int = 0


func geometry_signature() -> String:
	var parts := PackedStringArray([str(root_rect), str(usable_rect), str(pending)])
	for element: GuiLayoutElement in measured:
		if element.visible:
			parts.append("%s:%s" % [element.role, element.rect])
	for overlay: GuiOverlaySnapshot in overlays:
		parts.append("%s:%s:%s" % [overlay.kind, overlay.element.visible, overlay.element.rect])
		for element: GuiLayoutElement in overlay.measured:
			if element.visible:
				parts.append("%s:%s" % [element.role, element.rect])
	return "|".join(parts)
