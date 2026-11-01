#!/usr/bin/env python3
"""Validate and compare matched BFCR cohorts using preregistered acceptance margins."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import sys

BENCHMARK = "res://tests/support/bot_raise_response_benchmark.gd"


def _integer(value: object, name: str, minimum: int = 0, maximum: int | None = None) -> int:
    if type(value) is not int or value < minimum or (maximum is not None and value > maximum):
        raise ValueError(f"Invalid integer: {name}")
    return value


def _number(value: object, name: str, minimum: float = 0.0, maximum: float | None = None) -> float:
    if type(value) not in (float, int) or not math.isfinite(value) or value < minimum:
        raise ValueError(f"Invalid finite number: {name}")
    if maximum is not None and value > maximum:
        raise ValueError(f"Out-of-range number: {name}")
    return float(value)


def summarize_responses(rows: list[dict]) -> dict:
    """Reconstruct the frozen GDScript collector's strata from individual observations."""
    groups: dict = {}
    for row in rows:
        keys = (
            "all", "profile:" + row["profile"], "street:" + row["street"],
            "prior:" + row["previous_branch"], "cheap" if row["cheap"] else "other_price",
            "expensive" if row["expensive"] else "not_expensive",
            "weak" if row["weak"] else "nonweak", f"opponents:{row['opponents']}",
            "pressure:high" if row["stack_pressure"] >= 0.25 else "pressure:low",
            "cheap_nonweak" if row["cheap"] and not row["weak"] else "outside_cheap_nonweak",
            "cheap_weak" if row["cheap"] and row["weak"] else "outside_cheap_weak",
        )
        for key in keys:
            group = groups.setdefault(key, {"opportunities": 0, "FOLD": 0, "CALL": 0, "RAISE": 0, "other": 0})
            group["opportunities"] += 1
            action = row["action"]
            group[action if action in ("FOLD", "CALL", "RAISE") else "other"] += 1
    for group in groups.values():
        n = group["opportunities"]
        proportion = group["FOLD"] / n
        denominator = 1 + 3.8416 / n
        center = (proportion + 1.9208 / n) / denominator
        half = 1.96 * math.sqrt(proportion * (1 - proportion) / n + 0.9604 / (n * n)) / denominator
        group["fold_rate"] = proportion
        group["fold_wilson95"] = [max(0, center - half), min(1, center + half)]
    return groups


