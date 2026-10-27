"""Command-line contract for the external profile-evolution workflow."""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path
from typing import NoReturn, Sequence

from .artifacts import (
    canonical_json_bytes,
    load_artifact,
    load_json_object,
    validate_artifact_envelope,
    write_artifact_atomic,
)
from .confirmation import confirm_candidate
from .contracts import (
    validate_bounds,
    validate_candidate_collection,
    validate_mutation_policy,
    validate_selection,
)
from .errors import ExitCode, ToolError
from .evolution import crossover_candidates, initialize_generation, mutate_candidates
from .export import export_candidates
from .fitness import evaluate_fitness
from .experiment import prepare_experiment
from .experiment_comparison import compare_experiment
from .lineage import build_lineage_registry, inspect_lineage
from .promotion_review import (
    create_promotion_review,
    create_promotion_review_plan,
    finalize_promotion_review,
    write_promotion_review_plan_atomic,
)
from .profile_publisher import publish_approved_profile
from .selection import select_elites


class StrictArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> NoReturn:
        raise ToolError("invalid_arguments", message, ExitCode.INVALID_INPUT)


def _positive_integer(value: str) -> int:
    try:
        result = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("must be an integer") from error
    if result <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return result


def _seed(value: str) -> int:
    try:
        result = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("must be an integer") from error
    if result < 0 or result > (1 << 64) - 1:
        raise argparse.ArgumentTypeError("must be in the inclusive range 0..2^64-1")
    return result


def _elite_fraction(value: str) -> float:
    try:
        result = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("must be a number") from error
    if not math.isfinite(result) or not 0.10 <= result <= 0.20:
        raise argparse.ArgumentTypeError("must be between 0.10 and 0.20 inclusive")
    return result


def _artifact_output_path(value: str) -> Path:
    path = Path(value)
    if path.suffix.lower() != ".json":
        raise argparse.ArgumentTypeError("must be a .json artifact path")
    if "roster" in path.name.lower():
        raise argparse.ArgumentTypeError("must not target a playable roster")
    return path


def build_parser() -> argparse.ArgumentParser:
    parser = StrictArgumentParser(
        prog="profile-evolution",
        description="Create immutable profile-evolution workflow artifacts.",
    )
    commands = parser.add_subparsers(dest="command", required=True)

    prepare = commands.add_parser("prepare-experiment")
    prepare.add_argument("--config", required=True, type=Path)
    prepare.add_argument("--output-dir", required=True, type=Path)
    prepare.add_argument("--dry-run", action="store_true")

    compare = commands.add_parser("compare-experiment")
    compare.add_argument("--config", required=True, type=Path)
    compare.add_argument("--report", required=True, action="append", type=Path)
    compare.add_argument("--output-dir", required=True, type=Path)

    init = commands.add_parser("init-generation")
    init.add_argument("--bounds", required=True, type=Path)
    init.add_argument("--population-size", required=True, type=_positive_integer)
    init.add_argument("--seed", required=True, type=_seed)
    init.add_argument("--output", required=True, type=_artifact_output_path)

    evaluate = commands.add_parser("evaluate-fitness")
    evaluate.add_argument("--generation", required=True, type=Path)
    evaluate.add_argument("--report", required=True, action="append", type=Path)
    evaluate.add_argument("--output", required=True, type=_artifact_output_path)

    select = commands.add_parser("select")
    select.add_argument("--fitness", required=True, type=Path)
    select.add_argument("--elite-fraction", required=True, type=_elite_fraction)
    select.add_argument("--output", required=True, type=_artifact_output_path)

    crossover = commands.add_parser("crossover")
    crossover.add_argument("--selection", required=True, type=Path)
    crossover.add_argument("--seed", required=True, type=_seed)
    crossover.add_argument("--target-count", required=True, type=_positive_integer)
    crossover.add_argument("--output", required=True, type=_artifact_output_path)

    mutate = commands.add_parser("mutate")
    mutate.add_argument("--input", required=True, type=Path)
    mutate.add_argument("--seed", required=True, type=_seed)
    mutate.add_argument("--policy", required=True, type=Path)
    mutate.add_argument("--output", required=True, type=_artifact_output_path)

    lineage = commands.add_parser("build-lineage")
    lineage.add_argument("--artifact", required=True, action="append", type=Path)
    lineage.add_argument("--output", required=True, type=_artifact_output_path)

    inspect = commands.add_parser("inspect-lineage")
    inspect.add_argument("--registry", required=True, type=Path)
    inspect.add_argument("--candidate-id", required=True)

    confirm = commands.add_parser("confirm-candidate")
    confirm.add_argument("--registry", required=True, type=Path)
    confirm.add_argument("--candidate-id", required=True)
    confirm.add_argument("--legacy-id", required=True, action="append")
    confirm.add_argument("--historical-champion-id", required=True, action="append")
    confirm.add_argument("--mirrored-report", required=True, action="append", type=Path)
    confirm.add_argument("--mixed-report", required=True, action="append", type=Path)
    confirm.add_argument("--output", required=True, type=_artifact_output_path)

    review = commands.add_parser("review-promotion")
    review.add_argument("--confirmation", required=True, type=Path)
    review.add_argument("--reviewer-id", required=True)
    review.add_argument("--approve", action="store_true")
    review.add_argument("--reject", action="store_true")
    review.add_argument("--note", default="")
    review.add_argument("--output", required=True, type=_artifact_output_path)

    prepare_review = commands.add_parser("prepare-promotion-review")
    prepare_review.add_argument(
        "--confirmation", required=True, action="append", type=Path
    )
    prepare_review.add_argument("--reviewer-id", required=True)
    prepare_review.add_argument("--output", required=True, type=_artifact_output_path)

    finalize_review = commands.add_parser("finalize-promotion-review")
    finalize_review.add_argument("--plan", required=True, type=Path)
    finalize_review.add_argument(
        "--confirmation", required=True, action="append", type=Path
    )
    finalize_review.add_argument("--output", required=True, type=_artifact_output_path)

    publish = commands.add_parser("publish-profile")
    publish.add_argument("--confirmation", required=True, type=Path)
    publish.add_argument("--review", required=True, type=Path)
    publish.add_argument("--version", required=True)
    publish.add_argument("--display-name")
    publish.add_argument("--project-root", type=Path, default=Path("."))

    export = commands.add_parser("export-candidates")
    export.add_argument("--registry", required=True, type=Path)
    export.add_argument("--confirmation", required=True, action="append", type=Path)
    export.add_argument("--candidate-id", required=True, action="append")
    export.add_argument("--output", required=True, type=_artifact_output_path)
    return parser


