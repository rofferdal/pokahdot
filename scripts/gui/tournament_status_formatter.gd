class_name GuiTournamentStatusFormatter
extends RefCounted

## Converts recipient-safe tournament state into presentation-only status text.


static func format(view) -> String:
	if view.tournament_status != &"finished":
		return ""
	if view.end_reason == &"player_quit":
		return "Tournament ended: player quit."
	if view.end_reason == &"winner":
		for player_view: PlayerView in view.seats:
			if player_view.seat == view.tournament_winner_seat:
				return "%s wins the tournament!" % player_view.display_name
	return "Tournament finished."
