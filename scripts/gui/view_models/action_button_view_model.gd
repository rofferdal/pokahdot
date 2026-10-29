class_name ActionButtonViewModel
extends RefCounted

## UI intent only; the consuming adapter owns the action.
var label: String = ""
var intent: StringName = &""
var enabled: bool = true
var primary: bool = false
var keypad: bool = false
