"""Validated common-cohort evaluation and independent confirmation preparation."""

from __future__ import annotations

import copy
import hashlib
import shlex
from pathlib import Path
from typing import Any

from .artifacts import (
    canonical_json_bytes,
    create_artifact,
    load_artifact,
    load_json_object,
)
from .contracts import (
    require_exact_fields,
    require_identifier,
    require_integer,
    validate_report_seed_range,
)
from .errors import ExitCode, ToolError
from .experiment_output import publish_documents
from .fitness import _simulation_manifest_checksum, _validate_manifest
from .lineage import validate_lineage_registry

CONFIG_FIELDS = (
    "schema_version", "experiment_id", "registry", "benchmark_manifest",
    "candidate_ids", "legacy_ids", "historical_champion_ids", "seed_starts",
    "tournaments_per_matchup", "starting_stack", "small_blind", "big_blind",
    "reviewer_id",
)
RNG_ALGORITHM = "named_stream_sha256_v2"


def _fail(message: str, details: dict[str, Any] | None = None) -> None:
    raise ToolError("invalid_experiment", message, ExitCode.INVALID_INPUT, details)


def _ids(value: Any, name: str) -> list[str]:
    if not isinstance(value, list) or not value:
        _fail(f"{name} must be a non-empty array.")
    result = [require_identifier(item, name) for item in value]
    if len(set(result)) != len(result):
        _fail(f"{name} must not contain duplicates.")
    return result


def _snapshot(entry: dict[str, Any]) -> dict[str, Any]:
    candidate = entry["candidate"]
    return {
        "profile_id": candidate["candidate_id"],
        "model_id": candidate["model_id"],
        "parameters": copy.deepcopy(candidate["parameters"]),
    }


def load_experiment(path: Path) -> dict[str, Any]:
    config = load_json_object(path)
    require_exact_fields(config, CONFIG_FIELDS, "experiment configuration")
    require_integer(config["schema_version"], "schema_version", 1, 1)
    for field in ("experiment_id", "reviewer_id", "registry", "benchmark_manifest"):
        require_identifier(config[field], field)
    for field in ("registry", "benchmark_manifest"):
        if "\0" in config[field]:
            _fail(f"{field} must not contain a null byte.")
    for field in ("candidate_ids", "legacy_ids", "historical_champion_ids"):
        config[field] = _ids(config[field], field)
    candidates = set(config["candidate_ids"])
    legacy = set(config["legacy_ids"])
    champions = set(config["historical_champion_ids"])
    if candidates & (legacy | champions) or legacy & champions:
        _fail("Candidates, legacy opponents and historical champions must be disjoint.")
    if len(legacy | champions) > 8:
        _fail("Mixed confirmation supports at most eight declared benchmark opponents.")
    count = require_integer(
        config["tournaments_per_matchup"], "tournaments_per_matchup", 300, 2**31 - 1
    )
    for field in ("starting_stack", "small_blind", "big_blind"):
        require_integer(config[field], field, 1, 1_000_000)
    if config["small_blind"] > config["big_blind"]:
        _fail("small_blind cannot exceed big_blind.")
    starts = config["seed_starts"]
    if not isinstance(starts, dict):
        _fail("seed_starts must be an object.")
    require_exact_fields(
        starts, ("evaluation", "mirrored", "mixed"), "experiment seed starts"
    )
    for value in starts.values():
        validate_report_seed_range(
            {"minimum": value, "maximum": value}, "experiment seed"
        )
    registry_artifact = load_artifact(path.parent / config["registry"], "lineage_registry")
    registry = validate_lineage_registry(registry_artifact)
    benchmark = load_json_object(path.parent / config["benchmark_manifest"])
    profiles = _validate_manifest(benchmark)["profiles"]
    entries = registry["entries"]
    for identifier in config["candidate_ids"] + config["historical_champion_ids"]:
        if identifier not in entries:
            _fail(f"Candidate or champion '{identifier}' is absent from the registry.")
    for identifier in config["candidate_ids"]:
        if entries[identifier]["creation_context"]["artifact_type"] != "generation_manifest":
            _fail(
                f"Candidate '{identifier}' comes from a candidate_batch; mutate it "
                "into a generation_manifest before evaluating it."
            )
    for identifier in config["legacy_ids"] + config["historical_champion_ids"]:
        if identifier not in profiles:
            _fail(f"Benchmark snapshot '{identifier}' is absent from benchmark_manifest.")
    for identifier in config["historical_champion_ids"]:
        if not entries[identifier]["selection_history"]:
            _fail(f"Historical champion '{identifier}' requires selection history.")
        if profiles[identifier] != _snapshot(entries[identifier]):
            _fail(f"Historical champion snapshot '{identifier}' contradicts its lineage.")
    return {
        "config": config,
        "registry_artifact": registry_artifact,
        "entries": entries,
        "benchmark": benchmark,
        "profiles": profiles,
        "sample_target": count,
    }


