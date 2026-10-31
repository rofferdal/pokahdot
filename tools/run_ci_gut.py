#!/usr/bin/env python3
"""Run CI quality tests without optional matrix runners or the separate phone job."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PHONE_SUITE = "res://tests/unit/test_gui_phone_table_layout.gd"


def quality_config(root: Path, config: dict) -> dict:
    """Discover the configured suite anew; fail if the required partition is absent."""
    tests = set(config.get("tests", []))
    pattern = config.get("prefix", "test_") + "*" + config.get("suffix", ".gd")
    for directory in config["dirs"]:
        if not directory.startswith("res://"):
            raise ValueError(f"Unsupported GUT test directory: {directory}")
        folder = root / directory.removeprefix("res://")
        if not folder.is_dir():
            raise ValueError(f"Missing GUT test directory: {directory}")
        paths = folder.rglob(pattern) if config.get("include_subdirs", False) else folder.glob(pattern)
        tests.update("res://" + path.relative_to(root).as_posix() for path in paths if path.is_file())
    if PHONE_SUITE not in tests:
        raise ValueError("The separately required phone suite was not discovered")
    selected = sorted(path for path in tests
                      if path != PHONE_SUITE and not path.endswith("_matrix_runner.gd"))
    if not selected:
        raise ValueError("The CI quality suite must not be empty")
    return dict(config, dirs=[], configured_dirs=[], tests=selected)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    try:
        config = quality_config(ROOT, json.loads((ROOT / ".gutconfig.json").read_text()))
        output = ROOT / "localtmp/ci-layout/quality.gutconfig.json"
        output.parent.mkdir(parents=True, exist_ok=True)
        config["junit_xml_file"] = "res://localtmp/ci-layout/quality.xml"
        config["junit_xml_timestamp"] = False
        output.write_text(json.dumps(config, indent=2) + "\n")
    except (OSError, ValueError, KeyError) as error:
        print(f"Cannot partition CI GUT suite: {error}", file=sys.stderr)
        return 1
    print(f"CI quality: {len(config['tests'])} scripts; phone suite is separate; matrix runners excluded.", flush=True)
    try:
        return subprocess.run(
            [args.godot, "--headless", "--path", str(ROOT), "-s", "addons/gut/gut_cmdln.gd",
             "-gconfig=res://localtmp/ci-layout/quality.gutconfig.json"], cwd=ROOT,
        ).returncode
    except OSError as error:
        print(f"Cannot start Godot: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
