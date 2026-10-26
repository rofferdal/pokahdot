"""Checked, isolated production exports for local LAN development."""

from __future__ import annotations

import configparser
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
from html import escape
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from urllib.parse import unquote, urlsplit
import uuid

ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATHS = ("scripts", "scenes", "resources", "assets", "project.godot",
                "export_presets.cfg", "icon.svg", "icon.svg.import", "tools", "tests",
                "Makefile", "requirements-dev.txt", ".gutconfig.json")


class BuildError(RuntimeError):
    """An actionable local build or artifact validation failure."""


def resolve_output(output: Path, root: Path = ROOT) -> Path:
    root = root.resolve()
    allowed = root / "localtmp"
    resolved = (output if output.is_absolute() else root / output).resolve()
    if allowed.resolve() != allowed or resolved == allowed or not resolved.is_relative_to(allowed):
        raise BuildError("LAN output must be a subdirectory of the project's localtmp directory.")
    return resolved


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _atomic_json(path: Path, document: dict) -> None:
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
        json.dump(document, file, indent=2, sort_keys=True)
        file.write("\n")
        file.flush()
        os.fsync(file.fileno())
        temporary = Path(file.name)
    os.replace(temporary, path)


def load_status(output: Path, root: Path = ROOT) -> dict:
    output = resolve_output(output, root)
    try:
        document = json.loads((output / "status.json").read_text())
    except (OSError, ValueError) as error:
        raise BuildError("No readable LAN build status; run the build command first.") from error
    if not isinstance(document, dict) or document.get("state") not in {"building", "failed", "ready"}:
        raise BuildError("LAN build status is invalid; rebuild before serving.")
    return document


def _git(root: Path, *arguments: str) -> bytes:
    result = subprocess.run(["git", "-C", str(root), *arguments], capture_output=True, check=False)
    if result.returncode:
        raise BuildError("Cannot record Git provenance for the LAN build.")
    return result.stdout


def _source_identity(root: Path) -> dict:
    paths = _git(root, "ls-files", "-z", "--cached", "--others", "--exclude-standard",
                 "--", *SOURCE_PATHS).split(b"\0")
    digest = hashlib.sha256()
    for raw in sorted(set(paths) - {b""}):
        path = root / os.fsdecode(raw)
        digest.update(raw + b"\0")
        digest.update(path.read_bytes() if path.is_file() else b"<deleted>")
    dirty = bool(_git(root, "status", "--porcelain", "--untracked-files=all").strip())
    return {
        "source_sha": _git(root, "rev-parse", "HEAD").decode().strip(),
        "source_tree_state": "dirty" if dirty else "clean",
        "dirty_source_fingerprint": digest.hexdigest() if dirty else "",
        "execution_source_sha256": digest.hexdigest(),
    }


def _configuration(root: Path) -> None:
    def read(name: str) -> configparser.ConfigParser:
        parser = configparser.ConfigParser(interpolation=None)
        parser.read_string("[godot_header]\n" + (root / name).read_text())
        return parser
    project = read("project.godot")
    preset = read("export_presets.cfg")
    if (project.get("application", "run/main_scene") != '"res://scenes/main.tscn"'
            or project.get("rendering", "renderer/rendering_method") != '"gl_compatibility"'
            or preset.get("preset.0", "name") != '"Web"'
            or preset.get("preset.0", "platform") != '"Web"'
            or preset.get("preset.0.options", "variant/thread_support") != "false"):
        raise BuildError("LAN builds require the production main scene and single-threaded Compatibility Web preset.")
    excluded = set(preset.get("preset.0", "exclude_filter").strip('"').split(","))
    required = {item for folder in ("addons", "tests", "localtmp", "artifacts")
                for item in (folder + "/*", folder + "/**/*")}
    if not required.issubset(excluded):
        raise BuildError("Web preset must exclude development-only directories.")


