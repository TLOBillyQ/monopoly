#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""校验 EggyAPI 拆分文档的 API 完整性。"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'docs' / 'eggy' / 'EggyAPI.lua'
DOC_DIR = ROOT / 'docs' / 'eggy' / 'api'

FUNC_RE = re.compile(r'^function\s+([^\(]+)\(([^)]*)\)\s*end\s*$', re.M)


def normalize_params(params: str) -> str:
    params = params.strip()
    if not params:
        return ''
    return ', '.join([p.strip() for p in params.split(',')])


def load_source_entries(text: str) -> set[str]:
    entries = []
    for m in FUNC_RE.finditer(text):
        name = m.group(1).strip()
        params = normalize_params(m.group(2))
        if ':' in name:
            module, func = name.split(':', 1)
        elif '.' in name:
            module, func = name.split('.', 1)
        else:
            module, func = name, ''
        entries.append(f"{module}|{func}|{params}".rstrip('|'))
    return set(entries)


def load_doc_entries(doc_dir: Path) -> set[str]:
    entries = []
    for path in doc_dir.glob('*.md'):
        for line in path.read_text(encoding='utf-8').splitlines():
            line = line.strip()
            if '|' not in line:
                continue
            if line.startswith('#'):
                continue
            entries.append(line)
    return set(entries)


def main() -> int:
    src_text = SRC.read_text(encoding='utf-8')
    source_entries = load_source_entries(src_text)
    doc_entries = load_doc_entries(DOC_DIR)

    missing = sorted(source_entries - doc_entries)
    extra = sorted(doc_entries - source_entries)

    print(f"Source count: {len(source_entries)}")
    print(f"Split docs count: {len(doc_entries)}")
    print(f"Missing: {len(missing)}")
    print(f"Extra: {len(extra)}")

    if missing:
        print("Missing sample:", missing[:10])
    if extra:
        print("Extra sample:", extra[:10])

    return 0 if not missing and not extra else 1


if __name__ == '__main__':
    raise SystemExit(main())
