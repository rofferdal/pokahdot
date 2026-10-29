class_name InputFieldViewModel
extends RefCounted

## Exact draft text; parsing, limits and commit/cancel belong to the adapter.
var value: String = ""
var placeholder: String = ""
var enabled: bool = true
var invalid: bool = false
var total: bool = false
## Explicit keypad-only entry surface, independent of screen size.
var touch_entry: bool = false
var accessible_name: String = ""
