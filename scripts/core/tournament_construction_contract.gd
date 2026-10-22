class_name TournamentConstructionContract
extends RefCounted

## Declares which participant composition a TournamentMatch may accept.
##
## Product composition uses the default exactly-one-human contract. The
## all-bot contract is reserved for the dedicated non-interactive simulation
## composition root; it is deliberately an explicit value rather than a
## boolean flag on the normal product configuration.

enum Kind {
	PRODUCT,
	SIMULATION,
}

var kind: Kind:
	get:
		return _kind

var _kind: Kind


func _init(contract_kind: Kind = Kind.PRODUCT) -> void:
	_kind = contract_kind


static func product() -> TournamentConstructionContract:
	return TournamentConstructionContract.new(Kind.PRODUCT)


static func simulation() -> TournamentConstructionContract:
	return TournamentConstructionContract.new(Kind.SIMULATION)


func validate_agents(
	seat_agents: Dictionary[int, Agent],
	player_count: int,
) -> String:
	var human_count: int = 0
	for seat: int in range(player_count):
		if not seat_agents.has(seat) or seat_agents[seat] == null:
			return "Seat %d has no agent." % seat
		if seat_agents[seat] is HumanAgent:
			human_count += 1

	match _kind:
		Kind.PRODUCT:
			if human_count != 1:
				return "A product tournament requires exactly one human agent."
		Kind.SIMULATION:
			if human_count != 0:
				return "A simulation tournament requires all seats to use bot agents."
		_:
			return "The tournament construction contract is invalid."
	return ""