def validate_report(report: dict) -> None:
    """Reject inconsistent evidence before any acceptance decision is calculated."""
    if not isinstance(report, dict) or report.get("schema") != "bfcr_behavior_v1":
        raise ValueError("Unsupported BFCR report")
    tournaments = report.get("tournaments")
    if not isinstance(tournaments, list) or len(tournaments) != 180:
        raise ValueError("Acceptance requires all 180 tournaments in each cohort")
    profile_hashes = report.get("profile_hashes")
    if not isinstance(profile_hashes, dict) or len(profile_hashes) != 15:
        raise ValueError("Acceptance requires all 15 strategic profile snapshots")
    for profile, fingerprint in profile_hashes.items():
        if (not isinstance(profile, str) or not profile or not isinstance(fingerprint, str)
                or len(fingerprint) != 64 or any(char not in "0123456789abcdef" for char in fingerprint)):
            raise ValueError("Invalid profile identity or fingerprint")
    source_hashes = report.get("source_hashes")
    if not isinstance(source_hashes, dict) or not source_hashes.get(BENCHMARK):
        raise ValueError("Benchmark source fingerprint is required")
    for path, fingerprint in source_hashes.items():
        if (not isinstance(path, str) or not path or not isinstance(fingerprint, str)
                or len(fingerprint) != 64 or any(char not in "0123456789abcdef" for char in fingerprint)):
            raise ValueError("Invalid source identity or fingerprint")
    _integer(report.get("seed_start"), "seed_start", 1, 2**63 - 180)
    _number(report.get("runtime_seconds"), "runtime_seconds", 0.000000001)
    counters = ("decisions", "long_chains", "repeated_weak_bluffs", "invalid_actions")
    totals = {field: 0 for field in counters}
    for index, tournament in enumerate(tournaments):
        if not isinstance(tournament, dict):
            raise ValueError("Invalid tournament observation")
        count = _integer(tournament.get("player_count"), "player_count", 2, 9)
        stack = _integer(tournament.get("starting_stack"), "starting_stack", 1, 1000000)
        if _integer(tournament.get("seed"), "seed", 1) != report["seed_start"] + index:
            raise ValueError("Tournament seeds must match the cohort's frozen ordering")
        if type(tournament.get("mirrored")) is not bool or type(tournament.get("completed")) is not bool:
            raise ValueError("Tournament flags must be booleans")
        if not isinstance(tournament.get("error"), str):
            raise ValueError("Tournament error must be text")
        _integer(tournament.get("hands"), "hands", 1)
        _integer(tournament.get("winner"), "winner", 0 if tournament["completed"] else -1, count - 1)
        assignments = tournament.get("seat_profiles")
        if not isinstance(assignments, list) or len(assignments) != count or any(profile not in profile_hashes for profile in assignments):
            raise ValueError("Invalid seat-to-profile assignments")
        _integer(tournament.get("chip_total"), "chip_total")
        if _integer(tournament.get("expected_chip_total"), "expected_chip_total", 1) != count * stack:
            raise ValueError("Expected chip total disagrees with tournament configuration")
        for field in counters:
            totals[field] += _integer(tournament.get(field), field, 1 if field == "decisions" else 0)
        _integer(tournament.get("fallback_folds"), "fallback_folds", 0, tournament["invalid_actions"])
        if any(tournament[field] > tournament["decisions"] for field in counters[1:]):
            raise ValueError("Tournament action counters exceed observed decisions")
    assigned_profiles = {profile for tournament in tournaments for profile in tournament["seat_profiles"]}
    if assigned_profiles != profile_hashes.keys():
        raise ValueError("Every fingerprinted profile must appear in the cohort")
    for field in counters:
        if _integer(report.get(field), field) != totals[field]:
            raise ValueError(f"Top-level {field} counter disagrees with tournament totals")
    branches = report.get("branches")
    if (not isinstance(branches, dict) or not branches
            or any(not isinstance(key, str) or not key for key in branches)
            or sum(_integer(value, "branch count", 1) for value in branches.values()) != report["decisions"]):
        raise ValueError("Branch counts must cover all observed decisions")
    rows = report.get("responses")
    if not isinstance(rows, list):
        raise ValueError("Response observations are required")
    per_tournament = Counter()
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("Invalid response observation")
        index = _integer(row.get("tournament"), "response tournament", 0, len(tournaments) - 1)
        tournament = tournaments[index]
        seat = _integer(row.get("seat"), "response seat", 0, tournament["player_count"] - 1)
        if row.get("profile") != tournament["seat_profiles"][seat]:
            raise ValueError("Response profile disagrees with its assigned seat")
        _integer(row.get("hand"), "response hand", 1, tournament["hands"])
        _integer(row.get("opponents"), "response opponents", 1, tournament["player_count"] - 1)
        if row.get("street") not in ("preflop", "flop", "turn", "river"):
            raise ValueError("Invalid response street")
        if row.get("action") not in ("FOLD", "CHECK", "CALL", "BET", "RAISE", "ALL_IN"):
            raise ValueError("Invalid response action")
        if any(not isinstance(row.get(field), str) or not row[field] for field in ("branch", "previous_branch")):
            raise ValueError("Response branches are required")
        score = _integer(row.get("score"), "response score", 0, 100)
        call = _integer(row.get("call"), "response call", 1)
        pot = _integer(row.get("pot"), "response pot")
        remaining = _integer(row.get("stack"), "response stack", call)
        price = _number(row.get("call_price"), "response call_price", 0, 1)
        pressure = _number(row.get("stack_pressure"), "response stack_pressure", 0, 1)
        threshold = _number(row.get("legacy_threshold"), "response legacy_threshold", -100, 200)
        if not math.isclose(price, call / (pot + call), rel_tol=1e-12, abs_tol=1e-12):
            raise ValueError("Response call price disagrees with raw chip amounts")
        if not math.isclose(pressure, call / (remaining + call), rel_tol=1e-12, abs_tol=1e-12):
            raise ValueError("Response stack pressure disagrees with raw chip amounts")
        for field, expected in (("cheap", price <= 0.20), ("expensive", price >= 0.40), ("weak", score < 30), ("threshold_crossing", score < threshold)):
            if type(row.get(field)) is not bool or row[field] != expected:
                raise ValueError(f"Inconsistent response classification: {field}")
        per_tournament[index] += 1
    if len(rows) > report["decisions"]:
        raise ValueError("Response observations exceed total decisions")
    for index, tournament in enumerate(tournaments):
        if per_tournament[index] > tournament["decisions"]:
            raise ValueError("Responses exceed their tournament decision count")
        if "response_count" in tournament and _integer(tournament["response_count"], "response_count") != per_tournament[index]:
            raise ValueError("Tournament response count disagrees with observations")
    if "response_count" in report and _integer(report["response_count"], "response_count") != len(rows):
        raise ValueError("Response count disagrees with observations")
    reconstructed = summarize_responses(rows)
    claimed = report.get("response_summary")
    if not isinstance(claimed, dict) or claimed.keys() != reconstructed.keys():
        raise ValueError("Claimed response summary groups disagree with raw observations")
    for key, expected in reconstructed.items():
        group = claimed[key]
        if not isinstance(group, dict):
            raise ValueError("Invalid response summary group")
        for field in ("opportunities", "FOLD", "CALL", "RAISE", "other"):
            if _integer(group.get(field), f"{key}:{field}") != expected[field]:
                raise ValueError("Claimed response summary counts disagree with raw observations")
        rate = _number(group.get("fold_rate"), "fold_rate", 0, 1)
        interval = group.get("fold_wilson95")
        if not math.isclose(rate, expected["fold_rate"], rel_tol=1e-12, abs_tol=1e-12):
            raise ValueError("Claimed fold rate disagrees with raw observations")
        if not isinstance(interval, list) or len(interval) != 2:
            raise ValueError("Invalid Wilson interval")
        for actual, bound in zip(interval, expected["fold_wilson95"]):
            if not math.isclose(_number(actual, "Wilson bound", 0, 1), bound, rel_tol=1e-12, abs_tol=1e-12):
                raise ValueError("Claimed interval disagrees with raw observations")


