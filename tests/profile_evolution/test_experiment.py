from __future__ import annotations

import copy
import contextlib
import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.profile_evolution.artifacts import create_artifact, load_artifact, write_artifact_atomic
from tools.profile_evolution.cli import main
from tools.profile_evolution.confirmation import confirm_candidate
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.experiment import (
    RNG_ALGORITHM, experiment_manifests, load_experiment, prepare_experiment,
)
from tools.profile_evolution.experiment_comparison import compare_experiment
from tools.profile_evolution.experiment_output import publish_documents
from tools.profile_evolution.fitness import (
    _planned_tournaments, _roster_provenance, _simulation_manifest_checksum, _validate_manifest,
)
from tools.profile_evolution.lineage import build_lineage_registry, validate_lineage_registry
from tools.profile_evolution.evolution import initialize_generation
from tools.profile_evolution.promotion_review import create_promotion_review_plan, finalize_promotion_review
from tests.profile_evolution.test_confirmation import _registry, _report
from tests.profile_evolution.test_fitness import _bounds, _profile_result, _provenance


def _configuration(directory: Path) -> Path:
    registry, candidates = _registry()
    for entry in registry["payload"]["entries"]:
        if entry["candidate"]["candidate_id"] in ("candidate", "outsider"):
            entry["evaluations"] = []
        if entry["candidate"]["candidate_id"] == "outsider":
            entry["generation"] = 1
            entry["generation_id"] = "generation_g1"
    registry = create_artifact("lineage_registry", registry["payload"])
    write_artifact_atomic(directory / "lineage.json", registry)
    baseline_report = _report(
        directory / "baseline_report.json",
        list(candidates.values())[:3],
        5000,
        "baseline"
    )
    baseline = json.loads(baseline_report.read_text())["manifest"]
    (directory / "baseline.json").write_text(json.dumps(baseline))
    config = {
        "schema_version": 1, "experiment_id": "test_experiment", "registry": "lineage.json",
        "benchmark_manifest": "baseline.json", "candidate_ids": ["candidate", "outsider"],
        "legacy_ids": ["legacy"], "historical_champion_ids": ["champion"],
        "seed_starts": {"evaluation": 10000, "mirrored": 20000, "mixed": 30000},
        "tournaments_per_matchup": 300, "starting_stack": 100,
        "small_blind": 5, "big_blind": 10, "reviewer_id": "independent_reviewer",
    }
    path = directory / "experiment_config.json"
    path.write_text(json.dumps(config))
    return path


def _change(path: Path, **changes: object) -> None:
    config = json.loads(path.read_text())
    config.update(changes)
    path.write_text(json.dumps(config))


def _cohort(
    directory: Path,
    manifest: dict[str, object],
    shards: int = 1,
    candidate_ids: tuple[str, ...] = ("candidate", "outsider")
) -> list[Path]:
    tournaments = []
    for planned in _planned_tournaments(manifest, _validate_manifest(manifest)).values():
        candidate_id = next(
            item["profile_id"] for item in planned["seat_map"] if item["profile_id"] in candidate_ids
        )
        winner = candidate_id if candidate_id == candidate_ids[0] else next(
            item["profile_id"] for item in planned["seat_map"] if item["profile_id"] != candidate_id
        )
        results = [
            _profile_result(
                item["profile_id"],
                item["seat"],
                item["profile_id"] == winner,
                2,
                100
            ) for item in planned["seat_map"]
        ]
        tournaments.append({**planned, "termination_reason": "winner", "winner_profile_id": winner,
                            "tournament_hand_count": 1, "profile_results": results, "diagnostics": []})
    provenance = _provenance()
    provenance["algorithm_versions"]["rng_streams"] = RNG_ALGORITHM
    paths = []
    for shard in range(shards):
        report = {"report_schema_version": 4, "manifest": manifest,
                  "manifest_checksum": _simulation_manifest_checksum(manifest),
                  "roster": _roster_provenance(manifest), "code_revision": provenance["code_revision"],
                  "command_version": "simulation_cli_v6", "execution_provenance": provenance,
                  "shard": {"index": shard, "count": shards}, "started_at": "", "finished_at": "",
                  "tournaments": [item for item in tournaments if item["tournament_index"] % shards == shard],
                  "aggregates": {}, "traces": []}
        path = directory / f"cohort_{shard}.json"
        path.write_text(json.dumps(report))
        paths.append(path)
    return paths


