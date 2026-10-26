"""Regression coverage for the offline documentation link gate."""
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
    def check_document(self, content: str) -> tuple[int, str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / 'README.md').write_text(content)
            (root / 'docs').mkdir()
            (root / 'devdocs').mkdir()
            (root / 'docs/target.md').write_text('# Target\n\n## Same\n\n## Same\n')
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


if __name__ == '__main__':
    unittest.main()
