class_name NumberEntryViewModel
extends RefCounted

## UI draft/limits only. The receiving adapter validates committed number text.
var valid: bool = true
var title: String = "Enter a number"
var value: String = ""
var minimum: int = 1
var maximum: int = 1000000
var show_presets: bool = false
var minimum_preset: String = ""
var pot_preset: String = ""
## Optional contribution caption; the submitted street-total payload stays separate.
var pot_display_value: String = ""
var minimum_label: String = "Min"
## Caption prefix; an omitted display value falls back to the exact preset.
var pot_label: String = "Pot"
var pot_enabled: bool = false
