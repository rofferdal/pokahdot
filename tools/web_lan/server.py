"""Private, immutable-build HTTP serving for local Web exports."""

from __future__ import annotations

import fcntl
import hashlib
import hmac
import http.server
import ipaddress
import json
import mimetypes
import os
from pathlib import Path
import re
import secrets
import socketserver
import ssl
import threading
from urllib.error import URLError
from urllib.parse import unquote, urlsplit
from urllib.request import HTTPSHandler, ProxyHandler, Request, build_opener

from .build import ROOT, BuildError, _atomic_json, resolve_output, verify_build
from .diagnostics import render_diagnostics
from .network import local_candidate, network_addresses

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/javascript", ".js")


def _read_json(path: Path) -> dict | None:
    try:
        value = json.loads(path.read_text())
    except (OSError, ValueError):
        return None
    return value if isinstance(value, dict) else None


def server_status(output: Path, root: Path = ROOT) -> dict:
    """Return build and server state without exposing its shutdown token."""
    output = resolve_output(output, root)
    build = _read_json(output / "status.json")
    server = _read_json(output / "server.json")
    if server:
        server = {key: value for key, value in server.items() if key != "token"}
    return {"build": build, "server": server}


def _request_stop(record: dict, token: str) -> dict:
    scheme = "https" if record.get("tls") else "http"
    host = record.get("stop_host", "localhost" if record.get("tls") else "127.0.0.1")
    url = f"{scheme}://{host}:{int(record['port'])}/__lan/stop"
    context = None
    if record.get("tls"):
        trust_file = Path(record.get("ca_cert") or record.get("cert", ""))
        if not trust_file.is_file():
            raise BuildError("HTTPS trust certificate is unavailable; stop it with Ctrl+C in its terminal.")
        context = ssl.create_default_context(cafile=str(trust_file))
    handlers = [ProxyHandler({})]
    if context:
        handlers.append(HTTPSHandler(context=context))
    opener = build_opener(*handlers)
    request = Request(url, data=b"{}", headers={"X-LAN-Stop-Token": token}, method="POST")
    try:
        response = opener.open(request, timeout=4)
        with response:
            return json.loads(response.read().decode("utf-8"))
    except (URLError, OSError, ValueError, KeyError) as error:
        raise BuildError(f"Could not request LAN server shutdown: {error}. Use Ctrl+C in its terminal if needed.") from error


def stop_server(output: Path, root: Path = ROOT) -> dict:
    """Request a credential-authenticated graceful stop; never signal a PID."""
    output = resolve_output(output, root)
    record = _read_json(output / "server.json")
    if not record or not isinstance(record.get("token"), str):
        raise BuildError("No readable LAN server record; the server may already be stopped.")
    result = _request_stop(record, record["token"])
    return result


def _atomic_private_json(path: Path, document: dict) -> None:
    _atomic_json(path, document)
    path.chmod(0o600)


def _safe_export_file(export: Path, relative: str) -> Path | None:
    if not relative or "\\" in relative or "\x00" in relative:
        return None
    path = Path(relative)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        return None
    candidate = export.joinpath(*path.parts)
    try:
        if candidate.is_symlink() or not candidate.resolve().is_relative_to(export.resolve()):
            return None
        return candidate if candidate.is_file() else None
    except OSError:
        return None


class _ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def get_request(self):
        connection, address = super().get_request()
        connection.settimeout(15)
        return connection, address

    def process_request_thread(self, request, client_address):
        if isinstance(request, ssl.SSLSocket):
            try:
                request.do_handshake()
                # Asset transfers may take longer than a handshake on Wi-Fi.
                request.settimeout(120)
            except OSError:
                self.shutdown_request(request)
                return
        super().process_request_thread(request, client_address)