def _write_result(path: Path, artifact: dict[str, object]) -> None:
    write_artifact_atomic(path, artifact)
    completion = {
        "checksum": artifact["checksum"],
        "output": str(path),
        "type": artifact["type"],
    }
    sys.stdout.write(canonical_json_bytes(completion).decode("utf-8"))


def _load_configuration(path: Path, artifact_type: str) -> dict[str, object]:
    """Accept a strict raw configuration object or its checksummed envelope."""
    document = load_json_object(path)
    if "type" in document or "payload" in document or "checksum" in document:
        validate_artifact_envelope(document, artifact_type)
        return document["payload"]
    return document


def run(arguments: argparse.Namespace) -> None:
    if arguments.command == "prepare-experiment":
        result = prepare_experiment(arguments.config, arguments.output_dir, arguments.dry_run)
        sys.stdout.write(canonical_json_bytes(result).decode("utf-8"))
        if result["payload"]["incompatibilities"]:
            raise ToolError(
                "incompatible_experiment",
                "Dry-run found incompatibilities; no files were written.",
                ExitCode.INVALID_INPUT,
                {"incompatibilities": result["payload"]["incompatibilities"]},
            )
        return
    if arguments.command == "compare-experiment":
        result = compare_experiment(arguments.config, arguments.report, arguments.output_dir)
        completion = {
            "type": result["type"],
            "checksum": result["checksum"],
            "output": str(arguments.output_dir / "comparison.json"),
        }
        sys.stdout.write(canonical_json_bytes(completion).decode("utf-8"))
        return
    if arguments.command == "init-generation":
        bounds = validate_bounds(_load_configuration(arguments.bounds, "gene_bounds"))
        _write_result(
            arguments.output,
            initialize_generation(bounds, arguments.population_size, arguments.seed),
        )
        return
    if arguments.command == "evaluate-fitness":
        generation_artifact = load_artifact(arguments.generation, "generation_manifest")
        _write_result(
            arguments.output,
            evaluate_fitness(generation_artifact, arguments.report),
        )
        return
    if arguments.command == "select":
        fitness_artifact = load_artifact(arguments.fitness, "fitness")
        _write_result(
            arguments.output,
            select_elites(fitness_artifact, arguments.elite_fraction),
        )
        return
    if arguments.command == "build-lineage":
        artifacts = [load_artifact(path) for path in arguments.artifact]
        _write_result(arguments.output, build_lineage_registry(artifacts))
        return
    if arguments.command == "inspect-lineage":
        registry = load_artifact(arguments.registry, "lineage_registry")
        sys.stdout.write(
            canonical_json_bytes(inspect_lineage(registry, arguments.candidate_id)).decode(
                "utf-8"
            )
        )
        return
    if arguments.command == "crossover":
        selection_artifact = load_artifact(arguments.selection, "selection")
        selection = validate_selection(selection_artifact["payload"])
        _write_result(
            arguments.output,
            crossover_candidates(selection, arguments.target_count, arguments.seed),
        )
        return
    if arguments.command == "mutate":
        source_artifact = load_artifact(arguments.input)
        if source_artifact["type"] not in ("generation_manifest", "candidate_batch"):
            raise ToolError(
                "unexpected_artifact_type",
                "Mutation input must be a generation_manifest or candidate_batch.",
                ExitCode.INVALID_INPUT,
            )
        source = validate_candidate_collection(source_artifact["payload"])
        policy = validate_mutation_policy(
            _load_configuration(arguments.policy, "mutation_policy")
        )
        _write_result(arguments.output, mutate_candidates(source, policy, arguments.seed))
        return
    if arguments.command == "confirm-candidate":
        registry = load_artifact(arguments.registry, "lineage_registry")
        _write_result(
            arguments.output,
            confirm_candidate(
                registry,
                arguments.candidate_id,
                arguments.legacy_id,
                arguments.historical_champion_id,
                arguments.mirrored_report,
                arguments.mixed_report,
            ),
        )
        return
    if arguments.command == "review-promotion":
        if arguments.approve == arguments.reject:
            raise ToolError(
                "invalid_review_decision",
                "Choose exactly one of --approve or --reject.",
                ExitCode.INVALID_INPUT,
            )
        confirmation = load_artifact(arguments.confirmation, "confirmation")
        _write_result(
            arguments.output,
            create_promotion_review(
                confirmation,
                arguments.reviewer_id,
                arguments.approve,
                arguments.note,
            ),
        )
        return
    if arguments.command == "prepare-promotion-review":
        confirmations = [
            load_artifact(path, "confirmation") for path in arguments.confirmation
        ]
        plan = create_promotion_review_plan(confirmations, arguments.reviewer_id)
        write_promotion_review_plan_atomic(arguments.output, plan)
        completion = {
            "candidate_count": len(plan["candidates"]),
            "output": str(arguments.output),
            "type": "promotion_review_plan",
        }
        sys.stdout.write(canonical_json_bytes(completion).decode("utf-8"))
        return
    if arguments.command == "finalize-promotion-review":
        plan = load_json_object(arguments.plan)
        confirmations = [
            load_artifact(path, "confirmation") for path in arguments.confirmation
        ]
        _write_result(
            arguments.output,
            finalize_promotion_review(plan, confirmations),
        )
        return
    if arguments.command == "publish-profile":
        confirmation = load_artifact(arguments.confirmation, "confirmation")
        review = load_artifact(arguments.review)
        result = publish_approved_profile(
            confirmation,
            review,
            arguments.project_root,
            arguments.version,
            arguments.display_name,
        )
        sys.stdout.write(canonical_json_bytes(result).decode("utf-8"))
        return
    if arguments.command == "export-candidates":
        registry = load_artifact(arguments.registry, "lineage_registry")
        confirmations = [
            load_artifact(path, "confirmation") for path in arguments.confirmation
        ]
        _write_result(
            arguments.output,
            export_candidates(registry, confirmations, arguments.candidate_id),
        )
        return
    raise ToolError(
        "not_implemented",
        f"Domain behavior for '{arguments.command}' belongs to a later Milestone 5 task.",
        ExitCode.INVARIANT_FAILURE,
        {"command": arguments.command},
    )


def main(argv: Sequence[str] | None = None) -> int:
    try:
        arguments = build_parser().parse_args(argv)
        run(arguments)
    except ToolError as error:
        sys.stderr.write(canonical_json_bytes(error.as_object()).decode("utf-8"))
        return int(error.exit_code)
    return int(ExitCode.SUCCESS)
