#!/usr/bin/env python3
"""从蛋仔编辑器的工程存档导出完整成就表 -> src/config/content/achievements.lua。

Export the FULL achievement table from the Eggy editor's project save into
src/config/content/achievements.lua. No runtime / play-mode required.

为什么读存档而不是 GameAPI / Why the save, not the API:
    宿主 API 只有 GameAPI.get_achievement_target(id)，仅返回目标阈值，且只在
    试玩态可用 (编辑态 GameAPI 为 nil)。成就的名称 / 描述 / 达成条件 / 类型在
    任何 API 中都不可读。但编辑器把整张成就表存进工程存档 archives.mm
    (zstd 压缩的 MessagePack)，字段齐全，且无需进入试玩态即可读取。

字段映射 / Field map (archives.mm -> achievements.lua):
    dict key       -> id            成就编号
    rarity         -> category      成就类型 (None/0=简单 1=普通 2=困难 3=传奇 4=隐藏)
    achievement_name-> name          成就名称
    desc           -> description   成就描述
    detail_desc    -> condition     达成条件
    achieve_count  -> target_progress 达成参数

依赖 / Deps: pip install zstandard msgpack

用法 / Usage:
    python tools/ops/export_achievements.py [--map 大富翁] [--archives <path>] [--out <path>]
    默认自动选取 ~/Documents/Eggitor/{backup,autosave}/<map>/*/archives.mm 中最新的一份。
"""
import argparse
import glob
import os
import sys

RARITY_TO_CATEGORY = {None: "简单", 0: "简单", 1: "普通", 2: "困难", 3: "传奇", 4: "隐藏"}
DEFAULT_OUT = "src/config/content/achievements.lua"
DEFAULT_MAP = "大富翁"


def _newest_archives(map_name):
    home = os.path.expanduser("~")
    roots = [
        os.path.join(home, "Documents", "Eggitor", "backup", map_name),
        os.path.join(home, "Documents", "Eggitor", "autosave", map_name),
    ]
    candidates = []
    for root in roots:
        candidates += glob.glob(os.path.join(root, "*", "archives.mm"))
    if not candidates:
        return None
    return max(candidates, key=os.path.getmtime)


def _load_achievement_data(archives_path):
    import zstandard
    import msgpack

    raw = open(archives_path, "rb").read()
    blob = zstandard.ZstdDecompressor().decompress(raw, max_output_size=64 * 1024 * 1024)
    obj = msgpack.unpackb(blob, raw=True, strict_map_key=False)

    def dec(x):
        if isinstance(x, bytes):
            try:
                return x.decode("utf-8")
            except UnicodeDecodeError:
                return x
        if isinstance(x, dict):
            return {dec(k): dec(v) for k, v in x.items()}
        if isinstance(x, list):
            return [dec(v) for v in x]
        return x

    return dec(obj)["achievement_data"]


def _entries_from(achievement_data):
    entries = []
    for key, value in achievement_data.items():
        category = "隐藏" if value.get("is_hide") else RARITY_TO_CATEGORY.get(value.get("rarity"), "简单")
        entries.append({
            "id": int(key),
            "category": category,
            "name": str(value.get("achievement_name", "")).strip(),
            "description": str(value.get("desc", "")).strip(),
            "condition": str(value.get("detail_desc", "")).strip(),
            "target_progress": value.get("achieve_count"),
        })
    entries.sort(key=lambda e: e["id"])
    return entries


def _lua_quote(text):
    s = str(text)
    if '"' in s or "\\" in s or "\n" in s:
        raise ValueError("unexpected quote/backslash/newline in field: %r" % s)
    return '"' + s + '"'


def render(entries):
    lines = [
        "-- Achievement catalog exported from the Eggy editor project save",
        "-- (archives.mm, zstd+MessagePack) by tools/ops/export_achievements.py.",
        "-- No runtime needed; regenerate after editing achievements in the editor.",
        "-- Progress tracking / unlock delivery stay host-owned",
        "-- (see src/app/host_integrations/achievement.lua).",
        "return {",
    ]
    for e in entries:
        fields = [
            "id = %d" % e["id"],
            "category = %s" % _lua_quote(e["category"]),
            "name = %s" % _lua_quote(e["name"]),
            "description = %s" % _lua_quote(e["description"]),
            "condition = %s" % _lua_quote(e["condition"]),
        ]
        if e["target_progress"] is not None:
            fields.append("target_progress = %d" % int(e["target_progress"]))
        lines.append("  { " + ", ".join(fields) + " },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Export the editor achievement table to Lua.")
    parser.add_argument("--map", default=DEFAULT_MAP, help="editor map name (default: %s)" % DEFAULT_MAP)
    parser.add_argument("--archives", help="explicit path to archives.mm (overrides --map auto-pick)")
    parser.add_argument("--out", default=DEFAULT_OUT, help="output Lua path (default: %s)" % DEFAULT_OUT)
    args = parser.parse_args(argv)

    archives_path = args.archives or _newest_archives(args.map)
    if not archives_path or not os.path.exists(archives_path):
        sys.stderr.write("archives.mm not found (启动编辑器并保存，或用 --archives 指定路径)\n")
        return 1

    entries = _entries_from(_load_achievement_data(archives_path))
    if not entries:
        sys.stderr.write("no achievement_data in %s\n" % archives_path)
        return 1

    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(render(entries))
    sys.stdout.write("成就表已导出 / exported %d entries -> %s\n  (源 / from: %s)\n"
                     % (len(entries), args.out, archives_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
