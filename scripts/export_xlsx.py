#!/usr/bin/env python3
import os
import sys
import zipfile
import xml.etree.ElementTree as ET
import argparse

NS_MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
NS_REL_DOC = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS_REL_PKG = "http://schemas.openxmlformats.org/package/2006/relationships"

NS = {
    "main": NS_MAIN,
    "rel_doc": NS_REL_DOC,
    "rel_pkg": NS_REL_PKG,
}


def load_shared_strings(zf):
    try:
        data = zf.read("xl/sharedStrings.xml")
    except KeyError:
        return []
    root = ET.fromstring(data)
    out = []
    for si in root.findall("main:si", NS):
        parts = []
        for t in si.findall(".//main:t", NS):
            parts.append(t.text or "")
        out.append("".join(parts))
    return out


def sheet_map(zf):
    wb = ET.fromstring(zf.read("xl/workbook.xml"))
    rels = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
    rid_to_target = {}
    for rel in rels.findall("rel_pkg:Relationship", NS):
        rid_to_target[rel.attrib["Id"]] = rel.attrib["Target"]
    sheets = []
    for sheet in wb.findall("main:sheets/main:sheet", NS):
        rid = sheet.attrib.get("{%s}id" % NS_REL_DOC)
        name = sheet.attrib["name"]
        target = rid_to_target.get(rid)
        sheets.append((name, "xl/" + target if target else None))
    return sheets


def cell_value(cell, shared):
    v = cell.find("main:v", NS)
    if v is None:
        return None
    value = v.text
    t = cell.attrib.get("t")
    if t == "s":
        try:
            return shared[int(value)]
        except Exception:
            return value
    return value


def read_sheet_rows(path, sheet_index=0):
    with zipfile.ZipFile(path, "r") as zf:
        sheets = sheet_map(zf)
        if not sheets:
            return []
        sheet_path = sheets[sheet_index][1]
        if not sheet_path:
            return []
        xml = zf.read(sheet_path)
        root = ET.fromstring(xml)
        shared = load_shared_strings(zf)
        rows = []
        for row in root.findall("main:sheetData/main:row", NS):
            cells = {}
            for c in row.findall("main:c", NS):
                ref = c.attrib.get("r")
                col = "".join(ch for ch in ref if ch.isalpha()) if ref else ""
                cells[col] = cell_value(c, shared)
            rows.append(cells)
        return rows


def parse_int(value):
    if value is None:
        return None
    s = str(value).strip()
    if s == "":
        return None
    try:
        return int(float(s))
    except ValueError:
        return None


def parse_bool(value):
    if value is None:
        return None
    s = str(value).strip().lower()
    if s in ("1", "true", "ture", "yes", "y", "是"):
        return True
    if s in ("0", "false", "no", "n", "否"):
        return False
    return None


def parse_coord(value):
    if value is None:
        return None
    s = str(value).strip()
    if not s:
        return None
    parts = [p.strip() for p in s.split(",") if p.strip()]
    if len(parts) != 2:
        return None
    try:
        return int(parts[0]), int(parts[1])
    except ValueError:
        return None


def lua_escape(value):
    return (
        value.replace("\\", "\\\\")
        .replace("\"", "\\\"")
        .replace("\r", "")
        .replace("\n", "\\n")
    )


