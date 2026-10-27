from __future__ import annotations

import concurrent.futures
import os
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

from tools.profile_evolution.artifacts import create_artifact, write_artifact_atomic
from tools.profile_evolution.atomic_write import publish_bytes_no_replace
from tools.profile_evolution.errors import ExitCode, ToolError
from tools.profile_evolution.profile_publisher import _write_new_file


class AtomicPublicationTests(unittest.TestCase):
    def test_competing_publishers_preserve_one_complete_winner_and_clean_temporary_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "winner.bin"
            rendezvous = threading.Barrier(2)
            original_link = os.link

            def competing_link(source: Path, target: Path) -> None:
                rendezvous.wait(timeout=5)
                original_link(source, target)

            def publish(contents: bytes) -> bool:
                try:
                    publish_bytes_no_replace(destination, contents)
                    return True
                except FileExistsError:
                    return False

            with mock.patch("tools.profile_evolution.atomic_write.os.link", side_effect=competing_link):
                with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                    results = list(pool.map(publish, [b"first" * 1000, b"second" * 1000]))
            self.assertEqual(sorted(results), [False, True])
            self.assertIn(destination.read_bytes(), [b"first" * 1000, b"second" * 1000])
            self.assertEqual(list(Path(directory).iterdir()), [destination])

    def test_file_sync_and_link_failures_never_publish_or_leave_temporary_files(self) -> None:
        for operation in ("fsync", "link"):
            with self.subTest(operation=operation), tempfile.TemporaryDirectory() as directory:
                destination = Path(directory) / "output"
                with mock.patch(
                    f"tools.profile_evolution.atomic_write.os.{operation}",
                    side_effect=OSError("injected publication failure"),
                ):
                    with self.assertRaises(OSError):
                        publish_bytes_no_replace(destination, b"complete payload")
                self.assertEqual(list(Path(directory).iterdir()), [])

    def test_directory_sync_failure_keeps_already_published_complete_destination(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "output"
            with mock.patch(
                "tools.profile_evolution.atomic_write.os.fsync",
                side_effect=[None, OSError("injected directory sync failure")],
            ):
                with self.assertRaises(OSError):
                    publish_bytes_no_replace(destination, b"complete payload")
            self.assertEqual(destination.read_bytes(), b"complete payload")
            self.assertEqual(list(Path(directory).iterdir()), [destination])

    def test_profile_publication_retains_utf8_bytes_and_file_only_sync_policy(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "new-parent" / "profile.tres"
            with mock.patch("tools.profile_evolution.atomic_write.os.fsync") as sync:
                _write_new_file(destination, "på\n")
            self.assertEqual(destination.read_bytes(), "på\n".encode("utf-8"))
            self.assertEqual(sync.call_count, 1)

    def test_wrappers_keep_distinct_error_contracts_for_racing_destinations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original_link = os.link

            def race(source: Path, target: Path) -> None:
                target.write_bytes(b"other publisher")
                original_link(source, target)

            wrappers = (
                (lambda path: write_artifact_atomic(path, create_artifact("test", {})),
                 "output_exists", ExitCode.IO_FAILURE),
                (lambda path: _write_new_file(path, "profile"),
                 "published_profile_exists", ExitCode.INVARIANT_FAILURE),
            )
            for index, (write, code, exit_code) in enumerate(wrappers):
                destination = root / f"output-{index}"
                with self.subTest(code=code), mock.patch(
                    "tools.profile_evolution.atomic_write.os.link", side_effect=race
                ):
                    with self.assertRaises(ToolError) as caught:
                        write(destination)
                self.assertEqual(caught.exception.code, code)
                self.assertEqual(caught.exception.exit_code, exit_code)
                self.assertEqual(destination.read_bytes(), b"other publisher")
            self.assertEqual(len(list(root.iterdir())), len(wrappers))

    def test_invalid_serialization_leaves_no_partial_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ToolError) as caught:
                write_artifact_atomic(Path(directory) / "invalid.json", {"value": float("nan")})
            self.assertEqual(caught.exception.code, "invalid_json_value")
            self.assertEqual(list(Path(directory).iterdir()), [])
