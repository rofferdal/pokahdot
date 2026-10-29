class_name GuiSeatSnapshot
extends RefCounted

var seat_id: int = -1
var visual_slot: int = -1
var hero: bool = false
var folded: bool = false
var busted: bool = false
var face_authorized: bool = false
var panel: GuiLayoutElement
var status: GuiLayoutElement
var footprint := Rect2()
var fields: Dictionary[StringName, GuiLayoutElement] = {}
var cards: Array[GuiCardSnapshot] = []
var required_badge_text: String = ""
