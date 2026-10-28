"""Regression coverage for the offline documentation link gate."""
from __future__ import annotations

import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'check_docs', Path(__file__).resolve().parents[2] / 'tools/check_docs.py'
)
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class DocumentationLinksTests(unittest.TestCase):
    def check_document(self, content: str,
                       extra_files: dict[str, str] | None = None) -> tuple[int, str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / 'README.md').write_text(content)
            (root / 'docs').mkdir()
            (root / 'devdocs').mkdir()
            (root / 'docs/target.md').write_text('# Target\n\n## Same\n\n## Same\n')
            for name, text in (extra_files or {}).items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
            original = CHECK.ROOT
            CHECK.ROOT = root
            output = io.StringIO()
            try:
                with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                    status = CHECK.main()
            finally:
                CHECK.ROOT = original
            return status, output.getvalue()

    def test_valid_anchors_external_links_and_fenced_examples(self):
        status, _ = self.check_document(
            '[ok](docs/target.md#same-1) [web](https://example.invalid)\n'
            '```text\n[example](missing.md)\n```\n'
        )
        self.assertEqual(status, 0)

    def test_missing_target_and_anchor_fail(self):
        status, output = self.check_document(
            '[bad](missing.md) [anchor](docs/target.md#missing)\n'
        )
        self.assertEqual(status, 1)
        self.assertIn('Missing target', output)
        self.assertIn('Missing anchor', output)

    def test_unavailable_ignored_evidence_is_reported_separately(self):
        status, output = self.check_document('[evidence](localtmp/old.png)\n')
        self.assertEqual(status, 0)
        self.assertIn('Unavailable local-only evidence', output)

    def test_unclosed_fence_fails(self):
        status, output = self.check_document('```text\nunclosed\n')
        self.assertEqual(status, 1)
        self.assertIn('Unclosed code fence', output)

    def test_historical_archive_contents_are_excluded_recursively(self):
        status, output = self.check_document(
            '[history](docs/arkiv/old.md#history)\n',
            {
                'docs/arkiv/old.md': '# History\n[old](missing.md)\n',
                'docs/arkiv/nested/older.md': '[old](missing.md)\n```text\nunclosed\n',
            },
        )
        self.assertEqual(status, 0)
        self.assertIn('Checked 2 Markdown files; 0 errors', output)

    def test_current_links_to_archive_still_require_valid_targets_and_anchors(self):
        status, output = self.check_document(
            '[missing](docs/arkiv/missing.md) [anchor](docs/arkiv/old.md#missing)\n',
            {'docs/arkiv/old.md': '# History\n'},
        )
        self.assertEqual(status, 1)
        self.assertIn('Missing target', output)
        self.assertIn('Missing anchor', output)


if __name__ == '__main__':
    unittest.main()
