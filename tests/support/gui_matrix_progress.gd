class_name GuiMatrixProgress
extends RefCounted

## Fixture-level CI diagnostics; never changes scheduling or pass/fail decisions.
var _group: String
var _total: int
var _index: int = 0
var _label: String
var _started_us: int
var _group_started_us: int


func _init(group: String, total: int) -> void:
	_group = group
	_total = total
	_group_started_us = Time.get_ticks_usec()


func begin(label: String) -> void:
	_index += 1
	_label = label
	_started_us = Time.get_ticks_usec()
	print("[layout %s %d/%d] START %s" % [_group, _index, _total, _label])


func finish(frames: int = -1) -> void:
	var elapsed_ms: float = (Time.get_ticks_usec() - _started_us) / 1000.0
	var waited: String = " / %d frames" % frames if frames >= 0 else ""
	print(
		(
			"[layout %s %d/%d] DONE %s / %.1f ms%s"
			% [_group, _index, _total, _label, elapsed_ms, waited]
		)
	)
	if _index == _total:
		print(
			(
				"[layout %s] COMPLETE %d fixtures / %.3f s"
				% [_group, _total, (Time.get_ticks_usec() - _group_started_us) / 1000000.0]
			)
		)
