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
var minimum_label: String = "Min"
## Caption prefix; the keypad appends the exact pot_preset amount.
var pot_label: String = "Pot"
var pot_enabled: bool = false
