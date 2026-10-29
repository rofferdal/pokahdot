class_name GuiCardSnapshot
extends RefCounted

enum Kind { EMPTY, BACK, FACE, UNKNOWN }

var kind: Kind = Kind.UNKNOWN
var element: GuiLayoutElement
var rank: GuiLayoutElement
var suit: GuiLayoutElement
var authorized: bool = false
