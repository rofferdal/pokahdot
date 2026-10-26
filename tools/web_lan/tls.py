"""Create local-only development certificates without changing device trust."""

from __future__ import annotations

import fcntl
import hashlib
import html
import ipaddress
from pathlib import Path
import shutil
import ssl
import subprocess

from .build import ROOT, BuildError, _atomic_json, resolve_output


def render_download_page(fingerprint: str, addresses: list[str]) -> str:
    """Explain the separate certificate installation and SSL trust steps."""
    games = "".join(
        f'<li><a href="https://{html.escape(address)}:8080/">'
        f'https://{html.escape(address)}:8080/</a></li>' for address in addresses
    )
    return (
        "<!doctype html><html lang='en'><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width,initial-scale=1'>"
        "<title>Pokahdot LAN certificate</title>"
        "<style>body{font:20px/1.5 system-ui;margin:24px;max-width:48rem}"
        "a{display:inline-block;padding:10px 0}code{overflow-wrap:anywhere}</style>"
        "<h1>Trust the local test certificate</h1>"
        "<p>Each test device needs this CA installed and trusted separately. "
        "Choosing Advanced and continuing through a browser warning does not install trust.</p>"
        "<h2>iPad</h2><ol>"
        "<li><a href='pokahdot-lan-ca.cer'>Download the iPad certificate (.cer)</a> in Safari.</li>"
        "<li>Open Settings &gt; General &gt; VPN &amp; Device Management. "
        "Install the Pokahdot Local LAN Development CA profile.</li>"
        "<li>Open Settings &gt; General &gt; About &gt; Certificate Trust Settings. "
        "Enable full trust for Pokahdot Local LAN Development CA.</li>"
        "<li>Close the game tab and reopen its HTTPS URL.</li></ol>"
        "<h2>Android</h2><ol>"
        "<li><a href='pokahdot-lan-ca.crt'>Download the Android certificate (.crt)</a>.</li>"
        "<li>Search device Settings for Install a certificate. Choose CA certificate "
        "and select the downloaded file. Menu names vary by manufacturer.</li>"
        "<li>Close the game tab and reopen its HTTPS URL.</li></ol>"
        "<p>This is a CA for HTTPS testing, not a Wi-Fi client certificate.</p>"
        "<h2>Open the game after trusting the CA</h2>"
        "<p>These links use the default game port 8080. For another port, use the server's printed HTTPS URL.</p>"
        "<ul>" + games + "</ul>"
        "<p>Trust persists beyond this session. Install this development CA only on your "
        "test devices and remove it when no longer needed. Private keys are not served.</p>"
        f"<p>CA SHA-256: <code>{html.escape(fingerprint)}</code></p></html>"
    )


def _openssl(*arguments: str) -> None:
    executable = shutil.which("openssl")
    if not executable:
        raise BuildError("OpenSSL is required to prepare local HTTPS certificates.")
    result = subprocess.run([executable, *arguments], capture_output=True, text=True,
                            timeout=60, check=False)
    if result.returncode:
        raise BuildError(f"OpenSSL certificate preparation failed: {result.stderr.strip()}")


def create_certificates(output: Path, addresses: list[str], root: Path = ROOT) -> dict:
    """Keep one private CA and issue a leaf for localhost and the chosen LAN IPs."""
    output = resolve_output(output, root)
    addresses = sorted({str(ipaddress.IPv4Address(value)) for value in addresses})
    if not addresses:
        raise BuildError("Provide at least one --address from the network command.")
    directory = output / "tls"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    if directory.is_symlink() or not directory.resolve().is_relative_to(output):
        raise BuildError("TLS directory must remain inside the LAN output directory.")
    directory.chmod(0o700)
    with (directory / "tls.lock").open("a+") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        ca_key, ca = directory / "ca.key", directory / "ca.pem"
        server_key, certificate = directory / "server.key", directory / "server.pem"
        if ca.exists() != ca_key.exists():
            raise BuildError("Local CA files are incomplete; restore them or choose a new output root.")
        if not ca.exists():
            config = directory / "ca.cnf"
            config.write_text("[req]\ndistinguished_name=dn\nx509_extensions=ca\nprompt=no\n"
                              "[dn]\nCN=Pokahdot Local LAN Development CA\n"
                              "[ca]\nbasicConstraints=critical,CA:TRUE,pathlen:0\n"
                              "keyUsage=critical,keyCertSign,cRLSign\n"
                              "subjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid:always\n")
            _openssl("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-sha256",
                     "-days", "365", "-config", str(config), "-keyout", str(ca_key),
                     "-out", str(ca))
            ca_key.chmod(0o600)
        _openssl("x509", "-in", str(ca), "-checkend", "86400", "-noout")
        config = directory / "server.cnf"
        san = ",".join(["DNS:localhost", "IP:127.0.0.1"] + [f"IP:{value}" for value in addresses])
        config.write_text("[req]\ndistinguished_name=dn\nprompt=no\n"
                          "[dn]\nCN=Pokahdot Local LAN\n"
                          "[server]\nbasicConstraints=critical,CA:FALSE\n"
                          "keyUsage=critical,digitalSignature,keyEncipherment\n"
                          "extendedKeyUsage=serverAuth\nsubjectAltName=" + san + "\n")
        request = directory / "server.csr"
        _openssl("req", "-new", "-newkey", "rsa:2048", "-nodes", "-sha256",
                 "-config", str(config), "-keyout", str(server_key), "-out", str(request))
        server_key.chmod(0o600)
        _openssl("x509", "-req", "-in", str(request), "-CA", str(ca), "-CAkey", str(ca_key),
                 "-CAcreateserial", "-days", "30", "-sha256", "-extfile", str(config),
                 "-extensions", "server", "-out", str(certificate))
        _openssl("verify", "-CAfile", str(ca), str(certificate))
        public = directory / "public"
        public.mkdir(exist_ok=True)
        if public.is_symlink() or not public.resolve().is_relative_to(directory.resolve()):
            raise BuildError("Public certificates must remain in the dedicated TLS public directory.")
        if any(path.is_symlink() or path.name not in {
            "pokahdot-lan-ca.crt", "pokahdot-lan-ca.cer", "index.html"
        } for path in public.iterdir()):
            raise BuildError("The public certificate directory contains unexpected files; use a clean directory.")
        shutil.copyfile(ca, public / "pokahdot-lan-ca.crt")
        _openssl("x509", "-in", str(ca), "-outform", "DER", "-out",
                 str(public / "pokahdot-lan-ca.cer"))
        fingerprint = hashlib.sha256(ssl.PEM_cert_to_DER_cert(ca.read_text())).hexdigest()
        (public / "index.html").write_text(render_download_page(fingerprint, addresses))
        result = {"certificate": str(certificate), "key": str(server_key), "ca_cert": str(ca),
                  "public_directory": str(public), "ca_sha256": fingerprint,
                  "addresses": addresses, "trust_installed": False}
        _atomic_json(directory / "tls.json", result)
        return result