class ExperimentTests(unittest.TestCase):
    def test_preparation_snapshots_inputs_and_balances_independent_manifest_blocks(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            _change(config, tournaments_per_matchup=301)
            output = root / "prepared"
            plan = prepare_experiment(config, output)
            self.assertFalse(plan["payload"]["incompatibilities"])
            self.assertEqual(len(plan["payload"]["manifests"]), 5)
            self.assertEqual(load_artifact(output / "experiment.json")["checksum"], plan["checksum"])
            self.assertEqual(len(plan["payload"]["commands"]), 14)
            self.assertNotIn("publish-profile", "\n".join(plan["payload"]["commands"]))
            self.assertEqual(
                plan["payload"]["config_checksum"],
                hashlib.sha256((output / "config.json").read_bytes()).hexdigest()
            )
            copied = load_experiment(output / "config.json")
            manifests, issues = experiment_manifests(copied)
            self.assertFalse(issues)
            ranges = []
            for name, manifest in manifests.items():
                counts = {}
                for item in _planned_tournaments(manifest, _validate_manifest(manifest)).values():
                    for seat in item["seat_map"]:
                        key = (item["matchup_id"], seat["profile_id"], seat["seat"])
                        counts[key] = counts.get(key, 0) + 1
                self.assertTrue(all(count >= 100 for count in counts.values()))
                start = manifest["seed_start"]
                end = start + manifest["evaluation_plans"][0]["tournament_count"] - 1
                self.assertTrue(all(end < lower or start > upper for lower, upper in ranges))
                ranges.append((start, end))
            self.assertEqual(
                (output / "input_registry.json").read_bytes(),
                (root / "lineage.json").read_bytes()
            )
            with self.assertRaises(ToolError):
                prepare_experiment(config, output)

    def test_dry_run_reports_commands_and_semantic_incompatibilities_without_writes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            _change(config, seed_starts={"evaluation": 10000, "mirrored": 10000, "mixed": 30000})
            output = root / "never_created"
            result = prepare_experiment(config, output, True)
            self.assertTrue(result["payload"]["commands"])
            self.assertIn("overlap", " ".join(result["payload"]["incompatibilities"]))
            self.assertFalse(output.exists())
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(
                    main(
                        [
                            "prepare-experiment",
                            "--config",
                            str(config),
                            "--output-dir",
                            str(output),
                            "--dry-run"
                        ]
                    ),
                    2
                )
            self.assertFalse(output.exists())

    def test_strict_config_rejects_invalid_numbers_classes_snapshots_and_seed_bounds(self) -> None:
        changes = [
            {"schema_version": True}, {"unknown": 1}, {"candidate_ids": ["candidate", "candidate"]},
            {"candidate_ids": ["absent"]}, {"legacy_ids": ["champion"]},
            {"historical_champion_ids": ["candidate"]}, {"starting_stack": 1_000_001},
            {"small_blind": 20}, {"tournaments_per_matchup": 299},
            {"seed_starts": {"evaluation": 0, "mirrored": 20000, "mixed": 30000}},
            {"seed_starts": {"evaluation": 2**53 - 10, "mirrored": 20000, "mixed": 30000}},
        ]
        for change in changes:
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                config = _configuration(root)
                _change(config, **change)
                with self.assertRaises(ToolError):
                    prepare_experiment(config, root / "result")
                self.assertFalse((root / "result").exists())

    def test_preparation_detects_prior_seed_overlap_and_incompatible_rng_history(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            registry, _ = _registry()
            registry["payload"]["entries"][0]["evaluations"][0]["report_evidence"][0]["seed_range"] = {
                "minimum": 10000,
                "maximum": 10010
            }
            artifact = create_artifact("lineage_registry", registry["payload"])
            (root / "lineage.json").write_text(json.dumps(artifact))
            plan = prepare_experiment(config, root / "dry", True)
            issues = " ".join(plan["payload"]["incompatibilities"])
            self.assertIn("prior evaluation RNG", issues)
            self.assertIn("overlaps a prior evaluation seed range", issues)

    def test_common_cohort_compares_cross_generation_candidates_and_preserves_lineage(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            context = load_experiment(config)
            manifests, _ = experiment_manifests(context)
            paths = _cohort(root, manifests["evaluation_manifest.json"], shards=2)
            comparison = compare_experiment(config, reversed(paths), root / "comparison")
            rows = comparison["payload"]["candidates"]
            self.assertEqual([row["candidate_id"] for row in rows], ["candidate", "outsider"])
            self.assertEqual([row["rank"] for row in rows], [1, 2])
            self.assertEqual([row["generation"] for row in rows], [0, 1])
            registry = load_artifact(root / "comparison/evaluated_registry.json", "lineage_registry")
            entries = validate_lineage_registry(registry)["entries"]
            for candidate_id in context["config"]["candidate_ids"]:
                self.assertEqual(
                    entries[candidate_id]["creation_context"],
                    context["entries"][candidate_id]["creation_context"]
                )
                self.assertEqual(entries[candidate_id]["evaluations"][0]["sample_count"], 600)
            for index in range(2):
                fitness = load_artifact(root / f"comparison/candidate_{index:04d}_fitness.json", "fitness")
                self.assertEqual(fitness["payload"]["source_generation_checksum"], "a" * 64)
            self.assertEqual(
                comparison["payload"]["source_registry_checksum"],
                context["registry_artifact"]["checksum"]
            )
            self.assertTrue(comparison["payload"]["review_required"])

    def test_comparison_rejects_changed_cohorts_missing_shards_and_mixed_provenance(self) -> None:
        for failure in ("changed_manifest", "missing_shard", "provenance"):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                config = _configuration(root)
                manifests, _ = experiment_manifests(load_experiment(config))
                paths = _cohort(root, manifests["evaluation_manifest.json"], shards=2)
                if failure == "missing_shard":
                    paths.pop()
                else:
                    report = json.loads(paths[0].read_text())
                    if failure == "changed_manifest":
                        report["manifest"]["profiles"][0]["parameters"]["bluff_rate"] += 1
                    else:
                        report["execution_provenance"]["engine_version"] = "other"
                    paths[0].write_text(json.dumps(report))
                with self.assertRaises(ToolError):
                    compare_experiment(config, paths, root / "comparison")
                self.assertFalse((root / "comparison").exists())

    def test_publication_rolls_back_owned_files_and_preserves_competitor_files(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "output"
            from tools.profile_evolution.atomic_write import publish_bytes_no_replace
            def fail_second(path, contents):
                if path.name == "second.json":
                    path.write_text("competitor")
                    raise FileExistsError(path)
                publish_bytes_no_replace(path, contents)
            with patch(
                "tools.profile_evolution.experiment_output.publish_bytes_no_replace",
                side_effect=fail_second
            ):
                with self.assertRaises(ToolError):
                    publish_documents(output, {"first.json": {}, "second.json": {}}, "index.json", {})
            self.assertEqual(list(output.iterdir()), [output / "second.json"])
            self.assertEqual((output / "second.json").read_text(), "competitor")

    def test_unchosen_creation_and_history_remain_unchanged_in_evaluated_registry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            context = load_experiment(config)
            manifests, _ = experiment_manifests(context)
            paths = _cohort(root, manifests["evaluation_manifest.json"])
            compare_experiment(config, paths, root / "comparison")
            registry = load_artifact(root / "comparison/evaluated_registry.json")
            entries = validate_lineage_registry(registry)["entries"]
            self.assertEqual(entries["champion"], context["entries"]["champion"])
            self.assertEqual(entries["legacy"], context["entries"]["legacy"])

    def test_emitted_fitness_reconstructs_with_real_original_generation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            generation = initialize_generation(_bounds(), 2, 991)
            generated_registry = build_lineage_registry([generation])
            registry = load_artifact(root / "lineage.json")
            registry["payload"]["entries"].extend(generated_registry["payload"]["entries"])
            registry["payload"]["artifacts"].extend(generated_registry["payload"]["artifacts"])
            (
                root / "lineage.json"
            ).write_text(json.dumps(create_artifact("lineage_registry", registry["payload"])))
            candidate_id = generation["payload"]["candidates"][0]["candidate_id"]
            _change(config, candidate_ids=[candidate_id])
            manifests, _ = experiment_manifests(load_experiment(config))
            paths = _cohort(root, manifests["evaluation_manifest.json"], candidate_ids=(candidate_id,))
            compare_experiment(config, paths, root / "comparison")
            fitness = load_artifact(root / "comparison/candidate_0000_fitness.json")
            rebuilt = build_lineage_registry([generation, fitness])
            entries = validate_lineage_registry(rebuilt)["entries"]
            self.assertEqual(len(entries[candidate_id]["evaluations"]), 1)
            self.assertEqual(fitness["payload"]["source_generation_checksum"], generation["checksum"])

    def test_crossover_batch_requires_mutation_into_a_generation_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            registry = load_artifact(root / "lineage.json")
            registry["payload"]["entries"][0]["creation_context"]["artifact_type"] = "candidate_batch"
            (
                root / "lineage.json"
            ).write_text(json.dumps(create_artifact("lineage_registry", registry["payload"])))
            with self.assertRaisesRegex(ToolError, "mutate it"):
                prepare_experiment(config, root / "prepared")

    def test_null_path_is_a_structured_config_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            _change(config, registry="bad\0path")
            errors = io.StringIO()
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(errors):
                code = main(
                    ["prepare-experiment", "--config", str(config), "--output-dir", str(root / "prepared")]
                )
            self.assertEqual(code, 2)
            self.assertIn("null byte", json.loads(errors.getvalue())["error"]["message"])

    def test_ineligible_candidates_remain_visible_and_unranked(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            manifests, _ = experiment_manifests(load_experiment(config))
            paths = _cohort(root, manifests["evaluation_manifest.json"])
            report = json.loads(paths[0].read_text())
            for result in report["tournaments"][0]["profile_results"]:
                if result["profile_id"] == "candidate":
                    result["invalid_action_fallbacks"] = 1
            paths[0].write_text(json.dumps(report))
            comparison = compare_experiment(config, paths, root / "comparison")
            rows = comparison["payload"]["candidates"]
            self.assertEqual([row["candidate_id"] for row in rows], ["outsider", "candidate"])
            self.assertEqual(rows[0]["rank"], 1)
            self.assertIsNone(rows[1]["rank"])
            self.assertIn("invalid_action_fallbacks", rows[1]["result"]["ineligibility_reasons"])

    def test_malformed_report_is_a_structured_cli_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            manifests, _ = experiment_manifests(load_experiment(config))
            paths = _cohort(root, manifests["evaluation_manifest.json"])
            report = json.loads(paths[0].read_text())
            report["execution_provenance"]["algorithm_versions"] = []
            paths[0].write_text(json.dumps(report))
            errors = io.StringIO()
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(errors):
                result = main(
                    [
                        "compare-experiment",
                        "--config",
                        str(config),
                        "--report",
                        str(paths[0]),
                        "--output-dir",
                        str(root / "comparison")
                    ]
                )
            self.assertEqual(result, 2)
            self.assertIn("error", json.loads(errors.getvalue()))
            self.assertFalse((root / "comparison").exists())

    def test_existing_dangling_output_symlink_is_never_followed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            output = root / "output"
            target = root / "target"
            output.symlink_to(target)
            with self.assertRaises(ToolError):
                prepare_experiment(config, output)
            self.assertTrue(output.is_symlink())
            self.assertFalse(target.exists())
            manifests, _ = experiment_manifests(load_experiment(config))
            paths = _cohort(root, manifests["evaluation_manifest.json"])
            with self.assertRaises(ToolError):
                compare_experiment(config, paths, output)
            self.assertTrue(output.is_symlink())
            self.assertFalse(target.exists())

    def test_identical_competitor_bytes_do_not_establish_ownership(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "output"
            def competing_write(path, contents):
                path.write_bytes(contents)
                raise FileExistsError(path)
            with patch(
                "tools.profile_evolution.experiment_output.publish_bytes_no_replace",
                side_effect=competing_write
            ):
                with self.assertRaises(ToolError):
                    publish_documents(output, {"foreign.json": {}}, "index.json", {})
            self.assertTrue((output / "foreign.json").exists())
            self.assertFalse((output / "index.json").exists())

    def test_failed_publication_before_link_removes_reserved_empty_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "output"
            with patch(
                "tools.profile_evolution.experiment_output.publish_bytes_no_replace",
                side_effect=OSError("injected")
            ):
                with self.assertRaises(ToolError):
                    publish_documents(output, {"data.json": {}}, "index.json", {})
            self.assertFalse(output.exists())

    def test_confirmation_and_consolidated_review_still_require_explicit_decisions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = _configuration(root)
            manifests, _ = experiment_manifests(load_experiment(config))
            paths = _cohort(root, manifests["evaluation_manifest.json"])
            compare_experiment(config, paths, root / "comparison")
            registry = load_artifact(root / "comparison/evaluated_registry.json")
            _, candidates = _registry()
            # These fixtures keep all three profiles at one mixed table. The
            # actual confirmation gates, not the preparation tool, judge results.
            mirrored = []
            for index, opponent in enumerate(("legacy", "champion")):
                mirrored.append(
                    _report(
                        root / f"mirror_{index}.json",
                        [candidates["candidate"], candidates[opponent]],
                        40000 + 1000 * index,
                        f"mirror_{index}"
                    )
                )
            mixed = _report(
                root / "mixed.json",
                [candidates[key] for key in ("candidate", "legacy", "champion")],
                50000,
                "mixed"
            )
            for path in mirrored + [mixed]:
                report = json.loads(path.read_text())
                report["execution_provenance"]["algorithm_versions"]["rng_streams"] = RNG_ALGORITHM
                path.write_text(json.dumps(report))
            confirmation = confirm_candidate(
                registry,
                "candidate",
                ["legacy"],
                ["champion"],
                mirrored,
                [mixed]
            )
            self.assertTrue(confirmation["payload"]["promotion_eligible"])
            plan = create_promotion_review_plan([confirmation], "independent_reviewer")
            self.assertEqual(plan["candidates"][0]["decision"], "pending")
            with self.assertRaises(ToolError):
                finalize_promotion_review(plan, [confirmation])


if __name__ == "__main__":
    unittest.main()