class _Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "PokahdotLAN/1"
    sys_version = ""

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"[{self.log_date_time_string()}] {self.address_string()} {fmt % args}")

    def _send(self, status: int, body: bytes = b"", content_type: str = "text/plain; charset=utf-8",
              extra: dict[str, str] | None = None) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.send_header("X-Content-Type-Options", "nosniff")
        for name, value in (extra or {}).items():
            self.send_header(name, value)
        self.end_headers()
        if self.command != "HEAD" and body:
            self.wfile.write(body)

    def _status(self) -> dict | None:
        return _read_json(self.server.output / "status.json")  # type: ignore[attr-defined]

    def _metadata_for(self, build_id: str) -> dict:
        with self.server.verify_lock:  # type: ignore[attr-defined]
            if build_id not in self.server.verified:  # type: ignore[attr-defined]
                metadata = verify_build(self.server.output, build_id, self.server.root)  # type: ignore[attr-defined]
                self.server.metadata[build_id] = metadata  # type: ignore[attr-defined]
                self.server.verified.add(build_id)  # type: ignore[attr-defined]
            return self.server.metadata[build_id]  # type: ignore[attr-defined]

    def do_GET(self) -> None:
        parsed = urlsplit(self.path)
        route = unquote(parsed.path)
        if route in {"/__lan", "/__lan/"}:
            status = self._status()
            state = status.get("state", "missing") if status else "missing"
            metadata = None
            if status and state == "ready":
                build_id = status.get("build_id", "")
                if isinstance(build_id, str) and re.fullmatch(r"[0-9a-f]{32}", build_id):
                    try:
                        metadata = self._metadata_for(build_id)
                    except BuildError:
                        state = "unavailable"
            body = render_diagnostics(state, metadata)
            self._send(200, body, "text/html; charset=utf-8")
            return
        if route == "/__lan/status":
            status = self._status()
            body = json.dumps({"state": status.get("state", "missing") if status else "missing",
                               "ready": bool(status and status.get("state") == "ready"),
                               "build_id": status.get("build_id") if status else None}).encode()
            self._send(200, body, "application/json; charset=utf-8")
            return
        if route == "/" or route == "":
            status = self._status()
            if not status or status.get("state") != "ready":
                state = status.get("state", "missing") if status else "missing"
                self._send(503, f"LAN export is {state}; build the game before serving it.\n".encode())
                return
            build_id = status.get("build_id", "")
            if not re.fullmatch(r"[0-9a-f]{32}", build_id):
                self._send(503, b"LAN build status has an invalid build ID.\n")
                return
            try:
                self._metadata_for(build_id)
            except BuildError as error:
                self._send(503, f"LAN build is unavailable: {error}\n".encode())
                return
            self._send(302, b"", extra={"Location": f"/builds/{build_id}/index.html"})
            return
        match = re.fullmatch(r"/builds/([0-9a-f]{32})/(.*)", route)
        if not match:
            self._send(404, b"Not found\n")
            return
        build_id, relative = match.groups()
        try:
            metadata = self._metadata_for(build_id)
        except BuildError as error:
            self._send(404, f"Build is unavailable: {error}\n".encode())
            return
        export = self.server.output / "builds" / build_id / "export"  # type: ignore[attr-defined]
        path = _safe_export_file(export, relative)
        if path is None:
            self._send(404, b"Not found\n")
            return
        if relative != "build-info.json" and relative not in metadata.get("files", {}):
            self._send(404, b"Not found\n")
            return
        try:
            body = path.read_bytes()
        except OSError:
            self._send(404, b"Not found\n")
            return
        if relative == "build-info.json":
            expected_body = (json.dumps(metadata, indent=2, sort_keys=True) + "\n").encode("utf-8")
            expected_hash = hashlib.sha256(expected_body).hexdigest()
        else:
            expected_hash = metadata.get("files", {}).get(relative)
        if not expected_hash or not hmac.compare_digest(hashlib.sha256(body).hexdigest(), expected_hash):
            self._send(409, b"Build payload changed after verification; rebuild before serving it.\n")
            return
        content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        self._send(200, body, content_type)

    def do_HEAD(self) -> None:
        self.do_GET()

    def do_POST(self) -> None:
        if urlsplit(self.path).path != "/__lan/stop":
            self._send(404, b"Not found\n")
            return
        supplied = self.headers.get("X-LAN-Stop-Token", "")
        if not hmac.compare_digest(supplied, self.server.stop_token):  # type: ignore[attr-defined]
            self._send(403, b"Forbidden\n")
            return
        self._send(200, b'{"stopping":true}\n', "application/json; charset=utf-8")
        threading.Thread(target=self.server.shutdown, daemon=True).start()


