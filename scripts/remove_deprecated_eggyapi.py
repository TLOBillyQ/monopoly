import argparse
from pathlib import Path


def remove_deprecated_api(lines):
    out = []
    buffer = []
    deprecated_in_buffer = False

    for line in lines:
        stripped = line.lstrip()
        is_doc = stripped.startswith("---")
        if is_doc:
            buffer.append(line)
            if "@deprecated" in line:
                deprecated_in_buffer = True
            continue

        if deprecated_in_buffer:
            if line.strip() == "":
                continue
            buffer.clear()
            deprecated_in_buffer = False
            continue

        if buffer:
            out.extend(buffer)
            buffer.clear()
            deprecated_in_buffer = False

        out.append(line)

    if not deprecated_in_buffer and buffer:
        out.extend(buffer)

    return out


def main():
    parser = argparse.ArgumentParser(
        description="删除 EggyAPI.lua 中标记为 @deprecated 的 API（含注释块）。"
    )
    parser.add_argument(
        "path",
        nargs="?",
        default="docs/eggy/EggyAPI.lua",
        help="目标文件路径，默认 docs/eggy/EggyAPI.lua",
    )
    parser.add_argument(
        "--backup-suffix",
        default=".bak",
        help="备份后缀，默认 .bak；传入空字符串表示不备份",
    )
    args = parser.parse_args()

    target = Path(args.path)
    original = target.read_text(encoding="utf-8")
    updated = "".join(remove_deprecated_api(original.splitlines(keepends=True)))

    if args.backup_suffix:
        backup = target.with_suffix(target.suffix + args.backup_suffix)
        backup.write_text(original, encoding="utf-8")

    target.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    main()
