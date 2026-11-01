"""Noninteractive roster campaign entry point with structured failures."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Sequence

from .artifacts import canonical_json_bytes, load_artifact, load_json_object, write_artifact_atomic
from .campaign import create_campaign, default_config, validate_campaign, freeze_candidates
from .cli import StrictArgumentParser
from .errors import ToolError
from .experiment_output import publish_documents
from .historical_lineage import import_historical_lineage


def original_sources(registry_path: Path) -> list[Path]:
    """Resolve exactly the checksummed original history catalog, excluding reports."""
    registry = load_artifact(registry_path, "lineage_registry")
    wanted = {x["checksum"] for x in registry["payload"]["artifacts"]}
    found = {}
    for path in sorted(registry_path.parent.glob("*.json")):
        try:
            artifact = load_artifact(path)
        except ToolError:
            continue
        if artifact["checksum"] in wanted:
            if artifact["checksum"] in found:
                raise ToolError("duplicate_original", "Duplicate historical source checksum.", 2)
            found[artifact["checksum"]] = path
    if set(found) != wanted:
        raise ToolError("missing_original", "Historical artifact catalog is incomplete.", 2,
                        {"missing_checksums": sorted(wanted - set(found))})
    return [found[key] for key in sorted(found)]


def main(argv: Sequence[str] | None = None) -> int:
    parser = StrictArgumentParser(prog="roster-campaign")
    sub = parser.add_subparsers(dest="command", required=True)
    prepare = sub.add_parser("prepare")
    prepare.add_argument("--inventory", type=Path, required=True)
    prepare.add_argument("--historical-registry", type=Path, action="append", required=True)
    prepare.add_argument("--output-dir", type=Path, required=True)
    prepare.add_argument("--campaign-id", required=True)
    generate = sub.add_parser("generate-candidates")
    generate.add_argument("--campaign", type=Path, required=True)
    generate.add_argument("--output-dir", type=Path, required=True)
    schedule = sub.add_parser("prepare-round")
    schedule.add_argument("--campaign", type=Path, required=True)
    schedule.add_argument("--round", type=int, choices=(1, 2), default=1)
    schedule.add_argument("--previous-result", type=Path)
    schedule.add_argument("--output-dir", type=Path, required=True)
    prepare_confirmation = sub.add_parser("prepare-confirmation")
    prepare_confirmation.add_argument("--campaign", type=Path, required=True)
    prepare_confirmation.add_argument("--candidate-id", required=True)
    prepare_confirmation.add_argument("--output-dir", type=Path, required=True)
    confirm = sub.add_parser("confirm")
    confirm.add_argument("--campaign", type=Path, required=True)
    confirm.add_argument("--candidate-id", required=True)
    confirm.add_argument("--report-a", type=Path, action="append", required=True)
    confirm.add_argument("--report-b", type=Path, action="append", required=True)
    confirm.add_argument("--output", type=Path, required=True)
    run = sub.add_parser("run-round")
    run.add_argument("--manifest", type=Path, required=True)
    run.add_argument("--godot", required=True)
    run.add_argument("--approval", type=Path, required=True)
    run.add_argument("--output-dir", type=Path, required=True)
    run.add_argument("--workers", type=int, default=4)
    run.add_argument("--expected-provenance", type=Path)
    compare = sub.add_parser("compare-round")
    compare.add_argument("--campaign", type=Path, required=True)
    compare.add_argument("--readiness", type=Path, required=True)
    compare.add_argument("--round", type=int, choices=(1, 2), default=1)
    compare.add_argument("--previous-result", type=Path)
    compare.add_argument("--output-dir", type=Path, required=True)
    prepare_cohort = sub.add_parser("prepare-confirmation-cohort")
    prepare_cohort.add_argument("--campaign", type=Path, required=True)
    prepare_cohort.add_argument("--round1-result", type=Path, required=True)
    prepare_cohort.add_argument("--round2-result", type=Path, required=True)
    prepare_cohort.add_argument("--output-dir", type=Path, required=True)
    run_cohort = sub.add_parser("run-confirmation-cohort")
    run_cohort.add_argument("--plan", type=Path, required=True)
    run_cohort.add_argument("--authorization", type=Path, required=True)
    run_cohort.add_argument("--godot", required=True)
    run_cohort.add_argument("--output-dir", type=Path, required=True)
    run_cohort.add_argument("--workers", type=int, default=4)
    prepare_review = sub.add_parser("prepare-confirmation-review")
    prepare_review.add_argument("--plan", type=Path, required=True)
    prepare_review.add_argument("--readiness", type=Path, required=True)
    prepare_review.add_argument("--reviewer-id", required=True)
    prepare_review.add_argument("--output-dir", type=Path, required=True)
    inspect = sub.add_parser("validate")
    inspect.add_argument("--campaign", type=Path, required=True)
    try:
        args = parser.parse_args(argv)
        if args.command == "prepare":
            archives = [import_historical_lineage(path, original_sources(path))
                        for path in args.historical_registry]
            campaign = create_campaign(default_config(args.campaign_id), load_json_object(args.inventory), archives)
            documents = {f"archive_{i:02d}.json": archive for i, archive in enumerate(archives)}
            documents["config.json"] = campaign["payload"]["config"]
            publish_documents(args.output_dir, documents, "campaign.json", campaign)
            output = {"campaign": str(args.output_dir / "campaign.json"), "checksum": campaign["checksum"], "stage": "prepared"}
        elif args.command == "generate-candidates":
            from .campaign_generation import generate_candidates
            prepared = load_artifact(args.campaign, "roster_campaign")
            generation = generate_candidates(prepared)
            campaign = freeze_candidates(prepared, generation)
            publish_documents(args.output_dir, {"candidate_generation.json": generation}, "campaign.json", campaign)
            output = {"campaign": str(args.output_dir / "campaign.json"), "checksum": campaign["checksum"], "stage": "candidates_frozen", "contenders": 30}
        elif args.command == "prepare-round":
            from .campaign_schedule import build_round_manifest, audit_manifest
            campaign = load_artifact(args.campaign, "roster_campaign")
            survivors = None
            if args.round == 2:
                if args.previous_result is None:
                    raise ToolError("round_one_result_required", "Round two requires verified round-one results before its actual manifest is constructed.", 2)
                from .campaign_comparison import validate_round_result
                previous = validate_round_result(load_artifact(args.previous_result, "campaign_round_result_v1"), campaign)
                if previous["round_number"] != 1:
                    raise ToolError("round_one_result_required", "Round-two scheduling requires the result of round one.", 2)
                survivors = previous["survivor_ids"]
            elif args.previous_result is not None:
                raise ToolError("unexpected_round_result", "Round one starts with all contenders and has no preceding result.", 2)
            manifest = build_round_manifest(campaign, args.round, survivors)
            certificate = audit_manifest(manifest)
            if args.round == 2:
                config = validate_campaign(campaign)["config"]
                certificate["profile_ordering"] = {
                    "policy": "round2_profile_order_v1", "recorded_seed": config["schedule_seeds"][1],
                    "campaign_id": config["campaign_id"],
                    "derivation": "SHA256(campaign_id + ':round2_profile_order_v1:' + recorded_seed), first 8 bytes as a big-endian integer",
                    "ordered_profile_ids": [p["profile_id"] for p in manifest["profiles"]],
                }
            documents = {"manifest.json": manifest}
            publish_documents(args.output_dir, documents, "fairness.json", certificate)
            output = {"manifest": str(args.output_dir / "manifest.json"), "profiles": certificate["profile_count"], "tournaments": certificate["tournament_count"], "pair_frequency": [certificate["minimum_pair_frequency"], certificate["maximum_pair_frequency"]]}
        elif args.command == "prepare-confirmation":
            from .campaign_confirmation import build_confirmation_manifests
            campaign = load_artifact(args.campaign, "roster_campaign")
            manifests = build_confirmation_manifests(campaign, args.candidate_id)
            publish_documents(args.output_dir, {f"{mode}_manifest.json": manifest for mode, manifest in manifests.items()}, "confirmation_plan.json", {"campaign_checksum": campaign["checksum"], "candidate_id": args.candidate_id, "policy_version": "nine_player_promotion_v1"})
            output = {"output_dir": str(args.output_dir), "candidate_id": args.candidate_id}
        elif args.command == "confirm":
            from .campaign_confirmation import confirm_nine_player
            confirmation = confirm_nine_player(load_artifact(args.campaign, "roster_campaign"), args.candidate_id, args.report_a, args.report_b)
            write_artifact_atomic(args.output, confirmation)
            output = {"confirmation": str(args.output), "checksum": confirmation["checksum"], "promotion_eligible": confirmation["payload"]["confirmation"]["promotion_eligible"]}
        elif args.command == "run-round":
            from .campaign_runner import run_manifest
            expected = load_json_object(args.expected_provenance) if args.expected_provenance else None
            readiness = run_manifest(args.manifest, args.godot, args.output_dir, load_json_object(args.approval), args.workers, expected)
            output = {"readiness": str(args.output_dir / "readiness.json"), "checksum": readiness["checksum"]}
        elif args.command == "compare-round":
            from .campaign_comparison import compare_round
            previous = load_artifact(args.previous_result, "campaign_round_result_v1") if args.previous_result else None
            result = compare_round(load_artifact(args.campaign, "roster_campaign"), load_artifact(args.readiness, "campaign_run_readiness_v1"), args.round, previous)
            publish_documents(args.output_dir, {}, "comparison.json", result)
            output = {"comparison": str(args.output_dir / "comparison.json"), "checksum": result["checksum"], "survivor_ids": result["payload"]["survivor_ids"], "rejected_ids": result["payload"]["rejected_ids"]}
        elif args.command == "prepare-confirmation-cohort":
            from .campaign_confirmation_cohort import prepare_confirmation_cohort
            plan = prepare_confirmation_cohort(load_artifact(args.campaign, "roster_campaign"), load_artifact(args.round1_result, "campaign_round_result_v1"), load_artifact(args.round2_result, "campaign_round_result_v1"))
            publish_documents(args.output_dir, {}, "cohort_plan.json", plan)
            output = {"plan": str(args.output_dir / "cohort_plan.json"), "checksum": plan["checksum"]}
        elif args.command == "run-confirmation-cohort":
            from .campaign_confirmation_cohort import run_confirmation_cohort
            readiness = run_confirmation_cohort(load_artifact(args.plan, "confirmation_cohort_plan_v1"), load_json_object(args.authorization), args.godot, args.output_dir, args.workers)
            output = {"output_dir": str(args.output_dir), "checksum": readiness["checksum"]}
        elif args.command == "prepare-confirmation-review":
            from .campaign_confirmation_review import prepare_confirmation_review
            summary = prepare_confirmation_review(load_artifact(args.plan, "confirmation_cohort_plan_v1"), load_artifact(args.readiness, "confirmation_cohort_readiness_v1"), args.output_dir, args.reviewer_id)
            output = {"summary": str(args.output_dir / "summary.json"), "checksum": summary["checksum"]}
        else:
            campaign = load_artifact(args.campaign, "roster_campaign")
            payload = validate_campaign(campaign)
            output = {"checksum": campaign["checksum"], "stage": payload["stage"], "contenders": len(payload["contenders"])}
        sys.stdout.buffer.write(canonical_json_bytes(output))
        return 0
    except ToolError as error:
        sys.stderr.buffer.write(canonical_json_bytes(error.as_object()))
        return int(error.exit_code)
    except (KeyError, TypeError, ValueError, IndexError, AttributeError) as error:
        sys.stderr.buffer.write(canonical_json_bytes({"error": {"code": "invalid_campaign_input", "message": str(error)}}))
        return 2
    except OSError as error:
        sys.stderr.buffer.write(canonical_json_bytes({"error": {"code": "campaign_io_failed", "message": str(error)}}))
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
