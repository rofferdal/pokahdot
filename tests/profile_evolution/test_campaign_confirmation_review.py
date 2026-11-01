"""Complete-producer and pending-review safeguards with fresh generated inputs."""
from __future__ import annotations

import copy
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tests.profile_evolution.test_campaign_confirmation import _confirmation_fixture
from tests.profile_evolution.test_campaign_confirmation_cohort import _authorization, _fake_producer_files
from tools.profile_evolution.artifacts import canonical_json_bytes, create_artifact, load_artifact
from tools.profile_evolution.campaign_confirmation import confirm_nine_player, validate_nine_player_confirmation
from tools.profile_evolution.campaign_confirmation_cohort import (
    READY_TYPE, RUN_TYPE, _job_audit, _validate_job_ready, prepare_confirmation_cohort,
)
from tools.profile_evolution.campaign_confirmation_review import prepare_confirmation_review
from tools.profile_evolution.campaign_runner import COMPLETE_TYPE, _digest
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.experiment_output import publish_documents


def _save(path, document):
    path.write_bytes(canonical_json_bytes(document))


class ConfirmationReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.campaign, cls.first_id, _, cls.real_confirmation = _confirmation_fixture(Path(cls.temporary.name))
        cls.template = cls.real_confirmation["payload"]["confirmation"]
        # The fixture helper's real report provenance is embedded in strict evidence.
        cls.engine = json.loads(cls.real_confirmation["payload"]["report_documents"]["a"][0])["execution_provenance"]
        finalists = [r["candidate_id"] for r in cls.campaign["payload"]["contenders"][:20]]
        final = {"round_number": 2, "survivor_ids": finalists, "execution_provenance": cls.engine}
        with patch("tools.profile_evolution.campaign_confirmation_cohort.validate_round_result", return_value=final):
            cls.plan = prepare_confirmation_cohort(cls.campaign, create_artifact("synthetic_round", {"round": 1}), create_artifact("synthetic_round", {"round": 2}))
        cls.context = cls.plan["payload"]

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def fixture(self, root, real_first=False):
        root.mkdir()
        (root / "jobs").mkdir()
        authorization = _authorization(self.plan)
        run = create_artifact(RUN_TYPE, {"plan_checksum": self.plan["checksum"], "campaign_checksum": self.context["campaign_checksum"],
            "policy_version": "nine_player_promotion_v1", "policy_authorization": authorization,
            "godot": "/synthetic-test-engine", "expected_provenance": self.engine, "maximum_parallel_jobs": 4})
        _save(root / "run.json", run)
        _save(root / "plan.json", self.plan)
        receipts = []
        for job in self.context["jobs"]:
            directory = root / "jobs" / job["job_id"]
            ready = _fake_producer_files(directory, job["manifest"], "/synthetic-test-engine", {"policy_authorization": authorization},
                                         self.engine, _job_audit(job), full_report=real_first and job["candidate_id"] == self.first_id)
            receipts.append({"job_id": job["job_id"], "candidate_id": job["candidate_id"], "mode": job["mode"],
                "manifest_checksum": job["manifest_checksum"], "readiness_path": str(directory / "readiness.json"),
                "readiness_checksum": ready["checksum"], "readiness_sha256": _digest(directory / "readiness.json"),
                "reports": ready["payload"]["reports"], "tournament_count": 297})
        cohort = create_artifact(READY_TYPE, {"plan_checksum": self.plan["checksum"], "campaign_checksum": self.context["campaign_checksum"],
            "run_checksum": run["checksum"], "policy_version": "nine_player_promotion_v1", "execution_provenance": self.engine,
            "finalist_ids": self.context["finalist_ids"], "jobs": receipts, "job_count": 40, "tournament_count": 11880})
        _save(root / "readiness.json", cohort)
        return cohort

    def postprocess(self, cohort, output, real_first=False, ineligible=False, wrong_embedded=False):
        receipts = {r["job_id"]: r for r in cohort["payload"]["jobs"]}
        rows = {r["candidate_id"]: r for r in self.campaign["payload"]["contenders"]}
        def producer(directory, job, ready, authorization, provenance):
            if real_first and job["candidate_id"] == self.first_id:
                return _validate_job_ready(directory, job, ready, authorization, provenance)
            return receipts[job["job_id"]]
        def confirm(campaign, identifier, paths_a, paths_b):
            if real_first and identifier == self.first_id:
                return confirm_nine_player(campaign, identifier, paths_a, paths_b)
            result = copy.deepcopy(self.template)
            row = rows[identifier]
            result["candidate"] = {"candidate_id": identifier, "model_id": row["profile"]["model_id"],
                                   "parameters": row["profile"]["parameters"], "parent_ids": row["parent_ids"]}
            if ineligible and identifier == self.context["finalist_ids"][1]:
                result["promotion_eligible"] = False
                result["ineligibility_reasons"] = ["a:performance_not_demonstrated:fixture"]
            documents = {"a": [paths_a[0].read_text()], "b": [paths_b[0].read_text()]}
            if wrong_embedded:
                documents["a"] = ['{"changed_embedded_source":true}']
            return create_artifact("nine_player_confirmation_v1", {"candidate_id": identifier, "report_documents": documents, "confirmation": result})
        def validated_confirmation(artifact):
            if real_first and artifact["payload"]["candidate_id"] == self.first_id:
                return validate_nine_player_confirmation(artifact)
            return artifact["payload"]["confirmation"]
        with patch("tools.profile_evolution.campaign_confirmation_review._validate_plan", return_value=self.context), \
             patch("tools.profile_evolution.campaign_confirmation_review._validate_job_ready", side_effect=producer) as checked_producer, \
             patch("tools.profile_evolution.campaign_confirmation_review.confirm_nine_player", side_effect=confirm) as confirmed, \
             patch("tools.profile_evolution.promotion_review.validate_confirmation", side_effect=validated_confirmation):
            result = prepare_confirmation_review(self.plan, cohort, output, "human_reviewer")
        self.assertEqual(40, checked_producer.call_count)
        self.assertEqual(20, confirmed.call_count)
        return result

    def test_complete_cohort_produces_twenty_confirmations_and_one_pretty_pending_review(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "cohort"
            ready = self.fixture(root)
            output = Path(folder) / "review"
            summary = self.postprocess(ready, output, ineligible=True)
            self.assertEqual(summary, load_artifact(output / "summary.json"))
            self.assertEqual(20, len(summary["payload"]["confirmations"]))
            self.assertEqual(19, summary["payload"]["eligible_count"])
            self.assertEqual(1, summary["payload"]["ineligible_count"])
            self.assertFalse(summary["payload"]["publication_authorized"])
            self.assertEqual(20, len(summary["payload"]["proposed_profiles"]))
            self.assertEqual(5, len(summary["payload"]["protected_strategic_controls"]))
            raw = (output / "promotion_review_plan.json").read_bytes()
            self.assertIn(b'\n  "candidates": [', raw)
            self.assertEqual(hashlib.sha256(raw).hexdigest(), summary["payload"]["promotion_review_plan"]["sha256"])
            plan = json.loads(raw)
            self.assertEqual({"pending"}, {c["decision"] for c in plan["candidates"]})
            names = {r["candidate_id"]: r["display_name"] for r in self.campaign["payload"]["contenders"]}
            self.assertTrue(all(c["display_name"] == names[c["candidate"]["candidate_id"]] for c in plan["candidates"]))
            self.assertEqual(22, len(list(output.iterdir())))

    def test_real_strict_confirmation_pair_reaches_pending_review(self):
        with tempfile.TemporaryDirectory() as folder:
            ready = self.fixture(Path(folder) / "cohort", real_first=True)
            summary = self.postprocess(ready, Path(folder) / "review", real_first=True)
            first = load_artifact(Path(folder) / "review" / "confirmation_0000.json")
            self.assertTrue(validate_nine_player_confirmation(first)["promotion_eligible"])
            self.assertEqual(20, summary["payload"]["eligible_count"])

    def test_incomplete_unknown_duplicate_and_wrong_cohort_fail_before_confirmation_consumption(self):
        mutations = (
            lambda p: p["jobs"].pop(),
            lambda p: p.__setitem__("unexpected", True),
            lambda p: p.__setitem__("plan_checksum", "0" * 64),
            lambda p: p["jobs"][0].__setitem__("mode", "b"),
            lambda p: p["jobs"][0].__setitem__("candidate_id", "balanced"),
            lambda p: p["jobs"][0].__setitem__("unknown_receipt_field", 1),
            lambda p: p["jobs"].__setitem__(1, copy.deepcopy(p["jobs"][0])),
        )
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index), tempfile.TemporaryDirectory() as folder:
                ready = self.fixture(Path(folder) / "cohort")
                p = copy.deepcopy(ready["payload"]); mutate(p)
                changed = create_artifact(READY_TYPE, p)
                _save(Path(folder) / "cohort" / "readiness.json", changed)
                with patch("tools.profile_evolution.campaign_confirmation_review._validate_plan", return_value=self.context), \
                     patch("tools.profile_evolution.campaign_confirmation_review.confirm_nine_player") as consumer, \
                     self.assertRaises(ToolError):
                    prepare_confirmation_review(self.plan, changed, Path(folder) / "out", "reviewer")
                consumer.assert_not_called()
                self.assertFalse((Path(folder) / "out").exists())

    def test_missing_changed_and_unsuccessful_producer_outputs_are_rejected_before_raw_report_validation(self):
        for mutation in ("missing_cohort", "missing_report", "changed_report", "changed_readiness", "unsuccessful", "wrong_authorization"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as folder:
                root = Path(folder) / "cohort"; ready = self.fixture(root)
                receipt = ready["payload"]["jobs"][0]
                directory = Path(receipt["readiness_path"]).parent
                if mutation == "missing_cohort": (root / "readiness.json").unlink()
                if mutation == "missing_report": (directory / "shard_0000.json").unlink()
                if mutation == "changed_report": (directory / "shard_0000.json").write_text('{}')
                if mutation == "changed_readiness": (directory / "readiness.json").write_text('{}')
                if mutation == "wrong_authorization":
                    # Even a late job with valid success markers cannot be
                    # consumed under a different policy authorization.
                    last = ready["payload"]["jobs"][-1]
                    late = Path(last["readiness_path"]).parent
                    run = load_artifact(late / "run.json")
                    run["payload"]["policy_authorization"]["authorized"] = False
                    _save(late / "run.json", create_artifact(run["type"], run["payload"]))
                if mutation == "unsuccessful":
                    complete = load_artifact(directory / "shard_0000.completed.json")
                    complete["payload"]["exit_code"] = 2
                    _save(directory / "shard_0000.completed.json", create_artifact(COMPLETE_TYPE, complete["payload"]))
                with patch("tools.profile_evolution.campaign_confirmation_review._validate_plan", return_value=self.context), \
                     patch("tools.profile_evolution.campaign_confirmation_review._validate_job_ready") as validator, \
                     self.assertRaises(ToolError):
                    prepare_confirmation_review(self.plan, ready, Path(folder) / "out", "reviewer")
                validator.assert_not_called()

    def test_changed_embedded_source_and_existing_output_cannot_be_published(self):
        with tempfile.TemporaryDirectory() as folder:
            ready = self.fixture(Path(folder) / "cohort")
            with self.assertRaises(ToolError):
                self.postprocess(ready, Path(folder) / "out", wrong_embedded=True)
            self.assertFalse((Path(folder) / "out").exists())
            output = Path(folder) / "occupied"; output.mkdir(); (output / "user.txt").write_text('preserve')
            with self.assertRaises(ToolError): self.postprocess(ready, output)
            self.assertEqual(['user.txt'], [p.name for p in output.iterdir()])

    def test_pretty_writer_preserves_default_and_commits_index_last(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "out"
            publish_documents(output, {"data.json": {"z": 2}}, "index.json", {"ready": True})
            self.assertEqual(canonical_json_bytes({"z": 2}), (output / "data.json").read_bytes())
            with self.assertRaises(ToolError):
                publish_documents(Path(folder) / "invalid", {}, "index.json", {}, pretty_names={"missing.json"})
            self.assertFalse((Path(folder) / "invalid").exists())
            from tools.profile_evolution.atomic_write import publish_bytes_no_replace
            calls = []
            def observed(path, contents):
                calls.append(path.name)
                return publish_bytes_no_replace(path, contents)
            with patch("tools.profile_evolution.experiment_output.publish_bytes_no_replace", side_effect=observed):
                publish_documents(Path(folder) / "pretty", {"data.json": {"x": 1}, "review.json": {"decision": "pending"}},
                                  "ready.json", {"ready": True}, pretty_names={"review.json"})
            self.assertEqual(["data.json", "review.json", "ready.json"], calls)
            self.assertIn('\n  "decision"', (Path(folder) / "pretty" / "review.json").read_text())

