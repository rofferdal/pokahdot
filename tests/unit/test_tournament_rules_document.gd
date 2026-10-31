extends GutTest

const Document := preload("res://resources/presentation/tournament_rules.tres")


func test_authored_document_has_stable_section_order_and_plain_text_rendering() -> void:
	assert_eq(Document.validate(), PackedStringArray())
	assert_eq(Document.title, "Pokahdot tournament rules")
	var result: TournamentRulesDocument.RenderResult = Document.render_plain_text()
	assert_true(result.is_valid())
	var expected := PackedStringArray([Document.title])
	for index: int in Document.sections.size():
		var section: TournamentRulesSection = Document.sections[index]
		assert_eq(section.id, TournamentRulesDocument.EXPECTED_SECTION_IDS[index])
		expected.append("%s\n%s" % [section.title, section.body])
	assert_eq(result.text, "\n\n".join(expected))
	assert_false(result.text.ends_with("\n"))


func test_blank_document_titles_fail_without_partial_rendering() -> void:
	for title: String in ["", " \n\t"]:
		var document := _copy()
		document.title = title
		_assert_invalid(document, "Document title")


func test_missing_extra_and_null_sections_fail_without_partial_rendering() -> void:
	var missing := _copy()
	missing.sections.pop_back()
	_assert_invalid(missing, "six ordered sections")
	var extra := _copy()
	extra.sections.append(extra.sections[0])
	_assert_invalid(extra, "six ordered sections")
	var empty := _copy()
	empty.sections.clear()
	_assert_invalid(empty, "six ordered sections")
	var null_section := _copy()
	null_section.sections[2] = null
	_assert_invalid(null_section, "must not be null")


func test_blank_section_values_fail_without_partial_rendering() -> void:
	for property: StringName in [&"id", &"title", &"body"]:
		for value: String in ["", " \n\t"]:
			var document := _copy()
			document.sections[1].set(property, StringName(value) if property == &"id" else value)
			_assert_invalid(document, "must not be blank")


func test_duplicate_unknown_and_reordered_ids_fail_without_partial_rendering() -> void:
	var duplicate := _copy()
	duplicate.sections[1].id = duplicate.sections[0].id
	_assert_invalid(duplicate, "duplicated")
	var unknown := _copy()
	unknown.sections[1].id = &"unknown"
	_assert_invalid(unknown, "unexpected ID or order")
	var reordered := _copy()
	var first: TournamentRulesSection = reordered.sections[0]
	reordered.sections[0] = reordered.sections[1]
	reordered.sections[1] = first
	_assert_invalid(reordered, "unexpected ID or order")


func test_setup_and_ending_copy_preserve_product_limits_and_quit_semantics() -> void:
	_assert_phrases(
		&"tournament",
		[
			"One human",
			"2–9",
			"2–7 on small-phone layouts",
			"6 players, 1000 chips each",
			"5/10",
			"Everyone starts equally",
			"stay fixed",
			"positive whole numbers",
			"1,000,000",
			"small blind cannot exceed big blind"
		]
	)
	_assert_phrases(
		&"ending",
		[
			"permanent elimination",
			"no rebuys",
			"Last player with chips wins",
			"without settling the pot or declaring a winner",
			"no monetary value"
		]
	)


func test_sizing_copy_keeps_nominal_blind_increment_and_short_all_in_boundaries() -> void:
	_assert_phrases(
		&"sizing",
		[
			"street totals",
			"at least one big blind",
			"twice the nominal big blind",
			"even when posted short",
			"previous full bet/raise increment",
			"Each full raise replaces that increment",
			"reset it to one big blind each street",
			"A full opening bet sets it",
			"all-in"
		]
	)
	_assert_phrases(
		&"short_all_ins",
		[
			"change the call target",
			"retain the increment",
			"never reopen closed raise rights",
			"even cumulatively",
			"one-big-blind increment",
			"Checking before it leaves raising closed",
			"Unacted players retain their choices",
			"big blind 10 and opening all-in 5",
			"reaches at least 15"
		]
	)


func test_pot_copy_distinguishes_contribution_from_total_without_clamping() -> void:
	_assert_phrases(
		&"pot_shortcut",
		[
			"pot P",
			"existing street wager H",
			"adds P chips",
			"submits H + P",
			"call is included once",
			"exact total is legal and affordable",
			"never clamped",
			"No Limit convenience, not Pot Limit sizing"
		]
	)


func test_blind_copy_preserves_fixed_completed_hand_interval_rounding_and_saturation() -> void:
	_assert_phrases(
		&"blinds",
		[
			"completed hands, not time",
			"Starting with at least five active players",
			"twice that count in hands; otherwise ten",
			"stays fixed despite eliminations",
			"After settlement",
			"next level's first hand",
			"× 1.25",
			"rounded upward to even",
			"small blind half",
			"5/10 → 7/14 → 9/18",
			"saturate at 500,000/1,000,000",
			"level counters continue"
		]
	)


func _copy() -> TournamentRulesDocument:
	return Document.duplicate(true) as TournamentRulesDocument


func _assert_invalid(document: TournamentRulesDocument, error_fragment: String) -> void:
	var errors: PackedStringArray = document.validate()
	assert_false(errors.is_empty())
	assert_string_contains("\n".join(errors), error_fragment)
	var result: TournamentRulesDocument.RenderResult = document.render_plain_text()
	assert_false(result.is_valid())
	assert_eq(result.errors, errors)
	assert_eq(result.text, "", "Invalid documents must never expose partial rule copy")


func _assert_phrases(id: StringName, phrases: Array[String]) -> void:
	var section: TournamentRulesSection = Document.sections[
		TournamentRulesDocument.EXPECTED_SECTION_IDS.find(id)
	]
	for phrase: String in phrases:
		assert_string_contains(section.body, phrase)
