extends "res://tests/support/poker_gut_test.gd"

const Suites := preload("res://tests/support/gui_invariant_matrix_suites.gd")
const CaptureManifest := preload("res://tests/support/gui_visual_capture_manifest.gd")
const PhoneContract := preload("res://tests/support/gui_phone_matrix_contract.gd")
const Harness := preload("res://tests/support/gui_scene_harness.gd")
const States := preload("res://tests/support/gui_visual_state_fixtures.gd")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")


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


func test_generic_harness_settles_and_resizes_a_snapshot_only_fixture_driver() -> void:
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	harness.set_fixture_driver(SnapshotFixtureDriver.new())
	var rendered: Dictionary = harness.render(
		States.by_id(&"human-turn-preflop", 6), Vector2i(400, 800)
	)
	assert_eq(rendered.root.name, "IndependentComposition")
	assert_true(await harness.settle_layout())
	harness.resize_viewport(Vector2i(800, 400))
	assert_true(await harness.settle_layout())
	assert_eq(rendered.root.get_layout_snapshot().root_rect.size, Vector2(800, 400))
	rendered.root.layout_pending = true
	assert_false(
		await harness.settle_layout(4), "Pending snapshots must time out within the frame bound"
	)
	rendered.root.layout_pending = false
	rendered.root.layout_ready = false
	assert_false(await harness.settle_layout(4), "Nonready snapshots must not settle")
	rendered.root.layout_ready = true
	var rebound: Dictionary = harness.rerender(States.by_id(&"human-turn-river", 6))
	assert_eq(rebound.descriptor.id, &"human-turn-river")
	assert_true(await harness.settle_layout())


func test_reference_geometry_oracles_are_optional_without_waiving_semantic_bounds() -> void:
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	var rendered: Dictionary = harness.render(
		States.by_id(&"human-turn-preflop", 6), Vector2i(390, 844)
	)
	assert_true(await harness.settle_layout())
	# A shared vertical offset preserves paired rows and the centered odd apex.
	for seat: GuiSeatSnapshot in rendered.root.get_layout_snapshot().seats.values():
		if not seat.hero:
			rendered.table._seat_widgets[seat.seat_id].position.y += 1.0
			rendered.table._seat_status_widgets[seat.seat_id].position.y += 1.0
	var panel: Control = rendered.table._seat_widgets[1]
	var failures := PackedStringArray()
	PhoneContract.validate(rendered, "flexible portrait geometry", failures)
	assert_eq(failures, PackedStringArray(), "Portrait has no frozen pixel oracle.")
	panel.position.x = -500.0
	PhoneContract.validate(rendered, "reference outside bounds", failures)
	assert_string_contains("\n".join(failures), "portrait-footprint:")
	rendered.erase("reference_geometry_check")
	var generic_failures: PackedStringArray = Invariants.validate(rendered)
	assert_string_contains("\n".join(generic_failures), "containment:")
	var landscape: Node = Harness.new()
	add_child_autofree(landscape)
	var other: Dictionary = landscape.render(
		States.by_id(&"human-turn-preflop", 6), Vector2i(844, 390)
	)
	assert_true(await landscape.settle_layout())
	other.table._seat_widgets[1].position.y += 1.0
	failures.clear()
	PhoneContract.validate(other, "unchanged landscape characterization", failures)
	assert_string_contains("\n".join(failures), "density-tier rectangle mismatch")


func test_phone_contract_rejects_an_extra_private_face_alongside_both_backs() -> void:
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	var rendered: Dictionary = harness.render(
		States.by_id(&"human-turn-preflop", 6), Vector2i(390, 844)
	)
	assert_true(await harness.settle_layout())
	var cards: Control = rendered.table._seat_widgets[1].hole_cards
	var private_face := Label.new()
	private_face.name = "ShowdownCard1"
	cards.add_child(private_face)
	var failures := PackedStringArray()
	PhoneContract.validate(rendered, "extra face", failures)
	assert_string_contains("\n".join(failures), "does not show two hole-card fields")
	assert_string_contains("\n".join(failures), "exposes or omits private cards")


func test_phone_contract_rejects_hidden_back_and_revealed_card_children() -> void:
	var cases: Array[Dictionary] = [
		{
			"state": &"human-turn-preflop",
			"seat": 1,
			"card": "CardBack1",
			"failure": "exposes or omits private cards"
		},
		{
			"state": &"showdown-long",
			"seat": 4,
			"card": "ShowdownCard1",
			"failure": "revealed-card presentation is incorrect"
		},
	]
	for case: Dictionary in cases:
		var harness: Node = Harness.new()
		add_child_autofree(harness)
		var rendered: Dictionary = harness.render(States.by_id(case.state, 6), Vector2i(390, 844))
		assert_true(await harness.settle_layout())
		var before := PackedStringArray()
		PhoneContract.validate(rendered, "before visibility mutation", before)
		assert_eq(before, PackedStringArray())
		var panel := (
			rendered.table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % case.seat)
			as Control
		)
		var card := panel.find_child(case.card, true, false) as Control
		assert_true(card.is_visible_in_tree())
		card.hide()
		var failures := PackedStringArray()
		PhoneContract.validate(rendered, "hidden required card", failures)
		assert_string_contains("\n".join(failures), case.failure)
		card.show()
		var restored := PackedStringArray()
		PhoneContract.validate(rendered, "restored required card", restored)
		assert_eq(restored, PackedStringArray())


class SnapshotFixtureRoot:
	extends Control

	var layout_ready: bool = true
	var layout_pending: bool = false

	func get_layout_snapshot() -> GuiLayoutSnapshot:
		var snapshot := GuiLayoutSnapshot.new()
		snapshot.root_rect = Rect2(position, size)
		snapshot.usable_rect = snapshot.root_rect
		snapshot.ready = layout_ready
		snapshot.pending = layout_pending
		return snapshot


class SnapshotFixtureDriver:
	extends RefCounted

	func render(
		viewport: SubViewport, descriptor: Dictionary, size: Vector2i, _profile: int
	) -> Dictionary:
		var root := SnapshotFixtureRoot.new()
		root.name = "IndependentComposition"
		root.size = Vector2(size)
		viewport.add_child(root)
		return {"root": root, "descriptor": descriptor}

	func resize(rendered: Dictionary, size: Vector2i) -> void:
		rendered.root.size = Vector2(size)

	func rerender(rendered: Dictionary, descriptor: Dictionary) -> Dictionary:
		rendered.descriptor = descriptor
		return rendered
