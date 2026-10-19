class_name CardFaceFactory
extends RefCounted

const GuiTableStyleScript := preload("res://scripts/gui/gui_table_style.gd")
const CLUB_TEXTURE := preload("res://assets/ui/club.svg")
const DIAMOND_TEXTURE := preload("res://assets/ui/diamond.svg")
const HEART_TEXTURE := preload("res://assets/ui/heart.svg")
const SPADE_TEXTURE := preload("res://assets/ui/spade.svg")
const MAIN_POT_WINNER_STAR_TEXTURE := preload("res://assets/ui/winner_star.svg")
const SUIT_SIZE_RATIO: float = 0.9
static var card_rank_text: PackedStringArray = PackedStringArray(
	["", "", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
)


static func create_card_face(
	card_data: CardData,
	card_name: String,
	card_size: Vector2,
	rank_font_size: int,
	background_color: Color,
	border_color: Color,
) -> PanelContainer:
	var card_face := PanelContainer.new()
	card_face.name = card_name
	card_face.custom_minimum_size = card_size
	card_face.add_theme_stylebox_override(
		"panel", GuiTableStyleScript.box(background_color, border_color, 2, 4)
	)
	var content := HBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 1)
	card_face.add_child(content)
	var rank := Label.new()
	rank.name = "Rank"
	rank.text = card_rank_text[card_data.rank] if card_data != null else "?"
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank.add_theme_font_size_override("font_size", rank_font_size)
	rank.add_theme_color_override("font_color", _rank_color(card_data))
	content.add_child(rank)
	var suit := TextureRect.new()
	suit.name = "Suit"
	suit.custom_minimum_size = Vector2(
		rank_font_size * SUIT_SIZE_RATIO, rank_font_size * SUIT_SIZE_RATIO
	)
	suit.texture = _suit_texture(card_data)
	suit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	suit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(suit)
	return card_face


static func create_main_pot_winner_star(avatar_size: Vector2) -> TextureRect:
	var star := TextureRect.new()
	star.name = "MainPotWinnerStar"
	star.custom_minimum_size = avatar_size * 0.5
	star.texture = MAIN_POT_WINNER_STAR_TEXTURE
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return star


static func _suit_texture(card_data: CardData) -> Texture2D:
	if card_data == null:
		return SPADE_TEXTURE
	match card_data.suit:
		CardData.Suit.CLUBS:
			return CLUB_TEXTURE
		CardData.Suit.DIAMONDS:
			return DIAMOND_TEXTURE
		CardData.Suit.HEARTS:
			return HEART_TEXTURE
		CardData.Suit.SPADES:
			return SPADE_TEXTURE
	push_error("Card suit is invalid.")
	return SPADE_TEXTURE


static func _rank_color(card_data: CardData) -> Color:
	if (
		card_data != null
		and (card_data.suit == CardData.Suit.DIAMONDS or card_data.suit == CardData.Suit.HEARTS)
	):
		return Color("ad2636")
	return Color("172331")
