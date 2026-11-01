"""Explicit human publication preserves original evidence and immutable resources."""
from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.profile_evolution.artifacts import create_artifact
from tools.profile_evolution.campaign_publication import POLICY, approve_selection, publish_selection, validate_selection
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.profile_publisher import _resource_text, _write_new_file
from tools.profile_evolution.contracts import GENES


def fixtures() -> tuple[dict, dict]:
    """Synthetic data at the verified-comparison boundary; no saved run inputs."""
    rows = []
    for i in range(25):
        cid = f"candidate_{i:02d}"
        rows.append({"candidate_id": cid, "rank": i + 1, "display_name": f"Silver Current {i}",
                     "eligible": True, "origin": "incumbent" if i < 6 else "initialized",
                     "parent_ids": [], "profile_id": cid + "__old" if i < 6 else cid,
                     "profile_snapshot": {"model_id": "strategy_parameterized", "parameters": {g: i for g in GENES}},
                     "component_means": {"win_score": i / 100}, "original_creation_checksum": f"{i:064x}"})
    comparison = create_artifact("campaign_round_result_v1", {
        "round_number": 2, "campaign_checksum": "a" * 64, "ranking": rows,
        "survivor_ids": [r["candidate_id"] for r in rows[:20]], "rejected_ids": [r["candidate_id"] for r in rows[20:]],
    })
    entries = []
    for r in rows[:19] + [rows[22]]:
        cid = r["candidate_id"]
        entries.append({"candidate": {"candidate_id": cid, "model_id": "strategy_parameterized", "parameters": r["profile_snapshot"]["parameters"], "parent_ids": []},
                        "display_name": r["display_name"], "original_creation_checksum": r["original_creation_checksum"],
                        "round2_rank": r["rank"], "win_rate": r["component_means"]["win_score"],
                        "retain_existing_resource": r["origin"] == "incumbent",
                        "proposed_profile_id": r["profile_id"] if r["origin"] == "incumbent" else cid + "__20261101_r2",
                        "strict_confirmation_eligible": False if r["rank"] < 23 else None,
                        "confirmation_checksum": "c" * 64 if r["rank"] < 23 else None,
                        "confirmation_status": "available" if r["rank"] < 23 else "not_run"})
    selection = create_artifact("campaign_human_selection_v1", {
        "round2_comparison_checksum": comparison["checksum"], "campaign_checksum": "a" * 64,
        "excluded_candidate_id": rows[19]["candidate_id"], "included_candidate_id": rows[22]["candidate_id"], "selected": entries,
    })
    return selection, comparison


class CampaignPublicationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.selection, self.comparison = fixtures()

    def approval(self, **changes: object) -> dict:
        return dict(source="user", approved=True, replace_strict_performance_gate=True,
                    selection_checksum=self.selection["checksum"], instruction="Publish these twenty despite benchmark findings.", **changes)

    def review(self) -> dict:
        return approve_selection(self.selection, self.comparison, reviewer_id="human", approval=self.approval())

    def reseal(self, value: dict) -> dict:
        return create_artifact(value["type"], copy.deepcopy(value["payload"]))

    def seed_incumbents(self, root: Path) -> dict[Path, bytes]:
        originals = {}
        for e in self.selection["payload"]["selected"]:
            if e["retain_existing_resource"]:
                p = root / "resources/bot_profiles/published" / (e["proposed_profile_id"] + ".tres")
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(_resource_text(e["proposed_profile_id"], e["candidate"], e["display_name"]))
                originals[p] = p.read_bytes()
        return originals

    def test_exact_user_policy_approval_is_required(self) -> None:
        for field, bad in [("approved", False), ("replace_strict_performance_gate", False), ("source", "agent"), ("selection_checksum", "d" * 64), ("instruction", "")]:
            with self.subTest(field=field):
                a = self.approval(); a[field] = bad
                with self.assertRaises(ToolError):
                    approve_selection(self.selection, self.comparison, reviewer_id="human", approval=a)
        with self.assertRaises(ToolError):
            approve_selection(self.selection, self.comparison, reviewer_id="", approval=self.approval())

    def test_tampered_binding_identity_and_membership_fail(self) -> None:
        mutations = [lambda s: s.update(round2_comparison_checksum="b" * 64),
                     lambda s: s["selected"][0]["candidate"]["parameters"].update(bluff_rate=99),
                     lambda s: s["selected"].pop(),
                     lambda s: s.update(excluded_candidate_id="candidate_18"),
                     lambda s: s["selected"][0].update(proposed_profile_id="../escape"),
                     lambda s: s["selected"][0].update(retain_existing_resource=False),
                     lambda s: s["selected"][0].update(display_name="Changed Name")]
        for mutate in mutations:
            s = copy.deepcopy(self.selection); mutate(s["payload"])
            with self.subTest(mutate=mutate), self.assertRaises(ToolError):
                validate_selection(self.reseal(s), self.comparison)

    def test_duplicate_names_and_ids_fail(self) -> None:
        s, c = copy.deepcopy(self.selection), copy.deepcopy(self.comparison)
        s["payload"]["selected"][1]["display_name"] = s["payload"]["selected"][0]["display_name"]
        c["payload"]["ranking"][1]["display_name"] = c["payload"]["ranking"][0]["display_name"]
        c = self.reseal(c); s["payload"]["round2_comparison_checksum"] = c["checksum"]
        with self.assertRaises(ToolError): validate_selection(self.reseal(s), c)
        s = copy.deepcopy(self.selection); s["payload"]["selected"][1] = copy.deepcopy(s["payload"]["selected"][0])
        with self.assertRaises(ToolError): validate_selection(self.reseal(s), self.comparison)

    def test_fourteen_new_six_retained_with_honest_policy_sidecars(self) -> None:
        before = copy.deepcopy(self.comparison)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); old = self.seed_incumbents(root)
            result = publish_selection(self.selection, self.comparison, self.review(), root)
            profiles = result["payload"]["profiles"]
            self.assertEqual(len(profiles), 20)
            self.assertEqual(sum(p["retained_existing_resource"] for p in profiles), 6)
            for p in profiles:
                sidecar = json.loads((root / p["provenance_path"]).read_text())
                self.assertEqual(sidecar["policy_version"], POLICY)
                self.assertIsNot(sidecar["strict_confirmation_eligible"], True)
                self.assertTrue((root / p["resource_path"]).is_file())
            for p, original in old.items(): self.assertEqual(p.read_bytes(), original)
            with self.assertRaises(ToolError): publish_selection(self.selection, self.comparison, self.review(), root)
        self.assertEqual(self.comparison, before)

    def test_changed_or_incomplete_review_cannot_publish(self) -> None:
        for field in ("decisions", "selection_checksum"):
            review = copy.deepcopy(self.review())
            if field == "decisions": review["payload"][field].pop()
            else: review["payload"][field] = "f" * 64
            with tempfile.TemporaryDirectory() as tmp, self.assertRaises(ToolError):
                publish_selection(self.selection, self.comparison, self.reseal(review), Path(tmp))

    def test_write_failure_rolls_back_new_files_preserving_incumbents(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); old = self.seed_incumbents(root)
            count = 0
            def failing_write(path: Path, text: str) -> None:
                nonlocal count
                count += 1
                if count == 10: raise OSError("injected disk failure")
                _write_new_file(path, text)
            with patch("tools.profile_evolution.campaign_publication._write_new_file", side_effect=failing_write), self.assertRaises(OSError):
                publish_selection(self.selection, self.comparison, self.review(), root)
            self.assertEqual(set((root / "resources/bot_profiles/published").iterdir()), set(old))
            for p, content in old.items(): self.assertEqual(p.read_bytes(), content)

    def test_mismatched_retained_resource_fails_before_any_writes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); old = self.seed_incumbents(root)
            next(iter(old)).write_text("altered")
            with self.assertRaises(ToolError): publish_selection(self.selection, self.comparison, self.review(), root)
            self.assertEqual(set((root / "resources/bot_profiles/published").iterdir()), set(old))


if __name__ == "__main__":
    unittest.main()
