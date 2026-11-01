"""Immutable configuration and accounting for a nine-player roster campaign."""
from __future__ import annotations

import copy
from functools import wraps
from typing import Any

from .artifacts import create_artifact, validate_artifact_envelope
from .contracts import GENES, require_exact_fields, require_identifier, require_integer, validate_parameters
from .errors import ExitCode, ToolError

POLICY = "roster_campaign_v1"
PROTECTED_CONTROL_IDS = frozenset(("nit_caller", "tight_aggressive", "loose_passive", "loose_aggressive", "balanced"))
STAGES = ("prepared", "candidates_frozen", "round1_complete", "round2_complete", "confirmed")
BLOCK_NAMES = ("pilot", "baseline", "round1", "round1_extension", "round2", "round2_extension", "confirmation_a", "confirmation_b", "after")
CONFIG_FIELDS = ("policy", "campaign_id", "player_count", "starting_stack", "small_blind", "big_blind", "expected_contenders", "survivor_counts", "round_repetitions", "confirmation_repetitions", "maximum_schedule_cycles", "maximum_extensions", "maximum_parallel_processes", "seed_blocks", "generation_seed", "mutation_seed", "schedule_seeds", "cutoff_rule")


def fail(message: str) -> None:
    raise ToolError("invalid_campaign", message, ExitCode.INVALID_INPUT)


def schema_boundary(function):
    """Convert malformed JSON shapes into stable validation diagnostics."""
    @wraps(function)
    def checked(*args, **kwargs):
        try:
            return function(*args, **kwargs)
        except (KeyError, TypeError, ValueError, IndexError, AttributeError) as error:
            fail(f"Malformed campaign input for {function.__name__}: {error}")
    return checked


def default_config(campaign_id: str) -> dict[str, Any]:
    """Return proposed budgets; preparation freezes them before competitive play."""
    return {
        "policy": POLICY, "campaign_id": campaign_id, "player_count": 9,
        "starting_stack": 1000, "small_blind": 5, "big_blind": 10,
        "expected_contenders": 30, "survivor_counts": [25, 20],
        "round_repetitions": [297, 594], "confirmation_repetitions": 297,
        "maximum_schedule_cycles": 64, "maximum_extensions": 1,
        "maximum_parallel_processes": 4,
        "seed_blocks": {name: {"minimum": 1_200_000_000 + i * 10_000_000,
                               "maximum": 1_209_999_999 + i * 10_000_000}
                        for i, name in enumerate(BLOCK_NAMES)},
        "generation_seed": 2026110101, "mutation_seed": 2026110102,
        "schedule_seeds": [2026110111, 2026110112],
        "cutoff_rule": "extend_full_round_once_when_marginal_intervals_overlap_then_fitness_desc_id_asc",
    }


@schema_boundary
def validate_config(config: dict[str, Any]) -> None:
    require_exact_fields(config, CONFIG_FIELDS, "campaign configuration")
    if config["policy"] != POLICY:
        fail("Unsupported campaign policy.")
    require_identifier(config["campaign_id"], "campaign_id")
    for field, expected in (("player_count", 9), ("expected_contenders", 30)):
        require_integer(config[field], field, expected, expected)
    if config["survivor_counts"] != [25, 20] or any(type(x) is not int for x in config["survivor_counts"]):
        fail("Campaign must eliminate exactly five contenders in each round.")
    for field in ("starting_stack", "small_blind", "big_blind"):
        require_integer(config[field], field, 1, 1_000_000)
    if (config["starting_stack"], config["small_blind"], config["big_blind"]) != (1000, 5, 10):
        fail("Campaign requires the frozen 100bb, 5/10 regime.")
    rounds = config["round_repetitions"]
    if not isinstance(rounds, list) or len(rounds) != 2:
        fail("Two round repetition budgets are required.")
    for n in rounds:
        require_integer(n, "round repetitions", 9, 10_000_000)
        if n % 9:
            fail("Round repetitions must include complete nine-seat rotations.")
    if rounds[1] < rounds[0] * 2:
        fail("Round two must have at least twice round one's per-table budget.")
    require_integer(config["confirmation_repetitions"], "confirmation repetitions", 297, 10_000_000)
    if config["confirmation_repetitions"] % 9:
        fail("Confirmation requires complete nine-seat rotations.")
    for field, lower, upper in (("maximum_schedule_cycles", 1, 1024), ("maximum_extensions", 0, 1), ("maximum_parallel_processes", 1, 16)):
        require_integer(config[field], field, lower, upper)
    for field in ("generation_seed", "mutation_seed"):
        require_integer(config[field], field, 0, 2**64 - 1)
    if not isinstance(config["schedule_seeds"], list) or len(config["schedule_seeds"]) != 2:
        fail("Exactly two schedule seeds are required.")
    for seed in config["schedule_seeds"]:
        require_integer(seed, "schedule seed", 0, 2**64 - 1)
    if config["cutoff_rule"] != default_config("validation")["cutoff_rule"]:
        fail("Unsupported cutoff rule.")
    require_exact_fields(config["seed_blocks"], BLOCK_NAMES, "campaign seed blocks")
    intervals = []
    for name, block in config["seed_blocks"].items():
        require_exact_fields(block, ("minimum", "maximum"), "seed block")
        lo = require_integer(block["minimum"], "seed minimum", 1, 2**53 - 1)
        hi = require_integer(block["maximum"], "seed maximum", lo, 2**53 - 1)
        intervals.append((lo, hi, name))
    intervals.sort()
    if any(a[1] >= b[0] for a, b in zip(intervals, intervals[1:])):
        fail("Campaign effective seed blocks must be disjoint.")


