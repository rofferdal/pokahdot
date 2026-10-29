extends SceneTree


func _initialize() -> void:
	var fixture: Node = (
		load("res://tests/performance/gui_replacement_refresh_fixture.tscn").instantiate()
	)
	root.add_child.call_deferred(fixture)
