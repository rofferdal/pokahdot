"""Confirmation cohort policy and executor boundaries with fresh fixtures."""
from __future__ import annotations

import contextlib
import copy
import io
import json
import signal
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from tests.profile_evolution.test_campaign_comparison import _receipts, _save, _small_campaign
from tests.profile_evolution.test_campaign_confirmation import _report_for_manifest
from tools.profile_evolution.artifacts import create_artifact, load_artifact
from tools.profile_evolution.campaign_comparison import compare_round
from tools.profile_evolution.campaign_confirmation_cohort import (
    JOB_READY_TYPE, JOB_RUN_TYPE, PLAN_TYPE, READY_TYPE, _job_audit, _validate_job_ready,
    prepare_confirmation_cohort, run_confirmation_cohort,
)
from tools.profile_evolution.campaign_runner import COMPLETE_TYPE, START_TYPE, _digest
from tools.profile_evolution.errors import ToolError, ExitCode
from tools.profile_evolution.fitness import _simulation_manifest_checksum


def _authorization(plan):
    return {"scope": "confirmation_cohort", "source": "user_authorized_backlog", "authorized": True,
            "plan_checksum": plan["checksum"], "campaign_checksum": plan["payload"]["campaign_checksum"],
            "policy_version": "nine_player_promotion_v1"}


def _fake_producer_files(directory, manifest, godot, authorization_fields, provenance, audit, full_report=False):
    directory.mkdir(exist_ok=True)
    existing = directory / "readiness.json"
    if existing.is_file():
        return load_artifact(existing, JOB_READY_TYPE)
    run = create_artifact(JOB_RUN_TYPE, {"manifest": manifest, "manifest_checksum": _simulation_manifest_checksum(manifest),
        "workers": 1, "godot": godot, "expected_provenance": provenance, **authorization_fields})
    _save(directory / "run.json", run)
    _save(directory / "manifest.json", manifest)
    report = directory / "shard_0000.json"
    if full_report:
        _save(report, _report_for_manifest(manifest, manifest["profiles"][0]["profile_id"]))
    else:
        # Strict engine-report validation is mocked only in executor-boundary
        # tests. A separate integration test below exercises the real validator.
        _save(report, {"synthetic_executor_boundary_fixture": True})
    evidence = {"path": str(report.absolute()), "sha256": _digest(report), "shard": {"index": 0, "count": 1}, "tournament_count": 297}
    _save(directory / "shard_0000.started.json", create_artifact(START_TYPE, {"run_checksum": run["checksum"], "shard": evidence["shard"]}))
    _save(directory / "shard_0000.completed.json", create_artifact(COMPLETE_TYPE, {"run_checksum": run["checksum"], "exit_code": 0, "report": evidence}))
    ready = create_artifact(JOB_READY_TYPE, {"run_checksum": run["checksum"], "manifest_checksum": _simulation_manifest_checksum(manifest),
        "manifest": manifest, "workers": 1, "reports": [evidence], "execution_provenance": provenance,
        "tournament_count": 297, "schedule_audit": audit})
    _save(existing, ready)
    return ready


def _mock_report(path, manifest, planned, shard, workers, reference):
    if not path.is_file():
        raise ToolError("missing_fixture_report", "Producer report missing.", ExitCode.INVALID_INPUT)
    return {"path": str(path), "sha256": _digest(path), "shard": {"index": 0, "count": 1}, "tournament_count": 297}, reference


