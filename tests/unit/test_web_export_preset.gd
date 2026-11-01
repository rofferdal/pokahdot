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
			+ "artifacts/*,artifacts/**/*,resources/bot_profiles/campaigns/*,"
			+ "resources/bot_profiles/campaigns/**/*,"
			+ "resources/bot_profiles/published/*.provenance.json,.gutconfig.json"
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


func test_bot_campaign_evidence_is_excluded_without_removing_playable_profiles() -> void:
	var export_presets := ConfigFile.new()
	assert_eq(export_presets.load(WEB_PRESET_PATH), OK)
	var patterns: PackedStringArray = (
		String(export_presets.get_value(WEB_PRESET_SECTION, "exclude_filter")).split(",")
	)
	for evidence: String in [
		"resources/bot_profiles/campaigns/bot_roster_expansion_20261101/campaign.json",
		"resources/bot_profiles/campaigns/bot_roster_expansion_20261101/round1_comparison.json",
		"resources/bot_profiles/campaigns/bot_roster_expansion_20261101/round2_comparison.json",
		"resources/bot_profiles/published/example.campaign_20261101.provenance.json",
		"resources/bot_profiles/published/example.provenance.json",
	]:
		assert_true(_matches_exclusion(evidence, patterns), evidence)
	for profile_path: String in PlayableBotRoster.DEFAULT_PROFILE_PATHS:
		var relative_path := profile_path.trim_prefix("res://")
		assert_false(_matches_exclusion(relative_path, patterns), relative_path)


func _matches_exclusion(path: String, patterns: PackedStringArray) -> bool:
	for pattern: String in patterns:
		if path.match(pattern):
			return true
	return false
