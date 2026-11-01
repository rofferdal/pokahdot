"""Nine-player campaign manifests using translated difference-covering blocks.

The construction ports SimulationManifestGenerator's cyclic design to the
external tool's stable SplitMix64 RNG. Auditing independently counts exposure
from emitted schema-2 tables and plans, without generator counters.
"""
from __future__ import annotations

import copy
import hashlib
from collections import Counter
from itertools import combinations
from typing import Any, Iterable

from .campaign import schema_boundary, seed_start, validate_campaign
from .contracts import require_integer
from .errors import ExitCode, ToolError
from .fitness import _simulation_manifest_checksum, _validate_manifest
from .prng import SplitMix64

# User-specified nine-player pattern; all subsequent tables add one modulo 35.
ROUND_ONE_SEED_PATTERN = (0, 1, 4, 6, 11, 17, 23, 31, 32)


def _fail(message: str) -> None:
    raise ToolError("invalid_campaign_schedule", message, ExitCode.INVALID_INPUT)


# Independently verified thirty-player pattern; identities are shuffled first.
ROUND_TWO_SEED_PATTERN = (7, 14, 21, 0, 5, 24, 11, 6, 2)


def _base_block(count: int, seed: int) -> list[int]:
    """Use verified cyclic templates; randomness belongs to profile ordering."""
    if count == 35:
        return list(ROUND_ONE_SEED_PATTERN)
    if count == 30:
        return list(ROUND_TWO_SEED_PATTERN)
    _fail("Cyclic round scheduling supports thirty or thirty-five participants.")


def _shuffle_round_two_profiles(profiles: list[dict[str, Any]], campaign_id: str, schedule_seed: int) -> list[dict[str, Any]]:
    """Shuffle a dedicated ordering stream before assigning numeric table IDs."""
    material = f"{campaign_id}:round2_profile_order_v1:{schedule_seed}".encode("utf-8")
    ordering_seed = int.from_bytes(hashlib.sha256(material).digest()[:8], "big")
    random = SplitMix64(ordering_seed)
    ordered = list(profiles)
    for index in range(len(ordered) - 1, 0, -1):
        swap = random.integer(0, index)
        ordered[index], ordered[swap] = ordered[swap], ordered[index]
    return ordered


def _manifest(context: dict[str, Any], profiles: list[dict[str, Any]], tables: list[list[str]], block: str, count: int) -> dict[str, Any]:
    config = context["config"]
    matchups = [{"matchup_id": f"{block}_table_{index:04d}", "profile_ids": table} for index, table in enumerate(tables)]
    manifest = {
        "schema_version": 2, "batch_id": f"{config['campaign_id']}_{block}",
        "seed_start": seed_start(config, block, count),
        "profiles": copy.deepcopy(profiles),
        "regimes": [{"regime_id": "nine_player_100bb", "player_count": 9,
                     "starting_stack": config["starting_stack"], "starting_small_blind": config["small_blind"],
                     "starting_big_blind": config["big_blind"], "blind_progression": "normative_hand_based_v1"}],
        "matchups": matchups,
        "evaluation_plans": [{"plan_id": f"{block}_plan", "regime_id": "nine_player_100bb",
                              "matchup_ids": [m["matchup_id"] for m in matchups], "tournament_count": count,
                              "seat_rotation": "cyclic", "minimum_profile_samples": 300 if block != "pilot" else 1,
                              "uncertainty_estimator": "normal_95"}],
    }
    _validate_manifest(manifest)
    return manifest


