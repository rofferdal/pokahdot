from __future__ import annotations

from pathlib import Path
import json
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools.web_lan.build import BuildError, ROOT, build_project, load_status, resolve_output, verify_build


class BuildTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / "localtmp/web-lan"
        for name in ("scripts", "scenes", "resources", "assets"):
            (self.root / name).mkdir()
        (self.root / "scripts/game.gd").write_text("extends RefCounted\n")
        (self.root / ".gitignore").write_text("localtmp/\n")
        for name in ("project.godot", "export_presets.cfg", "icon.svg"):
            (self.root / name).write_bytes((ROOT / name).read_bytes())
        self.godot = self.root / "godot"
        self.godot.write_text("#!/bin/sh\n")
        self.godot.chmod(0o755)
        self.real_run = subprocess.run
        self.real_run(["git", "init", "-q", str(self.root)], check=True)
        self.real_run(["git", "-C", str(self.root), "add", "."], check=True)
        self.real_run(["git", "-C", str(self.root), "-c", "user.name=Test",
                       "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture"], check=True)
        self.mode = "success"
        self.calls: list[list[str]] = []
        self.mock = patch("tools.web_lan.build.subprocess.run", side_effect=self._run)
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def _run(self, arguments, **kwargs):
        if arguments[0] == "git":
            return self.real_run(arguments, **kwargs)
        self.calls.append(arguments)
        if "--version" in arguments:
            return subprocess.CompletedProcess(arguments, 0, "4.7.2.stable.test\n", "")
        if arguments[0] == "strings":
            return subprocess.CompletedProcess(arguments, 0, "res://scenes/main.tscn\n", "")
        if arguments[0] == "make":
            if self.mode == "check_failure":
                return subprocess.CompletedProcess(arguments, 2)
            if self.mode == "source_changed":
                (self.root / "scripts/game.gd").write_text("extends Resource\n")
        if "--import" in arguments and self.mode == "import_failure":
            kwargs["stdout"].write("SCRIPT ERROR: Broken script\n")
        if "--export-release" in arguments:
            if self.mode == "missing_template":
                kwargs["stdout"].write("ERROR: No export template found at expected location.\n")
                return subprocess.CompletedProcess(arguments, 0)
            export = Path(arguments[-1]).parent
            (export / "index.html").write_text('<html><script src="index.js"></script></html>')
            (export / "index.js").write_text("// exported runtime")
            (export / "index.pck").write_bytes(b"GDPC payload")
            if self.mode != "missing_payload":
                (export / "index.wasm").write_bytes(b"wasm payload")
        return subprocess.CompletedProcess(arguments, 0)

    def build(self) -> dict:
        return build_project(str(self.godot), self.output, self.root)

    def test_dirty_production_snapshot_is_checked_and_integrity_verified(self) -> None:
        (self.root / "scripts/game.gd").write_text("extends Resource\n")
        metadata = self.build()
        self.assertEqual(metadata["source_tree_state"], "dirty")
        self.assertEqual(len(metadata["dirty_source_fingerprint"]), 64)
        self.assertEqual(load_status(self.output, self.root)["state"], "ready")
        self.assertEqual(verify_build(self.output, metadata["build_id"], self.root), metadata)
        self.assertEqual(self.calls[1][0], "make")
        export = self.output / "builds" / metadata["build_id"] / "export"
        (export / "index.js").write_text("corrupt or stale content")
        with self.assertRaisesRegex(BuildError, "hashes have changed"):
            verify_build(self.output, metadata["build_id"], self.root)

    def test_failed_rebuild_invalidates_ready_status_and_retains_old_export(self) -> None:
        previous = self.build()
        self.mode = "missing_payload"
        with self.assertRaisesRegex(BuildError, "index.wasm"):
            self.build()
        status = load_status(self.output, self.root)
        self.assertEqual(status["state"], "failed")
        self.assertNotEqual(status["build_id"], previous["build_id"])
        self.assertTrue((self.output / "builds" / previous["build_id"] / "export/index.html").is_file())

    def test_zero_exit_import_error_and_missing_template_never_publish(self) -> None:
        for mode, message in (("import_failure", "Broken script"),
                              ("missing_template", "No export template")):
            with self.subTest(mode=mode):
                self.mode = mode
                with self.assertRaisesRegex(BuildError, message):
                    self.build()
                self.assertEqual(load_status(self.output, self.root)["state"], "failed")

    def test_failed_checks_and_source_change_stop_before_export(self) -> None:
        for mode in ("check_failure", "source_changed"):
            with self.subTest(mode=mode):
                self.mode = mode
                self.calls.clear()
                with self.assertRaises(BuildError):
                    self.build()
                self.assertFalse(any("--export-release" in call for call in self.calls))
                self.assertEqual(load_status(self.output, self.root)["state"], "failed")

    def test_output_escape_and_invalid_build_id_are_rejected(self) -> None:
        with self.assertRaises(BuildError):
            resolve_output(self.root / "build/web", self.root)
        with self.assertRaises(BuildError):
            verify_build(self.output, "../../project", self.root)

    def test_manifest_tampering_and_unsafe_html_reference_are_rejected(self) -> None:
        metadata = self.build()
        export = self.output / "builds" / metadata["build_id"] / "export"
        public = export / "build-info.json"
        document = json.loads(public.read_text())
        document["source_sha"] = "forged"
        public.write_text(json.dumps(document))
        with self.assertRaisesRegex(BuildError, "private build record"):
            verify_build(self.output, metadata["build_id"], self.root)
        public.write_text(json.dumps(metadata))
        (export / "index.html").write_text('<script src="../project/secret.js"></script>')
        with self.assertRaisesRegex(BuildError, "Unsafe or missing"):
            verify_build(self.output, metadata["build_id"], self.root)

    def test_export_directory_symlink_is_never_served(self) -> None:
        metadata = self.build()
        directory = self.output / "builds" / metadata["build_id"]
        export = directory / "export"
        original = directory / "original-export"
        export.rename(original)
        export.symlink_to(original, target_is_directory=True)
        with self.assertRaisesRegex(BuildError, "path escapes"):
            verify_build(self.output, metadata["build_id"], self.root)


if __name__ == "__main__":
    unittest.main()
