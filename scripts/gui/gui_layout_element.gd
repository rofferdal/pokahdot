class_name GuiLayoutElement
extends RefCounted

## Detached observation of a rendered element in root-viewport logical units.
var role: StringName
var parent_role: StringName
var present: bool = false
var text_kind: StringName = &"none"
var focused: bool = false
var rect := Rect2()
var content_rect := Rect2()
var visible: bool = false
var interactive: bool = false
var enabled: bool = true
var text: String = ""
var value_text: String = ""
var tooltip: String = ""
## Text measurements and allocations remain Control-local for direct comparison.
var required_size := Vector2.ZERO
var local_content_size := Vector2.ZERO
var logical_scale := Vector2.ONE
var line_count: int = 0
var max_lines: int = -1
var font_size: int = 0
var effective_font_size: float = 0.0
var output_font_size: float = 0.0
var opacity: float = 1.0
var clip_contents: bool = false
var clip_text: bool = false
var overrun: int = TextServer.OVERRUN_NO_TRIMMING
var privacy_redacted: bool = false
var texture_present: bool = false
var texture_aspect_ratio: float = 0.0
var allocated_size := Vector2.ZERO