@schema_boundary
def seed_start(config: dict[str, Any], block: str, count: int, offset: int = 0) -> int:
    validate_config(config)
    if block not in config["seed_blocks"]:
        fail("Unknown seed block.")
    require_integer(count, "seed count", 1, 2**53 - 1)
    require_integer(offset, "seed offset", 0, 2**53 - 1)
    interval = config["seed_blocks"][block]
    start = interval["minimum"] + offset
    if start + count - 1 > interval["maximum"]:
        fail("Planned tournament seeds exceed the reserved block.")
    return start


def _profiles(profiles: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    if not isinstance(profiles, list):
        fail("Profiles must be an array.")
    result = {}
    for profile in profiles:
        require_exact_fields(profile, ("profile_id", "model_id", "parameters"), "campaign profile")
        identifier = require_identifier(profile["profile_id"], "profile ID")
        require_identifier(profile["model_id"], "model ID")
        if identifier in result:
            fail("Duplicate profile identity.")
        if not isinstance(profile["parameters"], dict):
            fail("Profile parameters must be an object.")
        if profile["model_id"] == "strategy_parameterized":
            validate_parameters(profile["parameters"])
        result[identifier] = profile
    return result


@schema_boundary
def create_campaign(config: dict[str, Any], inventory: dict[str, Any], archives: list[dict[str, Any]]) -> dict[str, Any]:
    validate_config(config)
    payload = {"config": copy.deepcopy(config), "inventory": copy.deepcopy(inventory),
               "archives": copy.deepcopy(archives), "stage": "prepared", "contenders": [],
               "rounds": [], "confirmations": []}
    from .historical_lineage import validate_historical_lineage
    ancestry = {}
    for archive in archives:
        ancestry.update(validate_historical_lineage(archive)["entries"])
    for item in inventory["incumbents"]:
        original = ancestry.get(item["candidate_id"])
        if original is None:
            fail("Incumbent archival creation evidence missing.")
        payload["contenders"].append({"candidate_id": item["candidate_id"],
            "profile": copy.deepcopy(item["profile"]), "display_name": item["display_name"],
            "origin": "incumbent", "parent_ids": copy.deepcopy(original["candidate"]["parent_ids"]), "status": "active",
            "creation_checksum": original["original_creation"]["creation_context"]["artifact_checksum"]})
    artifact = create_artifact("roster_campaign", payload)
    validate_campaign(artifact)
    return artifact


@schema_boundary
def validate_campaign(artifact: dict[str, Any]) -> dict[str, Any]:
    from .historical_lineage import validate_historical_lineage
    validate_artifact_envelope(artifact, "roster_campaign")
    p = artifact["payload"]
    fields = ("config", "inventory", "archives", "stage", "contenders", "rounds", "confirmations")
    if p.get("stage") == "candidates_frozen":
        fields += ("prepared_campaign", "candidate_generation")
    require_exact_fields(p, fields, "campaign ledger")
    validate_config(p["config"])
    if p["stage"] not in STAGES:
        fail("Unknown campaign stage.")
    archive_entries = {}
    for archive in p["archives"]:
        context = validate_historical_lineage(archive)
        for identifier, entry in context["entries"].items():
            if identifier in archive_entries and archive_entries[identifier] != entry:
                fail("Contradictory historical candidate identities.")
            archive_entries[identifier] = entry
    inventory = p["inventory"]
    controls = _profiles(inventory["fixed_controls"])
    benchmarks = _profiles(inventory["confirmation_benchmarks"])
    if len(controls) != 5 or len(benchmarks) != 8:
        fail("Five strategic controls and eight strategic confirmation benchmarks required.")
    if set(controls) != PROTECTED_CONTROL_IDS:
        fail("All five hand-authored strategic profiles must remain protected controls.")
    if sum(x["model_id"] == "strategy_parameterized" for x in controls.values()) != 5:
        fail("Five handcrafted strategic controls are required.")
    if any(controls[k] != benchmarks[k] for k in controls.keys() & benchmarks.keys()):
        fail("Shared control/benchmark snapshots must match exactly.")
    if any(p["model_id"] != "strategy_parameterized" for p in list(controls.values()) + list(benchmarks.values())):
        fail("Legacy model profiles are excluded from campaign competition and confirmation.")
    historical_benchmarks = [x for k, x in benchmarks.items() if k not in controls]
    if not historical_benchmarks:
        fail("A disjoint historical champion benchmark is required.")
    for profile in historical_benchmarks:
        entry = archive_entries.get(profile["profile_id"])
        if entry is None or not entry["historical_selection"] or (entry["candidate"]["model_id"] != profile["model_id"] or entry["candidate"]["parameters"] != profile["parameters"]):
            fail("Historical benchmark must have actual archived selection and matching genes.")
    ids, aliases, genes, names = set(), set(), set(), set()
    incumbents = {x["candidate_id"]: x for x in inventory["incumbents"]}
    if len(incumbents) != 10:
        fail("Exactly ten original incumbents required.")
    for row in p["contenders"]:
        require_exact_fields(row, ("candidate_id", "profile", "display_name", "origin", "parent_ids", "status", "creation_checksum"), "contender")
        identifier = require_identifier(row["candidate_id"], "candidate_id")
        profile = row["profile"]
        _profiles([profile])
        alias = profile["profile_id"]
        if identifier in ids or identifier in aliases or alias in ids or alias in aliases or alias in controls or alias in benchmarks or identifier in benchmarks:
            fail("Contender IDs/aliases must be unique and disjoint from benchmarks/controls.")
        ids.add(identifier); aliases.add(alias)
        if profile["model_id"] != "strategy_parameterized":
            fail("Contenders must use the strategic model.")
        vector = tuple(profile["parameters"][g] for g in GENES)
        if vector in genes:
            fail("Duplicate contender parameter vector.")
        genes.add(vector)
        name = row["display_name"]
        if not isinstance(name, str) or not name.strip() or name.casefold() in names:
            fail("Display names must be nonempty and unique.")
        names.add(name.casefold())
        if row["status"] not in ("active", "rejected_round1", "rejected_round2", "finalist", "confirmed"):
            fail("Invalid contender state.")
        if identifier in incumbents and row["origin"] != "incumbent":
            fail("Original incumbents must retain their recorded origin.")
        if row["origin"] == "incumbent":
            original = incumbents.get(identifier)
            archived = archive_entries.get(identifier)
            if not original or not archived or archived["candidate"]["parameters"] != profile["parameters"] or original["profile"] != profile or original["display_name"] != name:
                fail("Incumbent snapshot/name contradicts immutable inventory or ancestry.")
            if row["parent_ids"] != archived["candidate"]["parent_ids"] or row["creation_checksum"] != archived["original_creation"]["creation_context"]["artifact_checksum"]:
                fail("Incumbent creation record contradicts archived ancestry.")
        elif row["origin"] not in ("initialized", "mutated"):
            fail("Unknown candidate origin.")
    if not set(incumbents).issubset(ids):
        fail("An original incumbent is missing from the ledger.")
    if p["stage"] == "candidates_frozen":
        from .campaign_generation import validate_candidate_generation
        prepared = validate_campaign(p["prepared_campaign"])
        if prepared["stage"] != "prepared":
            fail("Frozen candidates must bind the original prepared campaign.")
        for field in ("config", "inventory", "archives"):
            if p[field] != prepared[field]:
                fail("Frozen campaign inputs differ from their prepared source.")
        generation = validate_candidate_generation(p["candidate_generation"], p["prepared_campaign"])
        if p["contenders"] != prepared["contenders"] + generation["new_contenders"]:
            fail("Frozen contender identities/genes/names differ from creation evidence.")
        if p["rounds"] or p["confirmations"]:
            fail("Frozen candidates cannot claim completed rounds or confirmation.")
    elif p["stage"] != "prepared":
        fail("Later campaign stages require verified round evidence; not implemented yet.")
    if p["stage"] == "prepared":
        if len(ids) != 10 or p["rounds"] or p["confirmations"] or any(x["status"] != "active" for x in p["contenders"]):
            fail("Prepared ledger must contain only the ten incumbents.")
    elif len(ids) != 30:
        fail("Frozen campaign must account for exactly thirty contenders.")
    return p


@schema_boundary
def freeze_candidates(prepared: dict[str, Any], generation: dict[str, Any]) -> dict[str, Any]:
    from .campaign_generation import validate_candidate_generation
    source = validate_campaign(prepared)
    if source["stage"] != "prepared":
        fail("Candidate freeze requires a prepared campaign.")
    context = validate_candidate_generation(generation, prepared)
    payload = copy.deepcopy(source)
    payload.update(stage="candidates_frozen", prepared_campaign=copy.deepcopy(prepared),
                   candidate_generation=copy.deepcopy(generation))
    payload["contenders"].extend(copy.deepcopy(context["new_contenders"]))
    result = create_artifact("roster_campaign", payload)
    validate_campaign(result)
    return result
