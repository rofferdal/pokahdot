"""Local HTTPS certificate generation and private/public boundary regressions."""

from pathlib import Path
import json
import ssl
import subprocess
import tempfile
import unittest

from tools.web_lan.build import ROOT, BuildError
from tools.web_lan.tls import create_certificates


class TlsTests(unittest.TestCase):
    def test_ca_is_reused_and_server_cert_covers_localhost_and_lan(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "localtmp") as name:
            root = Path(name)
            result = create_certificates(Path("localtmp/site"), ["192.168.1.42"], root)
            self.assertFalse(result["trust_installed"])
            first_ca = Path(result["ca_cert"]).read_bytes()
            context = ssl.create_default_context(cafile=result["ca_cert"])
            self.assertTrue(context.check_hostname)
            info = ssl._ssl._test_decode_cert(result["certificate"])
            self.assertIn(("DNS", "localhost"), info["subjectAltName"])
            self.assertIn(("IP Address", "192.168.1.42"), info["subjectAltName"])
            self.assertEqual(Path(result["key"]).stat().st_mode & 0o777, 0o600)
            public = Path(result["public_directory"])
            self.assertEqual({p.name for p in public.iterdir()}, {
                "index.html", "pokahdot-lan-ca.crt", "pokahdot-lan-ca.cer"
            })
            instructions = (public / "index.html").read_text()
            self.assertIn("Enable full trust", instructions)
            self.assertIn("VPN &amp; Device Management", instructions)
            self.assertIn("https://192.168.1.42:8080/", instructions)
            self.assertIn("does not install trust", instructions)
            again = create_certificates(Path("localtmp/site"), ["192.168.1.43"], root)
            self.assertEqual(Path(again["ca_cert"]).read_bytes(), first_ca)
            self.assertEqual(again["ca_sha256"], result["ca_sha256"])
            self.assertEqual(subprocess.run([
                "openssl", "verify", "-CAfile", again["ca_cert"], again["certificate"]
            ], capture_output=True).returncode, 0)
            stored = json.loads((root / "localtmp/site/tls/tls.json").read_text())
            self.assertEqual(stored["addresses"], ["192.168.1.43"])

    def test_invalid_addresses_and_unexpected_public_files_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / "localtmp") as name:
            root = Path(name)
            with self.assertRaises(ValueError):
                create_certificates(Path("localtmp/site"), ["not-an-ip"], root)
            public = root / "localtmp/site/tls/public"
            public.mkdir(parents=True)
            (public / "unexpected.key").write_text("Do not publish arbitrary files")
            with self.assertRaises(BuildError):
                create_certificates(Path("localtmp/site"), ["192.168.1.42"], root)
