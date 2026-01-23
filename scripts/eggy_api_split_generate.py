#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 EggyAPI 拆分文档。"""
from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "docs" / "eggy" / "EggyAPI.lua"
DOC_DIR = ROOT / "docs" / "eggy" / "api"

FUNC_RE = re.compile(r"^function\s+([^\(]+)\(([^)]*)\)\s*end\s*$", re.M)
CLASS_RE = re.compile(r"^---@class\s+([^\n]+)$", re.M)
ALIAS_RE = re.compile(r"^---@alias\s+(.+)$", re.M)
ENUM_RE = re.compile(r"^---@enum\s+(.+)$", re.M)


def normalize_params(params: str) -> str:
    params = params.strip()
    if not params:
        return ""
    return ", ".join([p.strip() for p in params.split(",")])


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


def main() -> int:
    text = SRC.read_text(encoding="utf-8")
    DOC_DIR.mkdir(parents=True, exist_ok=True)

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

    # 00_index
    index = [
        "# EggyAPI 拆分索引",
        "",
        "本目录用于按功能拆分 `docs/eggy/EggyAPI.lua`，加速查询并保证 API 完整性。",
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
        "校验方式：运行 `python scripts/eggy_api_split_check.py`，确保接口数量一致。",
        "",
    ]
    (DOC_DIR / "00_index.md").write_text("\n".join(index), encoding="utf-8")

    # 01_types
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
    (DOC_DIR / "01_types.md").write_text("\n".join(types_lines), encoding="utf-8")

    # 02_aliases
    alias_lines = [m.group(1).strip() for m in ALIAS_RE.finditer(text) if m.group(1).strip()]
    (DOC_DIR / "02_aliases.md").write_text(
        "\n".join(["# 类型别名", ""] + alias_lines + [""]), encoding="utf-8"
    )

    # 03_enums
    enum_lines = [m.group(1).strip() for m in ENUM_RE.finditer(text) if m.group(1).strip()]
    (DOC_DIR / "03_enums.md").write_text(
        "\n".join(["# 枚举清单", ""] + enum_lines + [""]), encoding="utf-8"
    )

    # 04-06 APIs
    write_module_file(DOC_DIR / "04_global_api.md", ["GlobalAPI"], by_module)
    write_module_file(DOC_DIR / "05_game_api.md", ["GameAPI"], by_module)
    write_module_file(DOC_DIR / "06_lua_api.md", ["LuaAPI"], by_module)

    # 07/08
    write_module_file(DOC_DIR / "07_unit_entities.md", entity_modules, by_module)
    write_module_file(DOC_DIR / "08_components.md", component_modules, by_module)

    # 09_events
    idx = text.find("---@class EVENT")
    if idx != -1:
        events_section = text[idx:].strip()
        (DOC_DIR / "09_events.md").write_text(
            "\n".join(["# 事件常量", "", events_section, ""]), encoding="utf-8"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