@schema_boundary
def build_round_manifest(campaign: dict[str, Any], round_number: int = 1, survivor_ids: Iterable[str] | None = None) -> dict[str, Any]:
    """Emit one translated table per participant; repetitions balance all seats."""
    context = validate_campaign(campaign)
    if context["stage"] == "prepared":
        _fail("Round scheduling requires all thirty candidates frozen.")
    require_integer(round_number, "round number", 1, 2)
    contenders = context["contenders"]
    by_id = {r["candidate_id"]: r for r in contenders}
    if round_number == 1:
        if survivor_ids is not None:
            _fail("Round one must include every contender; survivor IDs are not applicable.")
        selected = contenders
    else:
        if survivor_ids is None or isinstance(survivor_ids, (str, bytes)):
            _fail("Round two requires twenty-five explicit survivor candidate IDs.")
        survivors = list(survivor_ids)
        if len(survivors) != 25 or any(not isinstance(identifier, str) for identifier in survivors) or len(set(survivors)) != 25 or not set(survivors).issubset(by_id):
            _fail("Round two requires exactly twenty-five distinct known contender IDs.")
        selected = [row for row in contenders if row["candidate_id"] in survivors]
    profiles = [row["profile"] for row in selected] + context["inventory"]["fixed_controls"]
    if any(p["model_id"] != "strategy_parameterized" for p in profiles):
        _fail("Campaign simulation participants must all use the strategic model.")
    expected = 35 if round_number == 1 else 30
    if len(profiles) != expected:
        _fail("Unexpected participant inventory for elimination round.")
    if round_number == 2:
        profiles = _shuffle_round_two_profiles(profiles, context["config"]["campaign_id"], context["config"]["schedule_seeds"][1])
    block = _base_block(len(profiles), context["config"]["schedule_seeds"][round_number - 1])
    tables = [[profiles[(index + translation) % len(profiles)]["profile_id"] for index in block] for translation in range(len(profiles))]
    repetitions = context["config"]["round_repetitions"][round_number - 1]
    manifest = _manifest(context, profiles, tables, f"round{round_number}", len(tables) * repetitions)
    audit_manifest(manifest, [p["profile_id"] for p in profiles])
    return manifest


