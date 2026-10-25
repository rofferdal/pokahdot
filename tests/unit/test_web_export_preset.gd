extends "res://tests/support/poker_gut_test.gd"

const WEB_PRESET_PATH := "res://export_presets.cfg"
const WEB_PRESET_SECTION := "preset.0"
const WEB_OPTIONS_SECTION := "preset.0.options"


func test_web_release_preset_excludes_development_content_and_is_single_threaded() -> void:
	var export_presets := ConfigFile.new()
	var load_error := export_presets.load(WEB_PRESET_PATH)

	assert_eq(load_error, OK, "The committed Web export preset must be readable.")
	assert_eq(export_presets.get_value(WEB_PRESET_SECTION, "name"), "Web")
	assert_eq(export_presets.get_value(WEB_PRESET_SECTION, "platform"), "Web")
	assert_eq(export_presets.get_value(WEB_PRESET_SECTION, "export_path"), "build/web/index.html")
	assert_eq(
		export_presets.get_value(WEB_PRESET_SECTION, "exclude_filter"),
		(
			"addons/*,addons/**/*,tests/*,tests/**/*,localtmp/*,localtmp/**/*,"
			+ "artifacts/*,artifacts/**/*,.gutconfig.json,"
			+ "my_test_node.gd,my_test_node.tscn"
		)
	)
	assert_false(
		export_presets.get_value(WEB_OPTIONS_SECTION, "variant/thread_support"),
		"The baseline Web release must not require cross-origin-isolation headers."
	)
	assert_false(export_presets.get_value(WEB_OPTIONS_SECTION, "progressive_web_app/enabled"))
	assert_true(
		export_presets.get_value(WEB_OPTIONS_SECTION, "html/experimental_virtual_keyboard"),
		"The Web export must provide touchscreen text entry for the startup form."
	)
	assert_eq(export_presets.get_value(WEB_OPTIONS_SECTION, "custom_template/debug"), "")
	assert_eq(export_presets.get_value(WEB_OPTIONS_SECTION, "custom_template/release"), "")
