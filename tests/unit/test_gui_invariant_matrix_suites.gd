extends "res://tests/support/poker_gut_test.gd"

const Suites := preload("res://tests/support/gui_invariant_matrix_suites.gd")
const CaptureManifest := preload("res://tests/support/gui_visual_capture_manifest.gd")
const PhoneContract := preload("res://tests/support/gui_phone_matrix_contract.gd")
const Harness := preload("res://tests/support/gui_scene_harness.gd")
const States := preload("res://tests/support/gui_visual_state_fixtures.gd")


func test_declarative_suites_preserve_every_ordered_historical_case_identity() -> void:
	# Hashes captured from the original four runners' selection before extraction.
	# These exclude source hashes so implementation changes cannot hide coverage drift.
	var expected := {
		Suites.Suite.MILESTONE_THREE:
		[348, "815d729b825507aeff333f88414bd2fc0cead34c372d0d13db9e345521a00865"],
		Suites.Suite.PHONE:
		[406, "a751d5f6c6d51272f607bbdd0e5d497d48caf3181a138f442c41d0ac08baf83c"],
		Suites.Suite.IPAD:
		[288, "81ca103a57566703bd08cc028e344ca07fa7fba1457b964aa4ab4974a8cf6947"],
		Suites.Suite.DESKTOP:
		[232, "9e34988457307b61e4274d0c1a9e602e83b4a23b16d122181b9303f8e9b94063"],
	}
	for suite: Suites.Suite in expected:
		var cases: Array[Dictionary] = Suites.cases(suite)
		var ids: Array[String] = []
		for case: Dictionary in cases:
			ids.append(CaptureManifest.capture_id(case))
		assert_eq(cases.size(), expected[suite][0])
		assert_eq("\n".join(ids).sha256_text(), expected[suite][1])


func test_suite_definitions_do_not_expose_shared_mutable_configuration() -> void:
	var phone := Suites.definition(Suites.Suite.PHONE)
	assert_true(phone.phone_contract)
	phone.viewport_ids.clear()
	phone.player_counts.append(9)
	phone.excluded_state_ids.clear()
	var fresh := Suites.definition(Suites.Suite.PHONE)
	assert_eq(fresh.viewport_ids.size(), 7)
	assert_eq(fresh.player_counts, [2, 4, 6, 7])
	assert_eq(fresh.excluded_state_ids, [&"event-history-full"])
	for suite: Suites.Suite in [
		Suites.Suite.MILESTONE_THREE, Suites.Suite.IPAD, Suites.Suite.DESKTOP
	]:
		assert_false(Suites.definition(suite).phone_contract)


func test_capture_source_provenance_binds_shared_suite_runner_and_phone_contract() -> void:
	var sources: Dictionary = CaptureManifest.matrix_source_checksums()
	for source: String in [
		"res://tests/support/gui_invariant_matrix_suites.gd",
		"res://tests/support/gui_invariant_matrix_runner.gd",
		"res://tests/support/gui_phone_matrix_contract.gd",
	]:
		assert_true(sources.has(source))
		assert_eq(sources.get(source, ""), FileAccess.get_sha256(source))
		assert_eq(String(sources.get(source, "")).length(), 64)


func test_extracted_phone_contract_still_rejects_an_unrevealed_opponent_face() -> void:
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	var rendered: Dictionary = harness.render(
		States.by_id(&"human-turn-preflop", 6),
		Vector2i(390, 844),
		GuiLayoutProfile.Kind.PHONE_PORTRAIT
	)
	assert_true(await harness.settle_layout())
	var failures := PackedStringArray()
	PhoneContract.validate(rendered, "before mutation", failures)
	assert_eq(failures, PackedStringArray())
	var cards: Control = rendered.table._seat_widgets[1].hole_cards
	cards.get_node("CardBack1").free()
	var private_face := Label.new()
	private_face.name = "ShowdownCard1"
	cards.add_child(private_face)
	PhoneContract.validate(rendered, "after mutation", failures)
	assert_string_contains("\n".join(failures), "seat 1 exposes or omits private cards")
