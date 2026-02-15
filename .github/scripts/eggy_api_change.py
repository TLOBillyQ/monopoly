#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 EggyAPI 拆分文档并输出差异/校验。"""
from __future__ import annotations

import argparse
import re
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_NEW = ROOT / ".agents" / "docs" / "eggy" / "EggyAPI.lua"
DEFAULT_OLD = ROOT / ".agents" / "docs" / "eggy" / "EggyAPI_old.lua"
DEFAULT_DOC_DIR = ROOT / ".agents" / "docs" / "eggy" / "api"
DEFAULT_CHANGELOG = ROOT / ".agents" / "docs" / "eggy" / "api_changelog.md"

FUNC_RE = re.compile(r"^function\s+([^\(]+)\(([^)]*)\)\s*end\s*$", re.M)
CLASS_RE = re.compile(r"^---@class\s+([^\n]+)$", re.M)
ALIAS_RE = re.compile(r"^---@alias\s+(.+)$", re.M)
ENUM_RE = re.compile(r"^---@enum\s+(.+)$", re.M)

DIFF_FUNC_RE = re.compile(r"^function\s+([A-Za-z_][\w\.:]*)\s*\(([^)]*)\)")
DIFF_ASSIGN_FUNC_RE = re.compile(
    r"^([A-Za-z_][\w\.]*)\s*=\s*function\s*\(([^)]*)\)"
)
DIFF_ASSIGN_RE = re.compile(r"^([A-Za-z_][\w\.]*)\s*=")


@dataclass(frozen=True)
class ApiSymbol:
    kind: str
    params: str
    line: int


def normalize_params(params: str, drop_empty: bool = False) -> str:
    params = params.strip()
    if not params:
        return ""
    parts = [p.strip() for p in params.split(",")]
    if drop_empty:
        parts = [p for p in parts if p]
    return ", ".join(parts)


def class_base_name(raw: str) -> str:
    raw = raw.strip().replace("(partial) ", "")
    return raw.split(":", 1)[0].strip()


def extract_class_block(text: str, class_name: str) -> str:
    pattern = re.compile(r"^---@class\s+" + re.escape(class_name) + r"\b.*$", re.M)
    match = pattern.search(text)
    if not match:
        return ""
    start = match.start()
    next_re = re.compile(r"^(---@class\s+|---@alias\s+|---@enum\s+|function\s+)", re.M)
    next_match = next_re.search(text, match.end())
    end = next_match.start() if next_match else len(text)
    return text[start:end].strip()


def load_functions(text: str) -> list[tuple[str, str, str]]:
    entries: list[tuple[str, str, str]] = []
    for match in FUNC_RE.finditer(text):
        name = match.group(1).strip()
        params = normalize_params(match.group(2))
        if ":" in name:
            module, func = name.split(":", 1)
        elif "." in name:
            module, func = name.split(".", 1)
        else:
            module, func = name, ""
        entries.append((module, func, params))
    return entries


def write_module_file(path: Path, modules: list[str], by_module: dict[str, list[str]]) -> None:
    lines: list[str] = []
    for mod in modules:
        lines.append(f"## {mod}")
        lines.append("")
        lines.extend(by_module.get(mod, []))
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def format_relpath(path: Path) -> str:
    try:
        rel = path.relative_to(ROOT)
    except ValueError:
        rel = path
    return str(rel).replace("\\", "/")