def _round_up(count: int, seats: int) -> int:
    return ((count + seats - 1) // seats) * seats


def _manifest(
    context: dict[str, Any],
    mode: str,
    profiles: list[dict[str, Any]],
    matchups: list[list[str]],
    seed: int,
    samples: int,
    suffix: str = "",
) -> dict[str, Any]:
    config = context["config"]
    seats = len(matchups[0])
    result = {
        "schema_version": 2,
        "batch_id": f"{config['experiment_id']}_{mode}{suffix}",
        "seed_start": seed,
        "profiles": copy.deepcopy(profiles),
        "regimes": [{
            "regime_id": "experiment_regime",
            "player_count": seats,
            "starting_stack": config["starting_stack"],
            "starting_small_blind": config["small_blind"],
            "starting_big_blind": config["big_blind"],
            "blind_progression": "normative_hand_based_v1",
        }],
        "matchups": [
            {"matchup_id": f"matchup_{index:04d}", "profile_ids": ids}
            for index, ids in enumerate(matchups)
        ],
        "evaluation_plans": [{
            "plan_id": mode,
            "regime_id": "experiment_regime",
            "matchup_ids": [f"matchup_{index:04d}" for index in range(len(matchups))],
            "tournament_count": len(matchups) * samples,
            "minimum_profile_samples": context["sample_target"],
            "seat_rotation": "cyclic",
            "uncertainty_estimator": "normal_95",
        }],
    }
    _validate_manifest(result)
    return result


def experiment_manifests(
    context: dict[str, Any],
) -> tuple[dict[str, dict[str, Any]], list[str]]:
    config = context["config"]
    benchmarks = config["legacy_ids"] + config["historical_champion_ids"]
    opponents = [context["profiles"][identifier] for identifier in benchmarks]
    snapshots = [
        _snapshot(context["entries"][identifier])
        for identifier in config["candidate_ids"]
    ]
    heads_up = _round_up(context["sample_target"], 2)
    mixed_seats = len(benchmarks) + 1
    mixed_count = _round_up(
        max(context["sample_target"], 100 * mixed_seats), mixed_seats
    )
    evaluation = _manifest(
        context, "evaluation", snapshots + opponents,
        [[candidate["profile_id"], opponent]
         for candidate in snapshots for opponent in benchmarks],
        config["seed_starts"]["evaluation"], heads_up,
    )
    manifests = {"evaluation_manifest.json": evaluation}
    for index, candidate in enumerate(snapshots):
        prefix = f"candidate_{index:04d}"
        manifests[f"{prefix}_mirrored_manifest.json"] = _manifest(
            context, "mirrored", [candidate] + opponents,
            [[candidate["profile_id"], opponent] for opponent in benchmarks],
            config["seed_starts"]["mirrored"] + index * len(benchmarks) * heads_up,
            heads_up, f"_{index:04d}",
        )
        manifests[f"{prefix}_mixed_manifest.json"] = _manifest(
            context, "mixed", [candidate] + opponents,
            [[candidate["profile_id"]] + benchmarks],
            config["seed_starts"]["mixed"] + index * mixed_count,
            mixed_count, f"_{index:04d}",
        )
    ranges = []
    for name, manifest in manifests.items():
        count = manifest["evaluation_plans"][0]["tournament_count"]
        ranges.append((name, manifest["seed_start"], manifest["seed_start"] + count - 1))
    issues = []
    for index, (name, lower, upper) in enumerate(ranges):
        for other, other_lower, other_upper in ranges[:index]:
            if lower <= other_upper and other_lower <= upper:
                issues.append(f"Seed blocks overlap: {other} and {name}.")
    for candidate_id in config["candidate_ids"]:
        for evaluation in context["entries"][candidate_id]["evaluations"]:
            for evidence in evaluation["report_evidence"]:
                algorithm = evidence["execution_provenance"]["algorithm_versions"]["rng_streams"]
                if algorithm != RNG_ALGORITHM:
                    issues.append(
                        f"{candidate_id}: prior evaluation RNG {algorithm} is incompatible "
                        f"with {RNG_ALGORITHM}; retain history and prepare a compatible lineage input."
                    )
                prior = evidence["seed_range"]
                for name, lower, upper in ranges:
                    if lower <= prior["maximum"] and prior["minimum"] <= upper:
                        issues.append(
                            f"{candidate_id}: {name} overlaps a prior evaluation seed range."
                        )
    return manifests, sorted(set(issues))


def _command(*arguments: object) -> str:
    return shlex.join([str(item) for item in arguments])


def experiment_commands(
    context: dict[str, Any], directory: Path, manifests: dict[str, Any]
) -> list[str]:
    commands = []
    godot = [
        "godot", "--headless", "--path", ".", "--script",
        "res://scripts/simulation/simulation_cli_app.gd", "--",
    ]
    for name in manifests:
        commands.append(_command(
            *godot, "validate", "--config", directory / name, "--format", "json"
        ))
        commands.append(_command(
            *godot, "run", "--config", directory / name, "--output",
            directory / name.replace("_manifest", "_report"), "--format", "json",
        ))
    comparison_dir = directory / "comparison"
    commands.append(_command(
        "tools/profile-evolution", "compare-experiment", "--config",
        directory / "config.json", "--report", directory / "evaluation_report.json",
        "--output-dir", comparison_dir,
    ))
    config = context["config"]
    confirmations = []
    for index, candidate_id in enumerate(config["candidate_ids"]):
        prefix = f"candidate_{index:04d}"
        confirmation = directory / f"{prefix}_confirmation.json"
        confirmations.append(confirmation)
        command = [
            "tools/profile-evolution", "confirm-candidate", "--registry",
            comparison_dir / "evaluated_registry.json", "--candidate-id", candidate_id,
        ]
        opponent_options = (
            ("--legacy-id", "legacy_ids"),
            ("--historical-champion-id", "historical_champion_ids"),
        )
        for option, field in opponent_options:
            for identifier in config[field]:
                command.extend([option, identifier])
        command.extend([
            "--mirrored-report", directory / f"{prefix}_mirrored_report.json",
            "--mixed-report", directory / f"{prefix}_mixed_report.json",
            "--output", confirmation,
        ])
        commands.append(_command(*command))
    review = [
        "tools/profile-evolution", "prepare-promotion-review", "--reviewer-id",
        config["reviewer_id"],
    ]
    for confirmation in confirmations:
        review.extend(["--confirmation", confirmation])
    commands.append(_command(*review, "--output", directory / "promotion_review_plan.json"))
    return commands


def prepare_experiment(
    config_path: Path, output_dir: Path, dry_run: bool = False
) -> dict[str, Any]:
    context = load_experiment(config_path)
    manifests, issues = experiment_manifests(context)
    directory = output_dir.absolute()
    if directory.exists() or directory.is_symlink():
        issues.append(f"Output directory already exists: {directory}.")
    if not directory.parent.is_dir():
        issues.append(f"Output parent directory does not exist: {directory.parent}.")
    snapshot_config = copy.deepcopy(context["config"])
    snapshot_config["registry"] = "input_registry.json"
    snapshot_config["benchmark_manifest"] = "benchmark_manifest.json"
    documents = {
        "config.json": snapshot_config,
        "input_registry.json": context["registry_artifact"],
        "benchmark_manifest.json": context["benchmark"],
        **manifests,
    }
    summaries = []
    for name, manifest in manifests.items():
        count = manifest["evaluation_plans"][0]["tournament_count"]
        summaries.append({
            "path": name,
            "checksum": _simulation_manifest_checksum(manifest),
            "seed_range": {
                "minimum": manifest["seed_start"],
                "maximum": manifest["seed_start"] + count - 1,
            },
            "tournament_count": count,
        })
    plan = create_artifact("experiment_plan", {
        "config_checksum": hashlib.sha256(canonical_json_bytes(snapshot_config)).hexdigest(),
        "source_config_checksum": hashlib.sha256(
            canonical_json_bytes(context["config"])
        ).hexdigest(),
        "registry_checksum": context["registry_artifact"]["checksum"],
        "benchmark_manifest_checksum": _simulation_manifest_checksum(context["benchmark"]),
        "artifacts": list(documents) + ["experiment.json"],
        "commands": experiment_commands(context, directory, manifests),
        "manifests": summaries,
        "incompatibilities": issues,
        "review_required": True,
    })
    if dry_run:
        return plan
    if issues:
        _fail("Experiment preparation is incompatible.", {"incompatibilities": issues})
    publish_documents(directory, documents, "experiment.json", plan)
    return plan