def _logged(arguments: list[str], root: Path, path: Path, timeout: int) -> None:
    with path.open("w") as log:
        result = subprocess.run(arguments, cwd=root, stdout=log, stderr=subprocess.STDOUT,
                                timeout=timeout, check=False)
    content = path.read_text(errors="replace")
    if result.returncode or "ERROR:" in content or "SCRIPT ERROR:" in content:
        errors = [line for line in content.splitlines() if "ERROR:" in line]
        reason = errors[0] if errors else f"process exited with status {result.returncode}"
        raise BuildError(f"{path.name}: {reason}. See {path}.")


class _References(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.paths: list[str] = []

    def handle_starttag(self, _tag: str, attrs: list[tuple[str, str | None]]) -> None:
        for name, value in attrs:
            if name in {"src", "href"} and value:
                url = urlsplit(value)
                if not url.scheme and not url.netloc and url.path:
                    self.paths.append(unquote(url.path))


class _DocumentTitle(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.openings = 0
        self.closings = 0
        self.in_title = False
        self.malformed = False
        self.text: list[str] = []

    def handle_starttag(self, tag: str, _attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() == "title":
            self.openings += 1
            if self.in_title:
                self.malformed = True
            self.in_title = True
        elif self.in_title:
            self.malformed = True

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "title":
            self.closings += 1
            if not self.in_title:
                self.malformed = True
            self.in_title = False
        elif self.in_title:
            self.malformed = True

    def handle_data(self, data: str) -> None:
        if self.in_title:
            self.text.append(data)


def _stamp_browser_title(export: Path, build_id: str) -> str:
    index = export / "index.html"
    document = index.read_text()
    title_parser = _DocumentTitle()
    title_parser.feed(document)
    title_pattern = re.compile(r"(?is)(<title\b[^>]*>)(.*?)(</title\s*>)")
    matches = list(title_pattern.finditer(document))
    original_title = "".join(title_parser.text).strip()
    if (
        title_parser.openings != 1
        or title_parser.closings != 1
        or title_parser.in_title
        or title_parser.malformed
        or len(matches) != 1
        or not original_title
    ):
        raise BuildError("LAN export must contain exactly one HTML title.")

    browser_title = f"{original_title} · LAN {build_id[:8]}"
    match = matches[0]
    stamped_title = (
        match.group(1) + escape(browser_title) + match.group(3)
        + f'<meta name="pokahdot-lan-build" content="{build_id}">'
    )
    index.write_text(document[:match.start()] + stamped_title + document[match.end():])
    return browser_title


def _payloads(export: Path) -> dict[str, str]:
    files = {path.relative_to(export).as_posix(): path for path in export.rglob("*")
             if path.is_file() and path.name != "build-info.json"}
    if any(path.is_symlink() or not path.resolve().is_relative_to(export.resolve())
           for path in files.values()):
        raise BuildError("LAN export contains a symlink or a path outside its export directory.")
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        if name not in files or not files[name].stat().st_size:
            raise BuildError(f"Incomplete Web export: missing or empty {name}.")
    references = _References()
    references.feed(files["index.html"].read_text())
    for name in references.paths:
        if name.startswith("/") or "\\" in name or ".." in Path(name).parts or name not in files:
            raise BuildError(f"Unsafe or missing HTML-referenced payload: {name}.")
    if any(part in {"addons", "tests", "localtmp", "artifacts", ".git"}
           for name in files for part in Path(name).parts):
        raise BuildError("LAN export contains development-only directories.")
    strings = subprocess.run(["strings", str(files["index.pck"])], capture_output=True,
                             text=True, check=False)
    if strings.returncode or re.search(r"(?:^|/)(?:addons|tests|localtmp|artifacts)/", strings.stdout, re.M):
        raise BuildError("Cannot verify that the game pack excludes development-only content.")
    return {name: _sha(path) for name, path in sorted(files.items())}


def verify_build(output: Path, build_id: str, root: Path = ROOT) -> dict:
    output = resolve_output(output, root)
    if not isinstance(build_id, str) or not re.fullmatch(r"[0-9a-f]{32}", build_id):
        raise BuildError("Invalid LAN build ID.")
    directory = output / "builds" / build_id
    export = directory / "export"
    if (directory.is_symlink() or not directory.resolve().is_relative_to(output)
            or export.is_symlink() or not export.resolve().is_relative_to(directory.resolve())):
        raise BuildError("LAN build path escapes its output directory.")
    try:
        metadata = json.loads((directory / "export/build-info.json").read_text())
        record = json.loads((directory / "record.json").read_text())
        if metadata != record or metadata.get("build_id") != build_id:
            raise BuildError("LAN build metadata does not match its private build record.")
        if _payloads(export) != metadata.get("files"):
            raise BuildError("LAN export payload hashes have changed; rebuild before serving.")
    except (OSError, ValueError, AttributeError) as error:
        raise BuildError("LAN build metadata or payloads are missing or unreadable.") from error
    return metadata


@contextmanager
def _build_lock(output: Path):
    with (output / "build.lock").open("a+") as file:
        try:
            fcntl.flock(file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise BuildError("Another LAN build is already running for this output directory.") from error
        try:
            yield
        finally:
            fcntl.flock(file.fileno(), fcntl.LOCK_UN)


def build_project(godot: str, output: Path, root: Path = ROOT) -> dict:
    root = root.resolve()
    output = resolve_output(output, root)
    output.mkdir(parents=True, exist_ok=True)
    (root / "localtmp/.gdignore").touch()
    with _build_lock(output):
        build_id = uuid.uuid4().hex
        directory = output / "builds" / build_id
        directory.mkdir(parents=True)
        status = {"state": "building", "build_id": build_id, "started_at": _now()}
        _atomic_json(output / "status.json", status)
        try:
            executable = shutil.which(godot)
            if executable is None:
                raise BuildError(f"Godot executable not found: {godot}.")
            version = subprocess.run([executable, "--version"], capture_output=True, text=True,
                                     check=False, timeout=15)
            version_text = version.stdout.strip()
            if version.returncode or not re.fullmatch(r"4\.7\.2\.stable(?:\.[^\s]+)?", version_text):
                raise BuildError(f"LAN builds require Godot 4.7.2 stable; found {version_text!r}.")
            _configuration(root)
            identity = _source_identity(root)
            _logged(["make", f"GODOT={executable}", "check"], root, directory / "check.log", 600)
            if _source_identity(root) != identity:
                raise BuildError("Source changed while checks ran; rerun the LAN build.")
            project = directory / "project"
            project.mkdir()
            for name in ("scripts", "scenes", "resources", "assets"):
                shutil.copytree(root / name, project / name, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
            for name in ("project.godot", "export_presets.cfg", "icon.svg", "icon.svg.import"):
                if (root / name).is_file():
                    shutil.copy2(root / name, project / name)
            if _source_identity(root) != identity:
                raise BuildError("Source changed while the production snapshot was copied; rebuild.")
            snapshot_hash = hashlib.sha256()
            for path in sorted(project.rglob("*")):
                if path.is_file():
                    snapshot_hash.update(path.relative_to(project).as_posix().encode() + b"\0")
                    snapshot_hash.update(path.read_bytes())
            export = directory / "export"
            export.mkdir()
            _logged([executable, "--headless", "--path", str(project), "--import"], root,
                    directory / "import.log", 180)
            _logged([executable, "--headless", "--path", str(project), "--export-release", "Web",
                     str(export / "index.html")], root, directory / "export.log", 180)
            browser_title = _stamp_browser_title(export, build_id)
            metadata = {"build_id": build_id, **identity, "godot_version": version_text,
                        "source_snapshot_sha256": snapshot_hash.hexdigest(),
                        "built_at": _now(), "browser_title": browser_title,
                        "files": _payloads(export)}
            _atomic_json(export / "build-info.json", metadata)
            _atomic_json(directory / "record.json", metadata)
            verify_build(output, build_id, root)
            _atomic_json(output / "status.json", {**status, "state": "ready", "completed_at": _now()})
            return metadata
        except (BuildError, OSError, ValueError, configparser.Error, subprocess.TimeoutExpired) as error:
            _atomic_json(output / "status.json", {**status, "state": "failed", "error": str(error),
                                                 "completed_at": _now()})
            raise BuildError(str(error)) from error