class FakeExecutor:
    def __init__(self, fail_at=None, delete_report=False):
        self.lock = threading.Lock()
        self.active = self.peak = 0
        self.calls = []
        self.events = []
        self.fail_at = fail_at
        self.delete_report = delete_report

    def __call__(self, manifest_path, manifest, godot, directory, authorization_fields, workers, expected_provenance,
                 audit, run_type, ready_type, cancel_event):
        with self.lock:
            index = len(self.calls)
            self.calls.append((directory, manifest, authorization_fields, workers, run_type, ready_type))
            self.events.append(cancel_event)
            self.active += 1
            self.peak = max(self.peak, self.active)
        try:
            if index == self.fail_at:
                time.sleep(.02)
                raise KeyboardInterrupt("synthetic cohort interruption")
            time.sleep(.01)
            if cancel_event.is_set():
                raise ToolError("cancelled", "Synthetic executor cancelled.", ExitCode.INVALID_INPUT)
            ready = _fake_producer_files(directory, manifest, godot, authorization_fields, expected_provenance, audit)
            if self.delete_report:
                (directory / "shard_0000.json").unlink(missing_ok=True)
            return ready
        finally:
            with self.lock:
                self.active -= 1


class ConfirmationCohortTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        root = Path(cls.temporary.name)
        cls.campaign = _small_campaign()
        cls.round1 = compare_round(cls.campaign, _receipts(root / "round1", cls.campaign))
        cls.round2 = compare_round(cls.campaign, _receipts(root / "round2", cls.campaign, 2, cls.round1), 2, cls.round1)
        cls.plan = prepare_confirmation_cohort(cls.campaign, cls.round1, cls.round2)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def execute(self, directory, executor, plan=None, authorization=None, workers=4):
        plan = self.plan if plan is None else plan
        authorization = _authorization(plan) if authorization is None else authorization
        # Selection was strictly verified in setUpClass; mock that expensive
        # boundary here while testing policy/ownership/concurrency behavior.
        with patch("tools.profile_evolution.campaign_confirmation_cohort.validate_round_result", return_value=self.round2["payload"]) as selection, \
             patch("tools.profile_evolution.campaign_runner._execute_validated_manifest", side_effect=executor), \
             patch("tools.profile_evolution.campaign_confirmation_cohort._report", side_effect=_mock_report), \
             contextlib.redirect_stdout(io.StringIO()):
            result = run_confirmation_cohort(plan, authorization, "/synthetic-test-engine", directory, workers)
        self.assertEqual(1, selection.call_count)
        return result

    def test_real_final_selection_freezes_twenty_finalists_and_forty_disjoint_nine_player_jobs(self):
        plan = self.plan["payload"]
        self.assertEqual(self.round2["payload"]["survivor_ids"], plan["finalist_ids"])
        self.assertEqual(20, len(plan["finalist_ids"]))
        self.assertEqual(40, len(plan["jobs"]))
        self.assertEqual(11880, sum(job["tournament_count"] for job in plan["jobs"]))
        ranges = []
        for job in plan["jobs"]:
            manifest = job["manifest"]
            self.assertEqual(9, len(manifest["profiles"]))
            self.assertTrue(all(p["model_id"] == "strategy_parameterized" for p in manifest["profiles"]))
            self.assertEqual(9, len(set(manifest["matchups"][0]["profile_ids"])))
            self.assertEqual(297, manifest["evaluation_plans"][0]["tournament_count"])
            self.assertEqual(33, _job_audit(job)["minimum_samples_per_seat"])
            ranges.append((manifest["seed_start"], manifest["seed_start"] + 296))
        ranges.sort()
        self.assertTrue(all(a[1] < b[0] for a, b in zip(ranges, ranges[1:])))
        self.assertEqual(self.round2["payload"]["execution_provenance"], plan["expected_provenance"])

    def test_authorization_mismatch_and_bad_worker_budget_fail_before_launch(self):
        for field, value in (("authorized", False), ("authorized", 1), ("scope", "round2"),
                             ("source", "manifest_approval"), ("plan_checksum", "0" * 64),
                             ("campaign_checksum", "0" * 64), ("policy_version", "promotion_evidence_v1")):
            authorization = _authorization(self.plan)
            authorization[field] = value
            with self.subTest(field=field, value=value), tempfile.TemporaryDirectory() as temporary, \
                 patch("tools.profile_evolution.campaign_runner._execute_validated_manifest") as launch:
                with self.assertRaises(ToolError):
                    run_confirmation_cohort(self.plan, authorization, "godot", Path(temporary) / "out")
                launch.assert_not_called()
                self.assertFalse((Path(temporary) / "out").exists())
        for workers in (0, 5, True, 1.0):
            with tempfile.TemporaryDirectory() as temporary, self.assertRaises(ToolError):
                run_confirmation_cohort(self.plan, _authorization(self.plan), "godot", Path(temporary) / "out", workers)

    def test_four_job_limit_policy_authorization_and_owned_resume(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "cohort"
            executor = FakeExecutor()
            ready = self.execute(directory, executor)
            self.assertEqual(READY_TYPE, ready["type"])
            self.assertEqual(40, len(ready["payload"]["jobs"]))
            self.assertEqual(11880, ready["payload"]["tournament_count"])
            self.assertLessEqual(executor.peak, 4)
            self.assertGreater(executor.peak, 1)
            self.assertEqual(0, executor.active)
            self.assertEqual(1, len({id(event) for event in executor.events}))
            for _, _, authorization_fields, workers, run_type, ready_type in executor.calls:
                self.assertEqual({"policy_authorization"}, set(authorization_fields))
                self.assertEqual(_authorization(self.plan), authorization_fields["policy_authorization"])
                self.assertEqual(1, workers)
                self.assertEqual(JOB_RUN_TYPE, run_type)
                self.assertEqual(JOB_READY_TYPE, ready_type)
            self.assertEqual(ready, self.execute(directory, FakeExecutor(), workers=2))

    def test_interruption_cancels_active_and_pending_jobs_then_resumes_owned_outputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "cohort"
            executor = FakeExecutor(fail_at=1)
            previous_handlers = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
            with self.assertRaises(KeyboardInterrupt):
                self.execute(directory, executor, workers=2)
            self.assertEqual(0, executor.active)
            self.assertLess(len(executor.calls), 40)
            self.assertTrue(all(event.is_set() for event in executor.events))
            self.assertFalse((directory / "readiness.json").exists())
            self.assertEqual(previous_handlers, {sig: signal.getsignal(sig) for sig in previous_handlers})
            ready = self.execute(directory, FakeExecutor(), workers=3)
            self.assertEqual(40, ready["payload"]["job_count"])

    def test_missing_producer_outputs_and_resealed_plan_changes_fail(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "cohort"
            with self.assertRaises(ToolError):
                self.execute(directory, FakeExecutor(delete_report=True))
            self.assertFalse((directory / "readiness.json").exists())
        for field in ("finalists", "sample_count", "legacy"):
            payload = copy.deepcopy(self.plan["payload"])
            if field == "finalists":
                payload["finalist_ids"].reverse()
            elif field == "sample_count":
                payload["jobs"][0]["manifest"]["evaluation_plans"][0]["tournament_count"] = 288
            else:
                payload["jobs"][0]["manifest"]["profiles"][0]["model_id"] = "random"
            forged = create_artifact(PLAN_TYPE, payload)
            with self.subTest(field=field), tempfile.TemporaryDirectory() as temporary:
                with self.assertRaises(ToolError):
                    self.execute(Path(temporary) / "cohort", FakeExecutor(), forged)

    def test_real_job_receipts_require_full_strict_report_validation(self):
        job = self.plan["payload"]["jobs"][0]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "job"
            ready = _fake_producer_files(root, job["manifest"], "godot", {"policy_authorization": _authorization(self.plan)},
                self.plan["payload"]["expected_provenance"], _job_audit(job), full_report=True)
            receipt = _validate_job_ready(root, job, ready, _authorization(self.plan), self.plan["payload"]["expected_provenance"])
            self.assertEqual(297, receipt["tournament_count"])
            (root / "shard_0000.json").unlink()
            with self.assertRaises(ToolError):
                _validate_job_ready(root, job, ready, _authorization(self.plan), self.plan["payload"]["expected_provenance"])


if __name__ == "__main__":
    unittest.main()
