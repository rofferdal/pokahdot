class_name HandSummaryLineViewModel
extends RefCounted

## Semantic emphasis is presentation data, independent of fonts or colors.
var text: String = ""
var seat: int = Table.NO_SEAT
var winner_emphasis: bool = false


static func create(
	copy: String, emphasized: bool, seat_id: int = Table.NO_SEAT
) -> HandSummaryLineViewModel:
	var result := HandSummaryLineViewModel.new()
	result.text = copy
	result.winner_emphasis = emphasized
	result.seat = seat_id
	return result
