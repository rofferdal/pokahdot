#!/usr/bin/env python3
"""Check repository documentation links without requiring network access."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]


def anchors(path: Path) -> set[str]:
    """Match GitHub heading slugs, including duplicate heading suffixes."""
    found: set[str] = set()
    counts: dict[str, int] = {}
    for heading in re.findall(r'^#{1,6}\s+(.+?)\s*#*$', path.read_text(), re.M):
        slug = re.sub(r'[^\w\- ]', '', heading.lower()).replace(' ', '-')
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        found.add(f'{slug}-{count}' if count else slug)
    return found


def main() -> int:
    paths = [ROOT / 'README.md', *sorted((ROOT / 'docs').rglob('*.md')),
             *sorted((ROOT / 'devdocs').rglob('*.md'))]
    errors: list[str] = []
    local_evidence: set[str] = set()
    for path in paths:
        content = re.sub(r'^```.*?^```\s*$', '', path.read_text(), flags=re.M | re.S)
        links = re.findall(r'\[[^\]]*\]\(([^)]+)\)', content)
        links += re.findall(r'^\[[^\]]+\]:\s+(\S+)', content, re.M)
        for raw in links:
            url = unquote(raw.strip().strip('<>'))
            if re.match(r'^[a-zA-Z][\w+.-]*:|^//', url):
                continue
            target, _, fragment = url.partition('#')
            resolved = (path.parent / target).resolve() if target else path
            label = f'{path.relative_to(ROOT)}: {raw}'
            if ROOT / 'localtmp' in resolved.parents:
                if not resolved.exists():
                    local_evidence.add(label)
                continue
            if not resolved.exists():
                errors.append(f'Missing target: {label}')
            elif fragment and resolved.suffix == '.md' and fragment not in anchors(resolved):
                errors.append(f'Missing anchor: {label}')
        if content.count('```') % 2:
            errors.append(f'Unclosed code fence: {path.relative_to(ROOT)}')
    for error in errors:
        print(error, file=sys.stderr)
    for evidence in sorted(local_evidence):
        print(f'Unavailable local-only evidence (not a portable link): {evidence}')
    print(f'Checked {len(paths)} Markdown files; {len(errors)} errors; '
          f'{len(local_evidence)} unavailable local evidence links.')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