def serve(output: Path, bind: str = "0.0.0.0", port: int = 8080,
          cert: Path | None = None, key: Path | None = None, root: Path = ROOT,
          ca_cert: Path | None = None) -> None:
    """Serve only validated immutable LAN builds until Ctrl+C or authenticated stop."""
    output = resolve_output(output, root)
    status = _read_json(output / "status.json")
    if not status or status.get("state") != "ready":
        raise BuildError("LAN export is not ready; run the build command successfully before serving.")
    if not isinstance(port, int) or not 0 <= port <= 65535:
        raise BuildError("Port must be between 0 and 65535.")
    if (cert is None) != (key is None):
        raise BuildError("Provide both --cert and --key to enable HTTPS.")
    tls = cert is not None
    cert_path = (cert.resolve() if cert else None)
    key_path = (key.resolve() if key else None)
    ca_cert_path = (ca_cert.resolve() if ca_cert else None)
    if tls and (not cert_path.is_file() or not key_path.is_file()):
        raise BuildError("HTTPS certificate and key must both exist.")
    if ca_cert_path is not None and not ca_cert_path.is_file():
        raise BuildError("HTTPS CA certificate must exist.")
    if ca_cert_path is not None and not tls:
        raise BuildError("--ca-cert requires HTTPS certificate and key arguments.")
    output.mkdir(parents=True, exist_ok=True)
    lock = (output / "server.lock").open("a+")
    try:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise BuildError("A LAN server is already running for this output directory.") from error
        try:
            httpd = _ThreadingHTTPServer((bind, port), _Handler)
        except OSError as error:
            raise BuildError(f"Cannot bind LAN server to {bind}:{port}: {error}.") from error
        token: str | None = None
        try:
            if tls:
                context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                context.load_cert_chain(str(cert_path), str(key_path))
                # Defer handshakes to each request worker. An idle preconnect or
                # a client awaiting certificate approval must not block accept.
                httpd.socket = context.wrap_socket(
                    httpd.socket, server_side=True, do_handshake_on_connect=False
                )
            token = secrets.token_urlsafe(32)
            httpd.output = output
            httpd.root = root.resolve()
            httpd.stop_token = token
            httpd.verified = set()
            httpd.metadata = {}
            httpd.verify_lock = threading.Lock()
            # Wildcard HTTPS stop requests use localhost and require localhost
            # in the certificate SAN. Explicit binds retain their own SAN name.
            stop_host = "localhost" if tls and bind == "0.0.0.0" else (
                "127.0.0.1" if bind == "0.0.0.0" else bind)
            record = {"state": "running", "pid": os.getpid(), "bind": bind,
                      "port": httpd.server_address[1], "tls": tls,
                      "stop_host": stop_host, "token": token,
                      "cert": str(cert_path) if cert_path else None,
                      "ca_cert": str(ca_cert_path) if ca_cert_path else None}
            _atomic_private_json(output / "server.json", record)
            scheme = "https" if tls else "http"
            lan_ip = local_candidate(bind)
            lan_host = f"[{lan_ip}]" if ":" in lan_ip else lan_ip
            lan_url = f"{scheme}://{lan_host}:{record['port']}/"
            print(f"LAN server ready ({'HTTPS' if tls else 'HTTP'}). Ctrl+C or use the stop command.")
            host_address = "localhost" if bind == "0.0.0.0" else bind
            try:
                if ipaddress.ip_address(host_address).is_unspecified:
                    host_address = "localhost"
            except ValueError:
                host_address = "localhost"
            host_literal = f"[{host_address}]" if ":" in host_address else host_address
            host_url = f"{scheme}://{host_literal}:{record['port']}/"
            print(f"Host smoke-test URL: {host_url}")
            print(f"LAN URL: {lan_url}")
            print(f"Bind: {bind}:{record['port']}")
            if bind == "0.0.0.0":
                for candidate in network_addresses():
                    print(f"LAN candidate ({candidate['label']} / {candidate['interface']}): "
                          f"{scheme}://{candidate['address']}:{record['port']}/")
            httpd.serve_forever(poll_interval=0.25)
        finally:
            httpd.server_close()
            current = _read_json(output / "server.json")
            if token and current and current.get("token") == token:
                try:
                    (output / "server.json").unlink()
                except FileNotFoundError:
                    pass
    except (OSError, ssl.SSLError) as error:
        raise BuildError(f"Cannot start LAN server: {error}.") from error
    except KeyboardInterrupt:
        print("\nStopping LAN server.")
    finally:
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
        lock.close()
