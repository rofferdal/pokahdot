from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

from tools.profile_evolution.artifacts import create_artifact
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.historical_lineage import (
    DISCLAIMER,
    import_historical_lineage,
    validate_historical_lineage,
)

ROOT = Path(__file__).resolve().parents[2]
EXAMPLE = ROOT / "examples/profile_evolution/milestone5"


def _paths(folder: Path) -> list[Path]:
    registry = json.loads((folder / "lineage_registry.json").read_text())
    checksums = {a["checksum"] for a in registry["payload"]["artifacts"]}
    return [p for p in folder.glob("*.json") if json.loads(p.read_text()).get("checksum") in checksums]


def _example() -> dict:
    return import_historical_lineage(EXAMPLE / "lineage_registry.json", _paths(EXAMPLE))


def _reseal(artifact: dict) -> dict:
    return create_artifact(artifact["type"], artifact["payload"])


class HistoricalLineageTests(unittest.TestCase):
    def test_tracked_originals_import_without_fabricated_current_evidence(self) -> None:
        imported = _example()
        context = validate_historical_lineage(imported)
        self.assertEqual(15, len(context["entries"]))
        champion = context["entries"]["candidate_g0_0003_9963610230e600f4"]
        self.assertEqual(1, len(champion["historical_selection"]))
        self.assertEqual([], champion["evaluations"])
        self.assertEqual(DISCLAIMER, champion["evidence_status"])
        self.assertIsNone(context["execution_provenance"])
        self.assertNotIn("point_fitness", champion["historical_evaluations"][0])
        self.assertNotIn("execution_provenance", champion["historical_evaluations"][0]["report_evidence"][0])
        self.assertEqual(json.loads((EXAMPLE / "lineage_registry.json").read_text()), imported["payload"]["source_registry"])

    def test_validates_embedded_originals_without_filesystem_dependencies(self) -> None:
        imported = _example()
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "archive.json"
            path.write_text(json.dumps(imported))
            restored = json.loads(path.read_text())
        self.assertEqual(validate_historical_lineage(imported), validate_historical_lineage(restored))
        self.assertEqual(imported, import_historical_lineage(EXAMPLE / "lineage_registry.json", reversed(_paths(EXAMPLE))))

    def test_missing_duplicate_and_tampered_originals_fail(self) -> None:
        paths = _paths(EXAMPLE)
        for inputs in (paths[:-1], paths + [paths[0]]):
            with self.subTest(inputs=len(inputs)), self.assertRaises(ToolError):
                import_historical_lineage(EXAMPLE / "lineage_registry.json", inputs)
        imported = _example()
        imported["payload"]["original_artifacts"][0]["tool_version"] = "tampered"
        with self.assertRaises(ToolError):
            validate_historical_lineage(_reseal(imported))

    def test_resealed_registry_gene_and_champion_claims_are_rejected(self) -> None:
        for field in ("parameters", "selection_history", "parent_ids"):
            imported = _example()
            registry = imported["payload"]["source_registry"]
            entry = registry["payload"]["entries"][0]
            if field == "parameters":
                entry["candidate"][field]["bluff_rate"] += 1
            elif field == "parent_ids":
                entry["candidate"][field] = ["nonexistent_parent"]
            else:
                selected = next(e for e in registry["payload"]["entries"] if e["selection_history"])
                entry[field] = copy.deepcopy(selected[field])
            imported["payload"]["source_registry"] = _reseal(registry)
            with self.subTest(field=field), self.assertRaises(ToolError):
                validate_historical_lineage(_reseal(imported))

    def test_resealed_source_selection_cannot_forge_champion(self) -> None:
        imported = _example()
        selection = next(a for a in imported["payload"]["original_artifacts"] if a["type"] == "selection")
        old_checksum = selection["checksum"]
        selection["payload"]["selected_candidates"].reverse()
        forged = _reseal(selection)
        originals = [forged if a["checksum"] == old_checksum else a for a in imported["payload"]["original_artifacts"]]
        imported["payload"]["original_artifacts"] = sorted(originals, key=lambda a: a["checksum"])
        registry = imported["payload"]["source_registry"]
        for evidence in registry["payload"]["artifacts"]:
            if evidence["checksum"] == old_checksum:
                evidence["checksum"] = forged["checksum"]
        registry["payload"]["artifacts"].sort(key=lambda a: a["checksum"])
        imported["payload"]["source_registry"] = _reseal(registry)
        with self.assertRaisesRegex(ToolError, "selection contradicts"):
            validate_historical_lineage(_reseal(imported))

    def test_unsupported_evidence_status_and_extra_fields_fail(self) -> None:
        for change in ("status", "extra"):
            imported = _example()
            if change == "status":
                imported["payload"]["evidence_status"] = "current"
            else:
                imported["payload"]["current_evaluations"] = []
            with self.subTest(change=change), self.assertRaises(ToolError):
                validate_historical_lineage(_reseal(imported))


if __name__ == "__main__":
    unittest.main()