def load_report(path: Path) -> dict:
    report = json.loads(path.read_text())
    validate_report(report)
    return report


def _profile_outcomes(report: dict) -> dict:
    outcomes: dict = {}
    for tournament in report["tournaments"]:
        for seat, profile in enumerate(tournament["seat_profiles"]):
            row = outcomes.setdefault(profile, {"appearances": 0, "wins": 0})
            row["appearances"] += 1
            row["wins"] += tournament["winner"] == seat
    for profile, row in outcomes.items():
        responses = [item for item in report["responses"] if item["profile"] == profile]
        row["responses"] = len(responses)
        row["response_actions"] = dict(Counter(item["action"] for item in responses))
    return outcomes


def _valid_tournaments(report: dict) -> bool:
    return all(
        row["completed"] and not row["error"] and row["chip_total"] == row["expected_chip_total"]
        and row["invalid_actions"] == 0 and row["fallback_folds"] == 0
        for row in report["tournaments"]
    )


def compare(baseline: dict, candidate: dict) -> dict:
    validate_report(baseline)
    validate_report(candidate)
    if baseline["seed_start"] != candidate["seed_start"]:
        raise ValueError("Baseline and candidate must use the same cohort seeds")
    if baseline["profile_hashes"] != candidate["profile_hashes"]:
        raise ValueError("Profile snapshots changed between matched cohorts")
    if baseline["source_hashes"][BENCHMARK] != candidate["source_hashes"][BENCHMARK]:
        raise ValueError("Benchmark source changed between matched cohorts")
    identity_fields = ("seed", "player_count", "starting_stack", "mirrored", "seat_profiles")
    if len(baseline["tournaments"]) != len(candidate["tournaments"]):
        raise ValueError("Tournament cohort sizes changed")
    for old, new in zip(baseline["tournaments"], candidate["tournaments"]):
        if any(old[field] != new[field] for field in identity_fields):
            raise ValueError("Tournament seed, regime or seat assignments changed")
    old_cheap = baseline["response_summary"].get("cheap_nonweak")
    new_cheap = candidate["response_summary"].get("cheap_nonweak")
    if not old_cheap or not new_cheap:
        raise ValueError("Both cohorts need observed cheap nonweak response opportunities")
    checks = {
        "all_tournaments_complete_and_conserve_chips": _valid_tournaments(candidate),
        "zero_invalid_actions": candidate["invalid_actions"] == 0,
        "zero_repeated_weak_bluffs": candidate["repeated_weak_bluffs"] == 0,
        "raise_chains_at_least_50_percent_lower": candidate["long_chains"] <= baseline["long_chains"] * 0.5,
        "cheap_nonweak_fold_rate_lower": new_cheap["fold_rate"] < old_cheap["fold_rate"],
        "runtime_no_more_than_three_times_baseline": candidate["runtime_seconds"] <= baseline["runtime_seconds"] * 3,
        "controlled_value_response_calls": (
            [row["action"] for row in candidate["controlled_value"]] == ["RAISE", "RAISE", "CALL"]
            and candidate["controlled_value"][0]["branch"] == "continue_aggressive"
            and candidate["controlled_value"][1]["branch"] == "scripted_min_raise"
        ),
        "controlled_weak_response_folds": (
            candidate["controlled_published"][0]["branch"] == "bluff_raise"
            and candidate["controlled_published"][-1]["action"] == "FOLD"
        ),
    }
    return {
        "schema": "bfcr_comparison_v1", "passed": all(checks.values()), "checks": checks,
        "seed_start": baseline["seed_start"],
        "baseline_decisions": baseline["decisions"], "candidate_decisions": candidate["decisions"],
        "baseline_chains": baseline["long_chains"], "candidate_chains": candidate["long_chains"],
        "baseline_repeated_weak_bluffs": baseline["repeated_weak_bluffs"],
        "candidate_repeated_weak_bluffs": candidate["repeated_weak_bluffs"],
        "baseline_runtime_seconds": baseline["runtime_seconds"],
        "candidate_runtime_seconds": candidate["runtime_seconds"],
        "baseline_strata": baseline["response_summary"], "candidate_strata": candidate["response_summary"],
        "baseline_profile_outcomes": _profile_outcomes(baseline),
        "candidate_profile_outcomes": _profile_outcomes(candidate),
        "limits": [
            "Actions within a tournament are correlated; Wilson intervals describe observed opportunity proportions, not independent tournament uncertainty.",
            "Policy changes alter reached states, so equal seeds do not yield equal response populations.",
            "Expensive-call tournament strata are descriptive; fixed matched decision tests protect that boundary.",
            "Win counts describe this mixed-roster cohort and do not establish playing-strength superiority.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    options = parser.parse_args()
    try:
        result = compare(load_report(options.baseline), load_report(options.candidate))
        result["report_sha256"] = {
            "baseline": hashlib.sha256(options.baseline.read_bytes()).hexdigest(),
            "candidate": hashlib.sha256(options.candidate.read_bytes()).hexdigest(),
        }
        options.output.parent.mkdir(parents=True, exist_ok=True)
        with options.output.open("x") as stream:
            json.dump(result, stream, indent=2, allow_nan=False)
            stream.write("\n")
    except (OSError, ValueError, KeyError, TypeError, IndexError) as error:
        print(f"Cannot compare BFCR reports: {error}", file=sys.stderr)
        return 1
    for name, passed in result["checks"].items():
        print(f"{'PASS' if passed else 'FAIL'} {name}")
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
