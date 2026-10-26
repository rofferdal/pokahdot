"""The LAN entry point chooses secure defaults and reports actionable errors."""

import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from tools.web_lan.build import ROOT
from tools.web_lan.cli import main


class CliTests(unittest.TestCase):
    def test_failed_build_exits_nonzero_and_invalidates_latest_status(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "localtmp") as name:
            output = Path(name)
            (output / "status.json").write_text(json.dumps({"state": "ready", "build_id": "old"}))
            result = subprocess.run(
                [sys.executable, str(ROOT / "tools/web-lan"), "build", "--output", name,
                 "--godot", str(output / "missing-godot")],
                cwd=ROOT, capture_output=True, text=True, timeout=15, check=False,
            )
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn("Godot executable not found", result.stderr)
            self.assertEqual(json.loads((output / "status.json").read_text())["state"], "failed")
            self.assertFalse((output / "server.json").exists())

    def test_failed_serve_exits_nonzero_without_publishing_server_state(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "localtmp") as name:
            result = subprocess.run(
                [sys.executable, str(ROOT / "tools/web-lan"), "serve", "--output", name],
                cwd=ROOT, capture_output=True, text=True, timeout=15, check=False,
            )
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn("Prepare HTTPS", result.stderr)
            self.assertFalse((Path(name) / "server.json").exists())

    def test_serve_uses_managed_https_and_passes_the_ca_to_shutdown(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "localtmp") as name:
            output = Path(name)
            tls = output / "tls"
            tls.mkdir()
            for item in ("ca.pem", "server.pem", "server.key"):
                (tls / item).touch()
            with patch("tools.web_lan.server.serve") as serve:
                self.assertEqual(main(["serve", "--output", name]), 0)
            serve.assert_called_once_with(output, "0.0.0.0", 8080,
                                          tls / "server.pem", tls / "server.key", ca_cert=tls / "ca.pem")

    def test_missing_certificates_fail_clearly_and_explicit_http_is_available(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "localtmp") as name:
            errors = io.StringIO()
            with contextlib.redirect_stderr(errors):
                self.assertEqual(main(["serve", "--output", name]), 1)
            self.assertIn("Prepare HTTPS", errors.getvalue())
            with patch("tools.web_lan.server.serve") as serve:
                self.assertEqual(main(["serve", "--output", name, "--http", "--bind", "127.0.0.1"]), 0)
            self.assertEqual(serve.call_args.args[1], "127.0.0.1")
