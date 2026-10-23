from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.profile_evolution.artifacts import (
    artifact_checksum,
    canonical_json_bytes,
    create_artifact,
    load_json_object,
    validate_artifact_envelope,
    write_artifact_atomic,
)
from tools.profile_evolution.errors import ExitCode, ToolError


class ArtifactTests(unittest.TestCase):
    def test_canonical_json_is_sorted_compact_utf8_with_newline(self) -> None:
        self.assertEqual(
            canonical_json_bytes({"z": "på", "a": [2, 1]}),
            b'{"a":[2,1],"z":"p\xc3\xa5"}\n',
        )

    def test_artifact_checksum_excludes_checksum_field(self) -> None:
        artifact = create_artifact("generation_manifest", {"generation": 0})
        original = artifact["checksum"]
        artifact["checksum"] = "ignored while calculating"
        self.assertEqual(artifact_checksum(artifact), original)

    def test_envelope_rejects_unknown_fields_and_checksum_changes(self) -> None:
        artifact = create_artifact("generation_manifest", {"generation": 0})
        artifact["extra"] = True
        with self.assertRaises(ToolError):
            validate_artifact_envelope(artifact)
        artifact.pop("extra")
        artifact["payload"]["generation"] = 1
        with self.assertRaises(ToolError):
            validate_artifact_envelope(artifact)

    def test_strict_loader_rejects_duplicate_keys_and_non_object_root(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            duplicate = Path(directory) / "duplicate.json"
            duplicate.write_text('{"a":1,"a":2}', encoding="utf-8")
            with self.assertRaises(ToolError) as duplicate_context:
                load_json_object(duplicate)
            self.assertEqual(duplicate_context.exception.exit_code, ExitCode.INVALID_INPUT)
            array = Path(directory) / "array.json"
            array.write_text("[]", encoding="utf-8")
            with self.assertRaises(ToolError):
                load_json_object(array)

    def test_atomic_write_rejects_existing_output_without_modifying_it(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "artifact.json"
            artifact = create_artifact("generation_manifest", {"generation": 0})
            write_artifact_atomic(output, artifact)
            expected = canonical_json_bytes(artifact)
            self.assertEqual(output.read_bytes(), expected)
            with self.assertRaises(ToolError) as context:
                write_artifact_atomic(output, create_artifact("other", {}))
            self.assertEqual(context.exception.exit_code, ExitCode.IO_FAILURE)
            self.assertEqual(output.read_bytes(), expected)
            self.assertEqual(list(Path(directory).glob("*.tmp")), [])

    def test_atomic_write_does_not_clobber_target_created_during_publish(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "artifact.json"
            raced_content = b"created-by-another-writer\n"
            original_link = __import__("os").link

            def race_link(source: object, destination: object) -> None:
                Path(destination).write_bytes(raced_content)
                original_link(source, destination)

            with mock.patch("tools.profile_evolution.artifacts.os.link", side_effect=race_link):
                with self.assertRaises(ToolError) as context:
                    write_artifact_atomic(output, create_artifact("candidate_bundle", {}))
            self.assertEqual(context.exception.code, "output_exists")
            self.assertEqual(output.read_bytes(), raced_content)
            self.assertEqual(list(Path(directory).glob("*.tmp")), [])

    def test_written_artifact_is_valid_json_object(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "artifact.json"
            artifact = create_artifact("candidate_bundle", {"ids": ["a"]})
            write_artifact_atomic(output, artifact)
            self.assertEqual(json.loads(output.read_text(encoding="utf-8")), artifact)
