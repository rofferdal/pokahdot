extends SceneTree

const Metrics := preload("res://tests/support/gui_default_font_metrics.gd")
const PREFIX := "RG62_DEFAULT_FONT_METRICS="


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var label := Label.new()
	root.add_child(label)
	await process_frame
	print(PREFIX + JSON.stringify(Metrics.capture(label.get_theme_font("font"))))
	label.queue_free()
	quit()
