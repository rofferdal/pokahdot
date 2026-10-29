extends "res://tests/support/poker_gut_test.gd"

const Registry := preload("res://tests/support/gui_layout_sweep_registry.gd")


func test_exact_registry_rejects_new_failures_and_unexpected_passes() -> void:
	var cases: Array[Dictionary] = [
		{"id": "phone/360x640/p7", "failures": PackedStringArray(["containment: seat/1"])},
		{"id": "desktop/1920x1080/p6", "failures": PackedStringArray()},
	]
	var registry: Dictionary = Registry.create(cases, "fixture-sha")
	assert_eq(Registry.compare(cases, registry), PackedStringArray())
	cases[1].failures.append("text-clipping: seat/2/name")
	assert_false(Registry.compare(cases, registry).is_empty(), "A new defect must fail")
	cases[1].failures.clear()
	cases[0].failures.clear()
	assert_false(Registry.compare(cases, registry).is_empty(), "A fixed defect requires review")


func test_input_identity_and_registry_corruption_cannot_hide_changes() -> void:
	var cases: Array[Dictionary] = [{"id": "case-a", "failures": PackedStringArray(["fit: panel"])}]
	var registry: Dictionary = Registry.create(cases, "fixture-sha")
	cases.append({"id": "case-a", "failures": PackedStringArray(["fit: panel"])})
	assert_false(Registry.compare(cases, registry).is_empty(), "Duplicate IDs fail")
	cases.pop_back()
	cases[0].id = "case-b"
	assert_false(Registry.compare(cases, registry).is_empty(), "A changed input fails")
	cases[0].id = "case-a"
	cases[0]["observations"] = {"profile": 3}
	assert_false(Registry.compare(cases, registry).is_empty(), "Policy drift needs review")
	cases[0].erase("observations")
	registry.known_failures.append(registry.known_failures[0].duplicate(true))
	assert_false(Registry.compare(cases, registry).is_empty(), "Duplicate registry IDs fail")


func test_signature_order_and_duplicate_messages_do_not_change_the_contract() -> void:
	var cases: Array[Dictionary] = [
		{"id": "case-a", "failures": PackedStringArray(["b", "a", "b"])}
	]
	var registry: Dictionary = Registry.create(cases, "fixture-sha")
	cases[0].failures = PackedStringArray(["a", "b"])
	assert_eq(Registry.compare(cases, registry), PackedStringArray())
