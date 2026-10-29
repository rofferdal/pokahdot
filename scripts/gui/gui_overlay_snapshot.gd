class_name GuiOverlaySnapshot
extends RefCounted

var kind: StringName
var element: GuiLayoutElement
var native_window: bool = false
var window_based: bool = false
var selected_seat: int = -1
var measured: Array[GuiLayoutElement] = []
var cards: Array[GuiCardSnapshot] = []
var elements: Dictionary[StringName, GuiLayoutElement] = {}
