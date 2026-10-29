class_name GuiHoleCards
extends AspectRatioContainer

## Fit the pair as one native aspect group so spare cell space cannot split it.
@export var vertical_pair: bool = false
var cards: Array[GuiPlayingCard]:
	get:
		return (get_node("Row") as GuiCardRow).cards


func _ready() -> void:
	_refresh_layout()


func render(model: CardRowViewModel) -> void:
	(get_node("Row") as GuiCardRow).render(model)
	_refresh_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_refresh_layout()


func _refresh_layout() -> void:
	(get_node("Row") as GuiCardRow).vertical = vertical_pair
	if cards.is_empty():
		custom_minimum_size = Vector2.ZERO
		return
	var fraction: float = get_theme_constant("gap_percent", &"HoleCards") / 100.0
	var count: int = cards.size()
	# Equal native cells include half a gap on each side of each fitted card.
	# Their aspect ratio creates the visible gap without an allocation-dependent
	# HBox separation feeding back into the component's intrinsic minimum.
	var units: float = count * (1.0 + fraction * (cards[0].ratio if vertical_pair else 1.0))
	ratio = cards[0].ratio / units if vertical_pair else cards[0].ratio * units
	var floor_size := Vector2.ZERO
	for card: GuiPlayingCard in cards:
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL if vertical_pair else Control.SIZE_FILL
		floor_size = floor_size.max(card.get_combined_minimum_size())
	custom_minimum_size = (
		Vector2(floor_size.x, ceilf(maxf(floor_size.y * units, floor_size.x / ratio)))
		if vertical_pair
		else Vector2(ceilf(maxf(floor_size.x * units, floor_size.y * ratio)), floor_size.y)
	)
