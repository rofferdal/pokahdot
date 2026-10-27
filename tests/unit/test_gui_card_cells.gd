extends "res://tests/support/poker_gut_test.gd"


func test_fixed_portrait_cards_fit_every_rank_and_suit_after_font_scaling() -> void:
	for dimensions: Vector2 in [Vector2(48, 54), Vector2(46, 30)]:
		for rank_value: int in range(2, 15):
			for suit_value: int in range(4):
				var card := CardData.new(rank_value, suit_value)
				var face := CardFaceFactory.create_card_face(
					card, "Card", dimensions, 32, Color.WHITE, Color.BLACK, true
				)
				add_child_autofree(face)
				GuiMobileTableLayout._scale_card_face(
					face, dimensions, 22 if dimensions.x == 48 else 20
				)
				await get_tree().process_frame
				await get_tree().process_frame
				var rank := face.get_node("Content/Rank") as Label
				var suit := face.get_node("Content/Suit") as TextureRect
				var needed: float = (
					rank
					. get_theme_font("font")
					. get_string_size(
						rank.text,
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						rank.get_theme_font_size("font_size")
					)
					. x
				)
				assert_eq(rank.text, CardFaceFactory.card_rank_text[rank_value])
				assert_gte(rank.size.x, needed)
				assert_gte(suit.size.x, 18.0)
				assert_gte(suit.size.y, 18.0)
				assert_true(face.get_global_rect().encloses(suit.get_global_rect()))
				assert_lte(rank.get_global_rect().end.x, suit.global_position.x)