def append_changelog(
    path: Path, report_lines: list[str], old_path: Path, new_path: Path
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    entry_lines = [
        f"## {date.today().isoformat()}",
        "",
        *report_lines,
        "",
    ]
    entry_text = "\n".join(entry_lines)
    if path.exists():
        content = path.read_text(encoding="utf-8").strip()
        if content:
            content = f"{content}\n\n{entry_text}\n"
        else:
            content = "\n".join(["# EggyAPI 变更记录", "", entry_text]) + "\n"
    else:
        content = "\n".join(["# EggyAPI 变更记录", "", entry_text]) + "\n"
    path.write_text(content, encoding="utf-8")


def iter_code_lines(text: str):
    in_block_comment = False
    for idx, raw in enumerate(text.splitlines(), 1):
        line = raw
        if in_block_comment:
            end_idx = line.find("]]")
            if end_idx == -1:
                continue
            line = line[end_idx + 2 :]
            in_block_comment = False
            if not line.strip():
                continue

        stripped = line.lstrip()
        if stripped.startswith("--[["):
            in_block_comment = True
            continue
        if stripped.startswith("--"):
            continue

        comment_idx = line.find("--")
        if comment_idx != -1:
            line = line[:comment_idx]

        line = line.strip()
        if line:
            yield idx, line


def parse_symbols(text: str) -> dict[str, ApiSymbol]:
    symbols: dict[str, ApiSymbol] = {}
    for line_no, line in iter_code_lines(text):
        if line.startswith("local "):
            continue

        func_match = DIFF_FUNC_RE.match(line)
        if func_match:
            name = func_match.group(1).strip()
            params = normalize_params(func_match.group(2), drop_empty=True)
            symbols[name] = ApiSymbol("function", params, line_no)
            continue

        assign_func_match = DIFF_ASSIGN_FUNC_RE.match(line)
        if assign_func_match:
            name = assign_func_match.group(1).strip()
            params = normalize_params(assign_func_match.group(2), drop_empty=True)
            symbols[name] = ApiSymbol("function", params, line_no)
            continue

        assign_match = DIFF_ASSIGN_RE.match(line)
        if assign_match:
            name = assign_match.group(1).strip()
            symbols[name] = ApiSymbol("field", "", line_no)

    return symbols


def parse_path(path: Path) -> dict[str, ApiSymbol]:
    return parse_symbols(path.read_text(encoding="utf-8"))


def format_list(title: str, items: list[str], limit: int | None) -> list[str]:
    lines = [f"{title}: {len(items)}"]
    if not items:
        return lines
    if limit is None or limit <= 0:
        limit = len(items)
    for name in items[:limit]:
        lines.append(f"  - {name}")
    return lines


def format_changes(
    title: str, items: list[tuple[str, str, str]], limit: int | None
) -> list[str]:
    lines = [f"{title}: {len(items)}"]
    if not items:
        return lines
    if limit is None or limit <= 0:
        limit = len(items)
    for name, old_value, new_value in items[:limit]:
        lines.append(f"  - {name}: {old_value} -> {new_value}")
    return lines


def diff_symbols(
    old_symbols: dict[str, ApiSymbol], new_symbols: dict[str, ApiSymbol]
) -> tuple[list[str], list[str], list[tuple[str, str, str]], list[tuple[str, str, str]]]:
    old_keys = set(old_symbols)
    new_keys = set(new_symbols)

    added = sorted(new_keys - old_keys)
    removed = sorted(old_keys - new_keys)

    changed_params: list[tuple[str, str, str]] = []
    type_changed: list[tuple[str, str, str]] = []
    for name in sorted(new_keys & old_keys):
        old = old_symbols[name]
        new = new_symbols[name]
        if old.kind != new.kind:
            type_changed.append((name, old.kind, new.kind))
            continue
        if old.kind == "function" and old.params != new.params:
            changed_params.append((name, old.params, new.params))

    return added, removed, changed_params, type_changed


def load_symbols(
    old_path: Path, new_path: Path
) -> tuple[dict[str, ApiSymbol], dict[str, ApiSymbol]]:
    with ThreadPoolExecutor(max_workers=2) as executor:
        old_future = executor.submit(parse_path, old_path)
        new_future = executor.submit(parse_path, new_path)
        return old_future.result(), new_future.result()


def format_diff_report(
    added: list[str],
    removed: list[str],
    changed_params: list[tuple[str, str, str]],
    type_changed: list[tuple[str, str, str]],
    limit: int | None,
) -> list[str]:
    lines: list[str] = []
    lines.extend(format_list("Added", added, limit))
    lines.extend(format_list("Removed", removed, limit))
    lines.extend(format_changes("Signature changed", changed_params, limit))
    lines.extend(format_changes("Type changed", type_changed, limit))
    return lines


def load_source_entries(text: str) -> set[str]:
    entries = []
    for module, func, params in load_functions(text):
        entries.append(f"{module}|{func}|{params}".rstrip("|"))
    return set(entries)


def load_doc_entries(doc_dir: Path) -> set[str]:
    entries = []
    for path in doc_dir.glob("*.md"):
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if "|" not in line:
                continue
            if line.startswith("#"):
                continue
            entries.append(line)
    return set(entries)


def build_check_report(
    source_entries: set[str], doc_entries: set[str]
) -> tuple[list[str], list[str], list[str]]:
    missing = sorted(source_entries - doc_entries)
    extra = sorted(doc_entries - source_entries)
    lines = [
        f"Source count: {len(source_entries)}",
        f"Split docs count: {len(doc_entries)}",
        f"Missing: {len(missing)}",
        f"Extra: {len(extra)}",
    ]
    if missing:
        lines.append(f"Missing sample: {missing[:10]}")
    if extra:
        lines.append(f"Extra sample: {extra[:10]}")
    return lines, missing, extra


def main() -> int:
    parser = argparse.ArgumentParser(
        description="生成 EggyAPI 拆分文档，并输出差异/校验结果。"
    )
    parser.add_argument("--old", type=Path, default=DEFAULT_OLD, help="旧版 API 文件")
    parser.add_argument("--new", type=Path, default=DEFAULT_NEW, help="新版 API 文件")
    parser.add_argument("--doc-dir", type=Path, default=DEFAULT_DOC_DIR, help="拆分文档目录")
    parser.add_argument(
        "--changelog",
        type=Path,
        default=DEFAULT_CHANGELOG,
        help="差异记录输出文件",
    )
    parser.add_argument(
        "--limit", type=int, default=50, help="差异输出每类最多显示条数"
    )
    parser.add_argument(
        "--skip-generate", action="store_true", help="跳过拆分文档生成"
    )
    parser.add_argument("--skip-check", action="store_true", help="跳过拆分校验")
    parser.add_argument("--skip-diff", action="store_true", help="跳过差异输出与记录")
    args = parser.parse_args()

    text = ""
    if not args.skip_generate or not args.skip_check:
        text = args.new.read_text(encoding="utf-8")

    if not args.skip_generate:
        args.doc_dir.mkdir(parents=True, exist_ok=True)

        entries = load_functions(text)
        modules = sorted({m for m, _, _ in entries})

        basic_types = {"Vector3", "Quaternion", "dict", "math"}
        api_modules = {"GlobalAPI", "GameAPI", "LuaAPI"}
        component_modules = sorted({m for m in modules if m.endswith("Comp")})

        class_names = [class_base_name(c) for c in CLASS_RE.findall(text)]
        class_set = set(class_names)
        entity_modules = sorted(
            {
                m
                for m in modules
                if m in class_set
                and m not in basic_types
                and m not in api_modules
                and m not in component_modules
                and m not in {"EVENT", "Enums", "Damage", "Timer", "GoodsInfo"}
            }
        )

        by_module: dict[str, list[str]] = {}
        for module, func, params in entries:
            line = f"{module}|{func}|{params}".rstrip("|")
            by_module.setdefault(module, []).append(line)

        index = [
            "# EggyAPI 拆分索引",
            "",
            "本目录用于按功能拆分 `.agents/docs/eggy/EggyAPI.lua`，加速查询并保证 API 完整性。",
            "",
            "## 目录",
            "",
            "- 01_types.md：基础类型与方法清单（Vector3/Quaternion/dict/math）。",
            "- 02_aliases.md：类型别名清单（`---@alias`）。",
            "- 03_enums.md：枚举清单（`---@enum`）。",
            "- 04_global_api.md：GlobalAPI 方法索引。",
            "- 05_game_api.md：GameAPI 方法索引。",
            "- 06_lua_api.md：LuaAPI 方法索引。",
            "- 07_unit_entities.md：实体类方法索引（Unit/Role/Ability 等）。",
            "- 08_components.md：组件类方法索引（*Comp）。",
            "- 09_events.md：事件常量与示例。",
            "",
            "校验方式：运行 `python .agents/scripts/eggy_api_split_generate.py`，默认包含校验。",
            "",
        ]
        (args.doc_dir / "00_index.md").write_text("\n".join(index), encoding="utf-8")

        basic_class_markers = ["Vector3", "Quaternion", "dict", "(partial) math"]
        types_lines = ["# 基础类型", ""]
        for marker in basic_class_markers:
            block = extract_class_block(text, marker)
            if block:
                types_lines.append(block)
                types_lines.append("")
        types_lines.append("## 方法清单")
        types_lines.append("")
        for module, func, params in entries:
            if module in basic_types:
                types_lines.append(f"{module}|{func}|{params}".rstrip("|"))
        types_lines.append("")
        types_lines.append("## 其他类型")
        types_lines.append("")
        for raw in CLASS_RE.findall(text):
            raw = raw.strip()
            if raw.startswith("EVENT"):
                continue
            base = class_base_name(raw)
            if base in basic_types:
                continue
            types_lines.append(f"- {raw}")
        types_lines.append("")
        (args.doc_dir / "01_types.md").write_text("\n".join(types_lines), encoding="utf-8")

        alias_lines = [m.group(1).strip() for m in ALIAS_RE.finditer(text) if m.group(1).strip()]
        (args.doc_dir / "02_aliases.md").write_text(
            "\n".join(["# 类型别名", ""] + alias_lines + [""]), encoding="utf-8"
        )

        enum_lines = [m.group(1).strip() for m in ENUM_RE.finditer(text) if m.group(1).strip()]
        (args.doc_dir / "03_enums.md").write_text(
            "\n".join(["# 枚举清单", ""] + enum_lines + [""]), encoding="utf-8"
        )

        write_module_file(args.doc_dir / "04_global_api.md", ["GlobalAPI"], by_module)
        write_module_file(args.doc_dir / "05_game_api.md", ["GameAPI"], by_module)
        write_module_file(args.doc_dir / "06_lua_api.md", ["LuaAPI"], by_module)
        write_module_file(args.doc_dir / "07_unit_entities.md", entity_modules, by_module)
        write_module_file(args.doc_dir / "08_components.md", component_modules, by_module)

        idx = text.find("---@class EVENT")
        if idx != -1:
            events_section = text[idx:].strip()
            (args.doc_dir / "09_events.md").write_text(
                "\n".join(["# 事件常量", "", events_section, ""]), encoding="utf-8"
            )

    diff_failed = False
    if not args.skip_diff:
        old_symbols, new_symbols = load_symbols(args.old, args.new)
        added, removed, changed_params, type_changed = diff_symbols(
            old_symbols, new_symbols
        )
        diff_lines = format_diff_report(
            added, removed, changed_params, type_changed, args.limit
        )
        print("\n".join(diff_lines))

        full_diff_lines = format_diff_report(
            added, removed, changed_params, type_changed, None
        )
        append_changelog(args.changelog, full_diff_lines, args.old, args.new)
        diff_failed = bool(added or removed or changed_params or type_changed)

    check_failed = False
    if not args.skip_check:
        source_entries = load_source_entries(text)
        doc_entries = load_doc_entries(args.doc_dir)
        check_lines, missing, extra = build_check_report(source_entries, doc_entries)
        if not args.skip_diff:
            print("")
        print("\n".join(check_lines))
        check_failed = bool(missing or extra)

    return 1 if diff_failed or check_failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
