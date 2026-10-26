"""The LAN entry point chooses secure defaults and reports actionable errors."""

import contextlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools.web_lan.build import ROOT
from tools.web_lan.cli import main


class CliTests(unittest.TestCase):
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