def lua_value(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if value.is_integer():
            return str(int(value))
        return str(value)
    if isinstance(value, str):
        return '"' + lua_escape(value) + '"'
    if isinstance(value, (list, tuple)):
        return "{ " + ", ".join(lua_value(v) for v in value) + " }"
    raise TypeError("unsupported lua value: %r" % (value,))


def write_lua_table(path, var_name, rows, field_order):
    lines = ["local %s = {" % var_name]
    for row in rows:
        parts = []
        for key in field_order:
            if key not in row:
                continue
            value = row[key]
            if value is None:
                continue
            parts.append("%s = %s" % (key, lua_value(value)))
        lines.append("  { " + ", ".join(parts) + " },")
    lines.append("}")
    lines.append("")
    lines.append("return %s" % var_name)
    content = "\n".join(lines) + "\n"
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def write_lua_kv(path, var_name, mapping, order):
    lines = ["local %s = {" % var_name]
    for key in order:
        if key not in mapping:
            continue
        value = mapping[key]
        lines.append("  %s = %s," % (key, lua_value(value)))
    lines.append("}")
    lines.append("")
    lines.append("return %s" % var_name)
    content = "\n".join(lines) + "\n"
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def table_from_sheet(path):
    rows = read_sheet_rows(path)
    if not rows:
        return {}, []
    header = rows[0]
    col_map = {name: col for col, name in header.items() if name}
    return col_map, rows[2:]


def value_by_headers(row, col_map, headers):
    for header in headers:
        col = col_map.get(header)
        if col is None:
            continue
        value = row.get(col)
        if value is not None and str(value).strip() != "":
            return value
    return None


def infer_market_kind(page, product_id):
    if page == "座驾商店":
        return "vehicle"
    if page == "皮肤商店":
        return "skin"
    if product_id is not None:
        if product_id >= 5000:
            return "skin"
        if product_id >= 4000:
            return "vehicle"
    return "item"


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Export design xlsx files to generated lua config.")
    parser.add_argument("--mode", choices=["dev", "release"], default="dev", help="export mode")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv or [])
    release_mode = args.mode == "release"
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(os.path.join(script_dir, os.pardir))
    design_dir = os.path.join(root, "docs", "design")
    if not os.path.isdir(design_dir):
        # Backward compatibility: older repos may place xlsx files under root/design.
        design_dir = os.path.join(root, "design")
    config_dir = os.path.join(root, "Config", "Generated")
    os.makedirs(config_dir, exist_ok=True)

    tiles_path = os.path.join(design_dir, "蛋仔--大富翁--地块表.xlsx")
    items_path = os.path.join(design_dir, "蛋仔--大富翁--道具表.xlsx")
    chance_path = os.path.join(design_dir, "蛋仔--大富翁--机会表.xlsx")
    roles_path = os.path.join(design_dir, "蛋仔--大富翁--角色表.xlsx")
    constants_path = os.path.join(design_dir, "蛋仔--大富翁--常量表.xlsx")
    market_path = os.path.join(design_dir, "蛋仔--大富翁--黑市表.xlsx")
    vehicles_path = os.path.join(design_dir, "蛋仔--大富翁--座驾表.xlsx")
    skins_path = os.path.join(design_dir, "蛋仔--大富翁--皮肤表.xlsx")

    # Tiles
    type_map = {
        "地皮": "land",
        "起点": "start",
        "医院": "hospital",
        "深山": "mountain",
        "税务局": "tax",
        "黑市": "market",
        "机会卡": "chance",
        "道具卡": "item",
    }

    col_map, rows = table_from_sheet(tiles_path)
    tiles = []
    coord_to_id = {}
    for row in rows:
        tile_id = parse_int(row.get(col_map.get("地块id")))
        if not tile_id:
            continue
        name = row.get(col_map.get("地块名称")) or ""
        ttype_raw = row.get(col_map.get("地块类型"))
        ttype = type_map.get(ttype_raw, ttype_raw or "land")
        road = parse_coord(row.get(col_map.get("道路坐标")))
        build = parse_coord(row.get(col_map.get("建筑坐标")))
        price = parse_int(row.get(col_map.get("初始价格")))
        upgrade_costs = [
            parse_int(row.get(col_map.get("房屋价格"))),
            parse_int(row.get(col_map.get("别墅价格"))),
            parse_int(row.get(col_map.get("高楼价格"))),
        ]
        rents = [
            parse_int(row.get(col_map.get("初始租金"))),
            parse_int(row.get(col_map.get("房屋租金"))),
            parse_int(row.get(col_map.get("别墅租金"))),
            parse_int(row.get(col_map.get("高楼租金"))),
        ]
        record = {
            "id": tile_id,
            "name": name,
            "type": ttype,
        }
        if road:
            record["row"], record["col"] = road
            coord_to_id[road] = tile_id
        if build:
            record["build_row"], record["build_col"] = build
        if price is not None:
            record["price"] = price
        if any(v is not None for v in upgrade_costs):
            record["upgrade_costs"] = [v or 0 for v in upgrade_costs]
        if any(v is not None for v in rents):
            record["rents"] = [v or 0 for v in rents]
        tiles.append(record)

    write_lua_table(
        os.path.join(config_dir, "Tiles.lua"),
        "tiles",
        tiles,
        [
            "id",
            "name",
            "type",
            "row",
            "col",
            "build_row",
            "build_col",
            "price",
            "upgrade_costs",
            "rents",
        ],
    )

    # Roles
    col_map, rows = table_from_sheet(roles_path)
    roles = []
    for row in rows:
        role_id = parse_int(row.get(col_map.get("AI角色id")))
        if not role_id:
            continue
        roles.append(
            {
                "id": role_id,
                "name": row.get(col_map.get("角色名称")) or "",
                "prototype": row.get(col_map.get("原型")) or "",
                "description": row.get(col_map.get("形象描述")) or "",
            }
        )

    write_lua_table(
        os.path.join(config_dir, "Roles.lua"),
        "roles",
        roles,
        ["id", "name", "prototype", "description"],
    )

    # Items
    timing_map = {
        "行动后触发": "post_action",
        "行动前主动使用": "pre_action",
        "骰子生效前触发": "pre_move",
        "经过其他玩家时触发": "pass_player",
        "税务局征税时触发": "tax_prompt",
        "被穷神附身时触发": "trigger_poor_god",
        "主动使用": "manual",
    }
    col_map, rows = table_from_sheet(items_path)
    items = []
    for row in rows:
        item_id = parse_int(row.get(col_map.get("道具id")))
        if not item_id:
            continue
        timing_raw = row.get(col_map.get("使用时机")) or ""
        items.append(
            {
                "id": item_id,
                "name": row.get(col_map.get("道具名称")) or "",
                "tier": parse_int(row.get(col_map.get("道具等级"))),
                "shop_currency": row.get(col_map.get("黑市支付类型")) or "",
                "shop_price": parse_int(row.get(col_map.get("黑市支付价格"))),
                "weight": parse_int(row.get(col_map.get("随机权重"))),
                "angel_immune": parse_bool(row.get(col_map.get("天使是否免疫"))),
                "timing": timing_map.get(timing_raw, "manual"),
                "usage": row.get(col_map.get("操作方式")) or "",
                "description": row.get(col_map.get("道具说明")) or "",
            }
        )

    write_lua_table(
        os.path.join(config_dir, "Items.lua"),
        "items",
        items,
        [
            "id",
            "name",
            "tier",
            "shop_currency",
            "shop_price",
            "weight",
            "angel_immune",
            "timing",
            "usage",
            "description",
        ],
    )

    # Vehicles
    col_map, rows = table_from_sheet(vehicles_path)
    vehicles = []
    if not release_mode:
        for row in rows:
            vid = parse_int(row.get(col_map.get("座驾id")))
            if not vid:
                continue
            vehicles.append(
                {
                    "id": vid,
                    "name": row.get(col_map.get("座驾名称")) or "",
                    "tier": parse_int(row.get(col_map.get("座驾等级"))),
                    "dice_count": parse_int(row.get(col_map.get("骰子数"))),
                    "indestructible": parse_bool(row.get(col_map.get("是否不可摧毁（免疫导弹、台风等效果）"))),
                }
            )

    write_lua_table(
        os.path.join(config_dir, "Vehicles.lua"),
        "vehicles",
        vehicles,
        ["id", "name", "tier", "dice_count", "indestructible"],
    )

    # Skins
    if not os.path.exists(skins_path):
        raise FileNotFoundError("missing required design file: %s" % skins_path)
    col_map, rows = table_from_sheet(skins_path)
    skins = []
    for row in rows:
        skin_id = parse_int(row.get(col_map.get("皮肤id")))
        if not skin_id:
            continue
        skins.append(
            {
                "id": skin_id,
                "name": row.get(col_map.get("皮肤名称")) or "",
            }
        )

    write_lua_table(
        os.path.join(config_dir, "Skins.lua"),
        "skins",
        skins,
        ["id", "name"],
    )

    # Market
    col_map, rows = table_from_sheet(market_path)
    market = []
    for row in rows:
        order = parse_int(value_by_headers(row, col_map, ["排序", "表头排序值"]))
        pid = parse_int(value_by_headers(row, col_map, ["商品id", "商品ID"]))
        if not pid:
            continue
        page = value_by_headers(row, col_map, ["分页"]) or ""
        kind = infer_market_kind(page, pid)
        if release_mode and kind == "vehicle":
            continue
        record = {
            "order": order,
            "product_id": pid,
            "name": value_by_headers(row, col_map, ["商品名称"]) or "",
            "page": page,
            "kind": kind,
            "currency": value_by_headers(row, col_map, ["支付类型"]) or "",
            "price": parse_int(value_by_headers(row, col_map, ["支付价格"])),
            "limit": parse_int(value_by_headers(row, col_map, ["全局限量"])),
        }
        if order == -1:
            record["market_enabled"] = False
        market.append(record)

    write_lua_table(
        os.path.join(config_dir, "Market.lua"),
        "market",
        market,
        ["order", "product_id", "name", "page", "kind", "currency", "price", "limit", "market_enabled"],
    )

    # Chance cards
    effect_map = {
        "获得金币": "add_cash",
        "扣除金币": "pay_cash",
        "按比例扣除金币": "percent_pay_cash",
        "向其他玩家支付金币": "pay_others",
        "向其他玩家收取金币": "collect_from_others",
        "更换座驾": "set_vehicle",
        "强制后退": "move_backward",
        "强制前进": "move_forward",
        "获得道具": "grant_item",
        "丢弃道具": "discard_items",
        "丢弃地块": "discard_properties",
        "拆除建筑": "destroy_buildings_on_path",
        "重置地块": "reset_tiles_on_path",
        "强制移动": "forced_move",
    }
    target_map = {
        "抽卡玩家": "self",
        "全体玩家": "all",
        "指定地皮": "path",
    }
    col_map, rows = table_from_sheet(chance_path)
    cards = []
    for row in rows:
        cid = parse_int(row.get(col_map.get("事件id")))
        if not cid:
            continue
        target_raw = row.get(col_map.get("事件目标")) or ""
        effect_raw = row.get(col_map.get("事件类型")) or ""
        effect = effect_map.get(effect_raw, "")
        if release_mode and effect == "set_vehicle":
            continue
        param = row.get(col_map.get("事件参数"))

        record = {
            "id": cid,
            "description": row.get(col_map.get("事件描述")) or "",
            "weight": parse_int(row.get(col_map.get("随机权重"))),
            "negative": parse_bool(row.get(col_map.get("是否负收益"))),
            "target": target_map.get(target_raw, "self"),
            "effect": effect,
        }

        if effect == "add_cash" or effect == "pay_cash" or effect == "pay_others" or effect == "collect_from_others":
            record["amount"] = parse_int(param)
        elif effect == "percent_pay_cash":
            record["percent"] = parse_int(param)
        elif effect == "set_vehicle":
            record["vehicle_id"] = parse_int(param)
        elif effect == "move_backward" or effect == "move_forward":
            record["steps"] = parse_int(param)
        elif effect == "grant_item":
            record["item_id"] = parse_int(param)
        elif effect == "discard_items" or effect == "discard_properties":
            record["count"] = parse_int(param)
        elif effect == "forced_move":
            coord = parse_coord(param)
            if coord and coord in coord_to_id:
                record["destination_tile_id"] = coord_to_id[coord]

        cards.append(record)

    write_lua_table(
        os.path.join(config_dir, "ChanceCards.lua"),
        "chance_cards",
        cards,
        [
            "id",
            "description",
            "weight",
            "negative",
            "target",
            "effect",
            "amount",
            "percent",
            "vehicle_id",
            "steps",
            "item_id",
            "count",
            "destination_tile_id",
        ],
    )

    # Constants
    col_map, rows = table_from_sheet(constants_path)
    constants = {
        "pass_start_bonus": 2000,
        "hospital_fee": 5000,
        "hospital_stay_turns": 2,
        "mountain_stay_turns": 2,
        "tax_rate": 0.5,
        "inventory_slots": 5,
        "deity_duration_turns": 5,
        "starting_jindou": 0,
        "starting_leyuanbi": 0,
    }
    name_to_key = {
        "初始金币": "starting_cash",
        "初始金豆": "starting_jindou",
        "初始乐园币": "starting_leyuanbi",
        "初始骰子数": "default_dice_count",
        "操作倒计时（秒）": "action_timeout_seconds",
    }
    for row in rows:
        name = row.get(col_map.get("常量名称"))
        if not name:
            continue
        key = name_to_key.get(name)
        if not key:
            continue
        constants[key] = parse_int(row.get(col_map.get("常量参数")))

    write_lua_kv(
        os.path.join(config_dir, "Constants.lua"),
        "constants",
        constants,
        [
            "starting_cash",
            "starting_jindou",
            "starting_leyuanbi",
            "default_dice_count",
            "action_timeout_seconds",
            "pass_start_bonus",
            "hospital_fee",
            "hospital_stay_turns",
            "mountain_stay_turns",
            "tax_rate",
            "inventory_slots",
            "deity_duration_turns",
        ],
    )

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
