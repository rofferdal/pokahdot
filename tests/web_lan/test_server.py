from __future__ import annotations

import hashlib
import json
from pathlib import Path
import socket
import ssl
import tempfile
import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import HTTPSHandler, ProxyHandler, Request, build_opener, urlopen

from tools.web_lan.build import BuildError
from tools.web_lan.server import _request_stop, serve, server_status, stop_server
from tools.web_lan.tls import create_certificates


class ServerTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.output = self.root / "localtmp/web-lan"
        self.output.mkdir(parents=True)
        self.ids = ["a" * 32, "b" * 32]
        self.payloads: dict[str, dict] = {}
        self.invalid_builds: set[str] = set()
        for build_id in self.ids:
            export = self.output / "builds" / build_id / "export"
            export.mkdir(parents=True)
            files = {"index.html": b"<html>game</html>", "index.js": b"// js",
                     "index.wasm": b"wasm", "index.pck": b"pack"}
            for name, content in files.items():
                (export / name).write_bytes(content)
            metadata = {"build_id": build_id,
                        "files": {name: hashlib.sha256(content).hexdigest()
                                  for name, content in files.items()}}
            self.payloads[build_id] = metadata
            (export / "build-info.json").write_text(
                json.dumps(metadata, indent=2, sort_keys=True) + "\n")
        self.set_ready(self.ids[0])
        self.server_thread: threading.Thread | None = None
        self.port = 0
        self.verifier_patch = patch("tools.web_lan.server.verify_build", side_effect=self.verify)
        self.verifier = self.verifier_patch.start()
        self.addCleanup(self.verifier_patch.stop)

    def verify(self, _output, build_id, _root):
        if build_id in self.invalid_builds:
            raise BuildError("payload verification failed")
        return self.payloads[build_id]

    def set_ready(self, build_id: str, state: str = "ready") -> None:
        (self.output / "status.json").write_text(json.dumps({"state": state, "build_id": build_id}))

    def start(self, port: int = 0, bind: str = "127.0.0.1", tls: dict | None = None) -> None:
        def run() -> None:
            try:
                options = {} if tls is None else {
                    "cert": Path(tls["certificate"]), "key": Path(tls["key"]),
                    "ca_cert": Path(tls["ca_cert"])
                }
                serve(self.output, bind, port, root=self.root, **options)
            except BuildError as error:
                self.start_error = error

        self.start_error = None
        self.server_thread = threading.Thread(target=run, daemon=True)
        self.server_thread.start()
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            record = self.output / "server.json"
            if record.exists():
                self.port = json.loads(record.read_text())["port"]
                return
            if not self.server_thread.is_alive():
                break
            time.sleep(0.02)
        self.fail(f"Server did not start: {self.start_error}")

    def stop(self) -> None:
        if self.server_thread and self.server_thread.is_alive():
            stop_server(self.output, self.root)
            self.server_thread.join(timeout=3)

    def request(self, path: str, method: str = "GET", headers: dict | None = None):
        return urlopen(Request(f"http://127.0.0.1:{self.port}{path}", method=method,
                               headers=headers or {}), timeout=2)

    def test_idle_tls_client_does_not_block_other_requests_or_shutdown(self) -> None:
        tls = create_certificates(self.output, ["127.0.0.1"], self.root)
        self.start(tls=tls)
        idle = socket.create_connection(("127.0.0.1", self.port), timeout=2)
        try:
            opener = build_opener(ProxyHandler({}), HTTPSHandler(
                context=ssl.create_default_context(cafile=tls["ca_cert"])))
            with opener.open(f"https://127.0.0.1:{self.port}/", timeout=2) as response:
                self.assertEqual(response.status, 200)
            self.stop()
            self.assertFalse(self.server_thread.is_alive())
        finally:
            idle.close()
            self.stop()

    def test_asset_responses_are_uncached_and_have_web_mime_types(self) -> None:
        self.start()
        try:
            response = self.request("/")
            self.assertTrue(response.geturl().endswith(f"/builds/{self.ids[0]}/index.html"))
            for name, mime in (("index.html", "text/html"), ("index.js", "application/javascript"),
                               ("index.wasm", "application/wasm"), ("index.pck", "application/octet-stream"),
                               ("build-info.json", "application/json")):
                response = self.request(f"/builds/{self.ids[0]}/{name}")
                self.assertEqual(response.status, 200)
                self.assertTrue(response.headers["Content-Type"].startswith(mime))
                self.assertIn("no-store", response.headers["Cache-Control"])
                self.assertTrue(response.read())
            self.assertEqual(self.request("/__lan/status").status, 200)
        finally:
            self.stop()

    def test_diagnostics_page_contains_local_browser_evidence_and_public_build_only(self) -> None:
        self.start()
        try:
            metadata = self.payloads[self.ids[0]]
            metadata.update({"source_sha": "</script><script>bad()</script>",
                             "source_tree_state": "dirty",
                             "dirty_source_fingerprint": "c" * 64,
                             "absolute_private_path": "/private/secret"})
            shutdown_token = json.loads((self.output / "server.json").read_text())["token"]
            body = self.request("/__lan/").read()
            self.assertIn(b'"build_id":"' + self.ids[0].encode() + b'"', body)
            self.assertIn(b"captured_at_utc", body)
            for capability in (b"is_secure_context", b"inner_width", b"inner_height",
                               b"device_pixel_ratio", b"user_agent", b"platform",
                               b"max_touch_points", b"audio_context_available",
                               b"audio_worklet_available"):
                self.assertIn(capability, body)
            self.assertIn(b'href="/"', body)
            self.assertNotIn(shutdown_token.encode(), body)
            self.assertNotIn(b"/private/secret", body)
            self.assertNotIn(b"</script><script>bad()", body)
            self.assertIn(b"\\u003c/script\\u003e", body)
        finally:
            self.stop()

    def test_diagnostics_page_without_ready_build_does_not_require_metadata(self) -> None:
        self.start()
        try:
            self.set_ready(self.ids[1], "building")
            body = self.request("/__lan/").read()
            self.assertIn(b'<span id="build-state">building</span>', body)
            self.assertIn(b'id="public-build">null</script>', body)
        finally:
            self.stop()

    def test_only_immutable_export_files_are_served_and_old_build_stays_pinned(self) -> None:
        self.start()
        try:
            self.set_ready(self.ids[1])
            response = self.request(f"/builds/{self.ids[0]}/index.html")
            self.assertEqual(response.read(), b"<html>game</html>")
            for path in ("../../status.json", "%2e%2e/%2e%2e/status.json", "missing.txt"):
                with self.assertRaises(HTTPError) as caught:
                    self.request(f"/builds/{self.ids[0]}/{path}")
                self.assertEqual(caught.exception.code, 404)
        finally:
            self.stop()

    def test_pinned_build_remains_available_while_latest_build_is_failed(self) -> None:
        self.start()
        try:
            self.set_ready(self.ids[1], "failed")
            response = self.request(f"/builds/{self.ids[0]}/index.html")
            self.assertEqual(response.read(), b"<html>game</html>")
        finally:
            self.stop()

    def test_root_refuses_to_select_old_build_during_or_after_failed_rebuild(self) -> None:
        self.start()
        try:
            for state in ("building", "failed"):
                self.set_ready(self.ids[1], state)
                with self.assertRaises(HTTPError) as caught:
                    self.request("/")
                self.assertEqual(caught.exception.code, 503)
            body = self.request("/__lan/status").read()
            self.assertIn(b'"state": "failed"', body)
        finally:
            self.stop()

    def test_root_does_not_redirect_to_tampered_latest_export(self) -> None:
        self.start()
        try:
            self.invalid_builds.add(self.ids[0])
            with self.assertRaises(HTTPError) as caught:
                self.request("/")
            self.assertEqual(caught.exception.code, 503)
        finally:
            self.stop()

    def test_payload_hashes_are_checked_on_every_response_after_initial_validation(self) -> None:
        self.start()
        try:
            # The first request verifies and caches this build's metadata.
            self.assertEqual(self.request(f"/builds/{self.ids[0]}/index.js").read(), b"// js")
            export = self.output / "builds" / self.ids[0] / "export"
            (export / "index.js").write_bytes(b"modified after verification")
            with self.assertRaises(HTTPError) as asset_error:
                self.request(f"/builds/{self.ids[0]}/index.js")
            self.assertEqual(asset_error.exception.code, 409)
            (export / "build-info.json").write_text('{"modified": true}\n')
            with self.assertRaises(HTTPError) as info_error:
                self.request(f"/builds/{self.ids[0]}/build-info.json")
            self.assertEqual(info_error.exception.code, 409)
        finally:
            self.stop()

    def test_concurrent_first_requests_verify_the_build_only_once(self) -> None:
        self.start()
        self.verifier.reset_mock()
        original_verify = self.verify

        def slow_verify(output, build_id, root):
            time.sleep(0.1)
            return original_verify(output, build_id, root)

        self.verifier.side_effect = slow_verify
        try:
            barrier = threading.Barrier(3)

            def fetch(asset: str) -> bytes:
                barrier.wait(timeout=2)
                return self.request(f"/builds/{self.ids[0]}/{asset}").read()

            with ThreadPoolExecutor(max_workers=2) as workers:
                first = workers.submit(fetch, "index.js")
                second = workers.submit(fetch, "index.wasm")
                barrier.wait(timeout=2)
                self.assertEqual(first.result(timeout=3), b"// js")
                self.assertEqual(second.result(timeout=3), b"wasm")
            self.assertEqual(self.verifier.call_count, 1)
        finally:
            self.stop()

    def test_stop_requires_token_and_authenticated_stop_releases_port(self) -> None:
        self.start()
        try:
            status = server_status(self.output, self.root)
            self.assertNotIn("token", status["server"])
            with self.assertRaises(HTTPError) as caught:
                self.request("/__lan/stop", "POST", {"X-LAN-Stop-Token": "wrong"})
            self.assertEqual(caught.exception.code, 403)
            record = json.loads((self.output / "server.json").read_text())
            self.assertEqual((self.output / "server.json").stat().st_mode & 0o777, 0o600)
            self.assertEqual(self.request("/__lan/stop", "POST",
                                          {"X-LAN-Stop-Token": record["token"]}).read(),
                             b'{"stopping":true}\n')
            self.server_thread.join(timeout=3)
            self.assertFalse(self.server_thread.is_alive())
            self.assertFalse((self.output / "server.json").exists())
            with socket.socket() as probe:
                probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                probe.bind(("127.0.0.1", self.port))
        finally:
            self.stop()

    def test_port_in_use_is_reported_without_leaving_server_state(self) -> None:
        with socket.socket() as occupied:
            occupied.bind(("127.0.0.1", 0))
            occupied.listen()
            with self.assertRaisesRegex(BuildError, "Cannot bind LAN server"):
                serve(self.output, "127.0.0.1", occupied.getsockname()[1], root=self.root)
        self.assertFalse((self.output / "server.json").exists())

    def test_existing_server_lock_prevents_second_server(self) -> None:
        self.start()
        try:
            with self.assertRaisesRegex(BuildError, "already running"):
                serve(self.output, "127.0.0.1", 0, root=self.root)
        finally:
            self.stop()

    def test_stop_uses_the_specific_bind_address(self) -> None:
        self.start(bind="127.0.0.1")
        try:
            record = json.loads((self.output / "server.json").read_text())
            self.assertEqual(record["stop_host"], "127.0.0.1")
            self.assertEqual(stop_server(self.output, self.root), {"stopping": True})
            self.server_thread.join(timeout=3)
            self.assertFalse(self.server_thread.is_alive())
        finally:
            self.stop()

    def test_https_stop_uses_recorded_host_and_ca_for_trust(self) -> None:
        certificate = self.root / "server.pem"
        ca_certificate = self.root / "local-ca.pem"
        certificate.write_text("certificate")
        ca_certificate.write_text("CA")

        class FakeResponse:
            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self):
                return b'{"stopping":true}'

        class FakeOpener:
            def open(self, request, timeout):
                self.url = request.full_url
                return FakeResponse()

        opener = FakeOpener()
        with patch("tools.web_lan.server.ssl.create_default_context") as create_context, \
                patch("tools.web_lan.server.build_opener", return_value=opener):
            result = _request_stop({"tls": True, "stop_host": "192.168.39.105", "port": 8443,
                                    "ca_cert": str(ca_certificate), "cert": str(certificate)}, "secret")
        self.assertEqual(result, {"stopping": True})
        self.assertEqual(opener.url, "https://192.168.39.105:8443/__lan/stop")
        create_context.assert_called_once_with(cafile=str(ca_certificate))

    def test_startup_failure_after_bind_releases_socket_and_private_state(self) -> None:
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        with patch("tools.web_lan.server._atomic_private_json", side_effect=OSError("disk full")):
            with self.assertRaisesRegex(BuildError, "Cannot start LAN server: disk full"):
                serve(self.output, "127.0.0.1", port, root=self.root)
        self.assertFalse((self.output / "server.json").exists())
        with socket.socket() as probe:
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            probe.bind(("127.0.0.1", port))


if __name__ == "__main__":
    unittest.main()
