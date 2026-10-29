class_name GuiFitCandidate
extends RefCounted

## One lower-bound envelope. Containers still own allocation and final fit.
enum Density { FULL, COMPACT, MINIMAL }
enum ActionFlow { SINGLE_ROW, TWO_ROWS, KEYPAD }

var mode: GuiSizeClass.LayoutMode = GuiSizeClass.LayoutMode.NOT_READY
var density: Density = Density.COMPACT
var action_flow: ActionFlow = ActionFlow.TWO_ROWS
var minimum := Vector2.ZERO
var seats: GuiSeatRows
var evidence: StringName = &"unmeasured"
var valid: bool = false


static func measure(
	layout: GuiSizeClass.LayoutMode,
	metrics: GuiFitMetrics,
	ids: PackedInt32Array,
	recipient: int,
	copy_density: Density = Density.COMPACT,
	flow: ActionFlow = ActionFlow.TWO_ROWS
) -> GuiFitCandidate:
	var result := GuiFitCandidate.new()
	result.mode = layout
	result.density = copy_density
	result.action_flow = flow
	if (
		metrics == null
		or not metrics.valid()
		or layout < GuiSizeClass.LayoutMode.PHONE
		or layout > GuiSizeClass.LayoutMode.WIDE
		or copy_density < Density.FULL
		or copy_density > Density.MINIMAL
		or flow < ActionFlow.SINGLE_ROW
		or flow > ActionFlow.KEYPAD
	):
		return result
	var phone: bool = (
		layout in [GuiSizeClass.LayoutMode.PHONE, GuiSizeClass.LayoutMode.PHONE_LANDSCAPE]
	)
	if phone and ids.size() > 7:
		return result
	# The hero/action rail occupies the other landscape region: at most two
	# opponent seats can share any horizontal band with that hero.
	result.seats = GuiSeatRows.compose(ids, recipient, phone)
	if not result.seats.valid:
		return result
	var rows: int = result.seats.rows.size() - 1
	var columns: int = 0
	for index: int in rows:
		columns = maxi(columns, result.seats.rows[index].size())
	var grid := Vector2(
		columns * metrics.opponent.x + (columns - 1) * metrics.gap,
		rows * metrics.opponent.y + (rows - 1) * metrics.gap
	)
	if layout == GuiSizeClass.LayoutMode.PHONE:
		result.minimum = Vector2(
			maxf(maxf(grid.x, metrics.board.x), maxf(metrics.hero.x, metrics.actions.x)),
			grid.y + metrics.board.y + metrics.hero.y + metrics.actions.y + 3.0 * metrics.gap
		)
	elif layout == GuiSizeClass.LayoutMode.PHONE_LANDSCAPE:
		result.minimum = Vector2(
			maxf(grid.x, metrics.board.x) + metrics.gap + maxf(metrics.hero.x, metrics.actions.x),
			maxf(
				grid.y + metrics.gap + metrics.board.y,
				metrics.hero.y + metrics.gap + metrics.actions.y
			)
		)
	else:
		if metrics.event_log.x <= 0.0 or metrics.event_log.y <= 0.0:
			return result
		var sides_height: float = maxf(
			0.0, (rows - 1) * (metrics.opponent.y + metrics.gap) - metrics.gap
		)
		var ring_width: float = grid.x
		if rows > 1:
			ring_width = maxf(
				ring_width, 2.0 * metrics.opponent.x + metrics.board.x + 2.0 * metrics.gap
			)
		result.minimum = Vector2(
			maxf(
				maxf(ring_width, metrics.board.x),
				metrics.hero.x + metrics.actions.x + metrics.event_log.x + 2.0 * metrics.gap
			),
			(
				metrics.opponent.y
				+ maxf(sides_height, metrics.board.y)
				+ maxf(metrics.hero.y, maxf(metrics.actions.y, metrics.event_log.y))
				+ 2.0 * metrics.gap
			)
		)
	result.minimum += 2.0 * metrics.margin
	result.evidence = metrics.evidence
	result.valid = result.minimum.is_finite()
	return result
