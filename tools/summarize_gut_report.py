#!/usr/bin/env python3
"""Validate GUT execution coverage and summarize its slowest scripts and tests."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def summarize(report: Path, config: dict | None = None) -> str:
    root = ET.parse(report).getroot()
    suites = list(root.iter("testsuite"))
    tests = list(root.iter("testcase"))
    if not tests:
        raise ValueError("GUT report contains no executed tests")
    if any(int(node.get("failures", "0")) or int(node.get("errors", "0"))
           for node in [root, *suites]):
        raise ValueError("GUT report contains failed tests")
    if config is not None:
        expected = {path.removeprefix("res://") for path in config["tests"]}
        observed = {suite.get("name", "").split("[", 1)[0] for suite in suites}
        if expected != observed:
            raise ValueError(f"GUT script coverage differs: missing={sorted(expected - observed)}, "
                             f"unexpected={sorted(observed - expected)}")
    lines = [f"### GUT timings ({len(tests)} tests)", "", "Slowest scripts:", ""]
    for suite in sorted(suites, key=lambda item: float(item.get("time", "0")), reverse=True)[:10]:
        lines.append(f"- {float(suite.get('time', '0')):.3f} s — `{suite.get('name')}`")
    lines.extend(["", "Slowest tests:", ""])
    for test in sorted(tests, key=lambda item: float(item.get("time", "0")), reverse=True)[:10]:
        lines.append(f"- {float(test.get('time', '0')):.3f} s — "
                     f"`{test.get('classname')}::{test.get('name')}`")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--config", type=Path)
    args = parser.parse_args()
    try:
        config = json.loads(args.config.read_text()) if args.config else None
        result = summarize(args.report, config)
        print(result, flush=True)
        summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary_path:
            with Path(summary_path).open("a") as output:
                output.write(result)
    except (OSError, ET.ParseError, ValueError, KeyError) as error:
        print(f"Invalid GUT execution report: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