@schema_boundary
def audit_manifest(manifest: dict[str, Any], expected_profile_ids: Iterable[str] | None = None) -> dict[str, Any]:
    """Certify planned appearances, actual table pairs and cyclic seat counts."""
    context = _validate_manifest(manifest)
    profiles = context["profiles"]
    if any(p["model_id"] != "strategy_parameterized" for p in profiles.values()):
        _fail("Campaign simulation participants must all use the strategic model.")
    expected = list(profiles) if expected_profile_ids is None else list(expected_profile_ids)
    if len(set(expected)) != len(expected) or set(expected) != set(profiles):
        _fail("Manifest participants differ from the expected profile identities.")
    if len(profiles) < 9 or len(context["plans"]) != 1 or len(context["regimes"]) != 1:
        _fail("Campaign round audits require one nine-player regime and one plan.")
    regime = next(iter(context["regimes"].values()))
    if regime["player_count"] != 9:
        _fail("Every campaign tournament must start with nine players.")
    plan = next(iter(context["plans"].values()))
    identifiers = plan["matchup_ids"]
    if len(set(identifiers)) != len(identifiers) or set(identifiers) != set(context["matchups"]):
        _fail("Every declared table must occur exactly once in the round's plan.")
    table_count = len(identifiers)
    if table_count != len(profiles):
        _fail("A round must contain exactly one nine-player matchup per participant.")
    if plan["tournament_count"] % (table_count * 9):
        _fail("Each scheduled table must have equal complete nine-seat rotations.")
    repetitions = plan["tournament_count"] // table_count
    appearances = Counter({profile_id: 0 for profile_id in profiles})
    seats = {profile_id: [0] * 9 for profile_id in profiles}
    pairs: Counter[tuple[str, str]] = Counter()
    matchup_appearances = Counter({profile_id: 0 for profile_id in profiles})
    pair_matchups: Counter[tuple[str, str]] = Counter()
    for identifier in identifiers:
        table = context["matchups"][identifier]["profile_ids"]
        if len(table) != 9 or len(set(table)) != 9:
            _fail("Every starting table must contain nine distinct profiles.")
        for profile_id in table:
            appearances[profile_id] += repetitions
            matchup_appearances[profile_id] += 1
        for rotation in range(9):
            for seat in range(9):
                seats[table[(seat + rotation) % 9]][seat] += repetitions // 9
        for pair in combinations(sorted(table), 2):
            pairs[pair] += repetitions
            pair_matchups[pair] += 1
    if len(set(appearances.values())) != 1 or not all(appearances.values()):
        _fail("Every participant must have exactly equal tournament appearances.")
    seat_counts = {value for row in seats.values() for value in row}
    if len(seat_counts) != 1 or not all(seat_counts):
        _fail("Every profile must have equal observations in every starting seat.")
    all_pairs = set(combinations(sorted(profiles), 2))
    if set(pairs) != all_pairs:
        _fail("The schedule does not cover every opponent pair.")
    if set(matchup_appearances.values()) != {9}:
        _fail("Every participant must appear in exactly nine matchups.")
    maximum_spread = 2
    if max(pair_matchups.values()) - min(pair_matchups.values()) > maximum_spread:
        _fail(f"Opponent-pair matchup frequency spread exceeds the permitted {maximum_spread} or a pair is outside the permitted counts.")
    positions = {profile_id: index for index, profile_id in enumerate(profiles)}
    first = context["matchups"][identifiers[0]]["profile_ids"]
    seed_indices = [positions[profile_id] for profile_id in first]
    order = list(profiles)
    expected_tables = {tuple(order[(index + shift) % len(order)] for index in seed_indices) for shift in range(len(order))}
    actual_tables = {tuple(context["matchups"][identifier]["profile_ids"]) for identifier in identifiers}
    if actual_tables != expected_tables:
        _fail("Matchups must be the complete cyclic shifts of one nine-player seed.")
    if sum(appearances.values()) != 9 * plan["tournament_count"]:
        _fail("Scheduled appearance totals do not reconcile.")
    return {"policy": "nine_player_schedule_audit_v3", "manifest_checksum": _simulation_manifest_checksum(manifest),
            "profile_count": len(profiles), "matchup_count": table_count,
            "tournament_count": plan["tournament_count"], "repetitions_per_table": repetitions,
            "maximum_allowed_pair_matchup_spread": maximum_spread,
            "appearances_by_profile": dict(sorted(appearances.items())),
            "matchup_appearances_by_profile": dict(sorted(matchup_appearances.items())),
            "minimum_pair_matchup_frequency": min(pair_matchups.values()),
            "maximum_pair_matchup_frequency": max(pair_matchups.values()),
            "seat_counts_by_profile": dict(sorted(seats.items())),
            "opponent_pair_count": len(pairs), "minimum_pair_frequency": min(pairs.values()),
            "maximum_pair_frequency": max(pairs.values()),
            "pair_counts": [{"profile_ids": list(pair), "matchup_count": pair_matchups[pair], "tournament_count": pairs[pair]} for pair in sorted(pairs)]}


@schema_boundary
def build_pilot_manifest(campaign: dict[str, Any], tournament_count: int = 36) -> dict[str, Any]:
    """Create a representative nine-player pilot, excluded from fair-round evidence."""
    context = validate_campaign(campaign)
    if context["stage"] == "prepared":
        _fail("Pilot requires the frozen candidate inventory.")
    require_integer(tournament_count, "pilot tournament count", 9, 10_000_000)
    if tournament_count % 9:
        _fail("Pilot counts must include complete nine-seat rotations.")
    controls = context["inventory"]["fixed_controls"]
    candidates = [r["profile"] for r in context["contenders"]]
    if len(controls) != 5 or any(p["model_id"] != "strategy_parameterized" for p in controls + candidates):
        _fail("Pilot requires five handcrafted strategic controls and strategic contenders.")
    random = SplitMix64(context["config"]["schedule_seeds"][0])
    for index in range(len(candidates) - 1, 0, -1):
        swap = random.integer(0, index)
        candidates[index], candidates[swap] = candidates[swap], candidates[index]
    profiles = controls + candidates[:4]
    return _manifest(context, profiles, [[p["profile_id"] for p in profiles]], "pilot", tournament_count)
