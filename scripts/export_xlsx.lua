local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _script_dir(script_path)
  local normalized = _normalize_path(script_path)
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local _raw_script_path = arg and arg[0] or "scripts/export_xlsx.lua"
local _entry_script_dir = _script_dir(_raw_script_path)
local _entry_parent_dir = _entry_script_dir:match("^(.*)/[^/]+$") or "."
package.path = _entry_script_dir .. "/?.lua;"
  .. _entry_script_dir .. "/?/?.lua;"
  .. _entry_parent_dir .. "/?.lua;"
  .. _entry_parent_dir .. "/?/?.lua;"
  .. package.path

local bootstrap = require("bootstrap")
local env = bootstrap.install(_raw_script_path)
local common = require("lib.common")
local xlsx_reader = require("lib.xlsx_reader")

local function _text(zh, en)
  return common.bilingual(zh, en)
end

local function _fail(message)
  io.stderr:write(tostring(message), "\n")
  os.exit(1)
end

local function _trim(text)
  local source = tostring(text or "")
  source = source:gsub("^%s+", "")
  source = source:gsub("%s+$", "")
  return source
end

local function _parse_int(value)
  if value == nil then
    return nil
  end
  local normalized = _trim(value)
  if normalized == "" then
    return nil
  end

  local direct = common.to_integer(normalized)
  if direct ~= nil then
    return direct
  end

  local sign, integer_part = normalized:match("^([+-]?)(%d+)%.%d+$")
  if integer_part ~= nil then
    if sign == "-" then
      return common.to_integer("-" .. integer_part)
    end
    return common.to_integer(integer_part)
  end

  return nil
end

local function _parse_bool(value)
  if value == nil then
    return nil
  end
  local normalized = _trim(value):lower()
  if normalized == "" then
    return nil
  end
  if normalized == "1" or normalized == "true" or normalized == "ture" or normalized == "yes" or normalized == "y" or normalized == "是" then
    return true
  end
  if normalized == "0" or normalized == "false" or normalized == "no" or normalized == "n" or normalized == "否" then
    return false
  end
  return nil
end

local function _parse_coord(value)
  if value == nil then
    return nil
  end
  local normalized = _trim(value)
  if normalized == "" then
    return nil
  end
  local first, second = normalized:match("^([^,]+),([^,]+)$")
  if first == nil then
    return nil
  end
  local row = _parse_int(first)
  local col = _parse_int(second)
  if row == nil or col == nil then
    return nil
  end
  return { row, col }
end

local function _lua_escape(value)
  local escaped = tostring(value or "")
  escaped = escaped:gsub("\\", "\\\\")
  escaped = escaped:gsub("\"", "\\\"")
  escaped = escaped:gsub("\r", "")
  escaped = escaped:gsub("\n", "\\n")
  return escaped
end

local function _lua_value(value)
  local value_type = type(value)
  if value == nil then
    return "nil"
  end
  if value_type == "boolean" then
    return value and "true" or "false"
  end
  if common.is_numeric(value) then
    return tostring(value)
  end
  if value_type == "string" then
    return '"' .. _lua_escape(value) .. '"'
  end
  if value_type == "table" then
    local parts = {}
    for _, item in ipairs(value) do
      parts[#parts + 1] = _lua_value(item)
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
  end
  _fail(_text(
    "不支持的 Lua 值类型: " .. tostring(value),
    "Unsupported Lua value: " .. tostring(value)
  ))
end

local function _write_lua_table(path, var_name, rows, field_order)
  local lines = { "local " .. tostring(var_name) .. " = {" }
  for _, row in ipairs(rows or {}) do
    local parts = {}
    for _, key in ipairs(field_order or {}) do
      local value = row[key]
      if value ~= nil then
        parts[#parts + 1] = tostring(key) .. " = " .. _lua_value(value)
      end
    end
    lines[#lines + 1] = "  { " .. table.concat(parts, ", ") .. " },"
  end
  lines[#lines + 1] = "}"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "return " .. tostring(var_name)
  lines[#lines + 1] = ""

  local ok, err = common.write_file(path, table.concat(lines, "\n"))
  if not ok then
    _fail(err)
  end
end

local function _write_lua_kv(path, var_name, mapping, order)
  local lines = { "local " .. tostring(var_name) .. " = {" }
  for _, key in ipairs(order or {}) do
    if mapping[key] ~= nil then
      lines[#lines + 1] = "  " .. tostring(key) .. " = " .. _lua_value(mapping[key]) .. ","
    end
  end
  lines[#lines + 1] = "}"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "return " .. tostring(var_name)
  lines[#lines + 1] = ""

  local ok, err = common.write_file(path, table.concat(lines, "\n"))
  if not ok then
    _fail(err)
  end
end

local function _table_from_sheet(path)
  local rows, err = xlsx_reader.read_sheet_rows(path, 1)
  if rows == nil then
    _fail(err)
  end
  if #rows == 0 then
    return {}, {}
  end
  local header = rows[1]
  local col_map = {}
  for col, name in pairs(header) do
    if name ~= nil and _trim(name) ~= "" then
      col_map[name] = col
    end
  end
  local data_rows = {}
  for index = 3, #rows do
    data_rows[#data_rows + 1] = rows[index]
  end
  return col_map, data_rows
end

local function _value_by_headers(row, col_map, headers)
  for _, header in ipairs(headers or {}) do
    local col = col_map[header]
    if col ~= nil then
      local value = row[col]
      if value ~= nil and _trim(value) ~= "" then
        return value
      end
    end
  end
  return nil
end

local function _infer_market_kind(page, product_id)
  if page == "座驾商店" then
    return "vehicle"
  end
  if page == "皮肤商店" then
    return "skin"
  end
  if product_id ~= nil then
    if product_id >= 5000 then
      return "skin"
    end
    if product_id >= 4000 then
      return "vehicle"
    end
  end
  return "item"
end

local function _parse_args(args)
  local options = {
    mode = "dev",
    output_dir = nil,
  }
  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--mode" then
      options.mode = args[index + 1] or "dev"
      index = index + 2
    elseif token == "--output-dir" then
      options.output_dir = args[index + 1]
      index = index + 2
    elseif token == "--help" or token == "-h" then
      print(_text(
        "用法: lua scripts/export_xlsx.lua [--mode dev|release] [--output-dir OUTDIR]",
        "Usage: lua scripts/export_xlsx.lua [--mode dev|release] [--output-dir OUTDIR]"
      ))
      os.exit(0)
    else
      _fail(_text(
        "未知参数: " .. tostring(token),
        "Unknown flag: " .. tostring(token)
      ))
    end
  end
  if options.mode ~= "dev" and options.mode ~= "release" then
    _fail(_text(
      "无效的 --mode 参数: " .. tostring(options.mode),
      "Invalid --mode value: " .. tostring(options.mode)
    ))
  end
  if options.output_dir ~= nil then
    options.output_dir = common.resolve_path(common.current_dir(), options.output_dir)
  end
  return options
end

local function _require_file(path)
  if not common.path_exists(path) then
    _fail(_text(
      "缺少设计文件: " .. tostring(path),
      "Missing required design file: " .. tostring(path)
    ))
  end
end

local function main(args)
  local options = _parse_args(args or {})
  local release_mode = options.mode == "release"
  local design_dir = common.join_path(env.repo_root, "docs/design")
  if not common.is_dir(design_dir) then
    design_dir = common.join_path(env.repo_root, "design")
  end
  local config_dir = options.output_dir or common.join_path(env.repo_root, "Config/generated")
  local ensure_ok, ensure_err = common.ensure_dir(config_dir)
  if not ensure_ok then
    _fail(ensure_err)
  end

  local tiles_path = common.join_path(design_dir, "蛋仔--大富翁--地块表.xlsx")
  local items_path = common.join_path(design_dir, "蛋仔--大富翁--道具表.xlsx")
  local chance_path = common.join_path(design_dir, "蛋仔--大富翁--机会表.xlsx")
  local roles_path = common.join_path(design_dir, "蛋仔--大富翁--角色表.xlsx")
  local constants_path = common.join_path(design_dir, "蛋仔--大富翁--常量表.xlsx")
  local market_path = common.join_path(design_dir, "蛋仔--大富翁--黑市表.xlsx")
  local vehicles_path = common.join_path(design_dir, "蛋仔--大富翁--座驾表.xlsx")
  local skins_path = common.join_path(design_dir, "蛋仔--大富翁--皮肤表.xlsx")

  _require_file(tiles_path)
  _require_file(items_path)
  _require_file(chance_path)
  _require_file(roles_path)
  _require_file(constants_path)
  _require_file(market_path)
  _require_file(vehicles_path)
  _require_file(skins_path)

  local type_map = {
    ["地皮"] = "land",
    ["起点"] = "start",
    ["医院"] = "hospital",
    ["深山"] = "mountain",
    ["税务局"] = "tax",
    ["黑市"] = "market",
    ["机会卡"] = "chance",
    ["道具卡"] = "item",
  }

  local col_map, rows = _table_from_sheet(tiles_path)
  local tiles = {}
  local coord_to_id = {}
  for _, row in ipairs(rows) do
    local tile_id = _parse_int(row[col_map["地块id"]])
    if tile_id ~= nil and tile_id ~= 0 then
      local tile_name = row[col_map["地块名称"]] or ""
      local tile_type_raw = row[col_map["地块类型"]]
      local tile_type = type_map[tile_type_raw] or tile_type_raw or "land"
      local road = _parse_coord(row[col_map["道路坐标"]])
      local build = _parse_coord(row[col_map["建筑坐标"]])
      local price = _parse_int(row[col_map["初始价格"]])
      local upgrade_costs = {
        _parse_int(row[col_map["房屋价格"]]),
        _parse_int(row[col_map["别墅价格"]]),
        _parse_int(row[col_map["高楼价格"]]),
      }
      local rents = {
        _parse_int(row[col_map["初始租金"]]),
        _parse_int(row[col_map["房屋租金"]]),
        _parse_int(row[col_map["别墅租金"]]),
        _parse_int(row[col_map["高楼租金"]]),
      }
      local record = {
        id = tile_id,
        name = tile_name,
        type = tile_type,
      }
      if road ~= nil then
        record.row = road[1]
        record.col = road[2]
        coord_to_id[table.concat(road, ",")] = tile_id
      end
      if build ~= nil then
        record.build_row = build[1]
        record.build_col = build[2]
      end
      if price ~= nil then
        record.price = price
      end
      local has_upgrade_costs = false
      for _, value in ipairs(upgrade_costs) do
        if value ~= nil then
          has_upgrade_costs = true
          break
        end
      end
      if has_upgrade_costs then
        record.upgrade_costs = { upgrade_costs[1] or 0, upgrade_costs[2] or 0, upgrade_costs[3] or 0 }
      end
      local has_rents = false
      for _, value in ipairs(rents) do
        if value ~= nil then
          has_rents = true
          break
        end
      end
      if has_rents then
        record.rents = { rents[1] or 0, rents[2] or 0, rents[3] or 0, rents[4] or 0 }
      end
      tiles[#tiles + 1] = record
    end
  end
  _write_lua_table(common.join_path(config_dir, "tiles.lua"), "tiles", tiles, {
    "id", "name", "type", "row", "col", "build_row", "build_col", "price", "upgrade_costs", "rents"
  })

  col_map, rows = _table_from_sheet(roles_path)
  local roles = {}
  for _, row in ipairs(rows) do
    local role_id = _parse_int(row[col_map["AI角色id"]])
    if role_id ~= nil and role_id ~= 0 then
      roles[#roles + 1] = {
        id = role_id,
        name = row[col_map["角色名称"]] or "",
        prototype = row[col_map["原型"]] or "",
        description = row[col_map["形象描述"]] or "",
      }
    end
  end
  _write_lua_table(common.join_path(config_dir, "roles.lua"), "roles", roles, {
    "id", "name", "prototype", "description"
  })

  local timing_map = {
    ["行动后触发"] = "post_action",
    ["行动前主动使用"] = "pre_action",
    ["骰子生效前触发"] = "pre_move",
    ["经过其他玩家时触发"] = "pass_player",
    ["税务局征税时触发"] = "tax_prompt",
    ["被穷神附身时触发"] = "trigger_poor_god",
    ["主动使用"] = "manual",
  }
  col_map, rows = _table_from_sheet(items_path)
  local items = {}
  for _, row in ipairs(rows) do
    local item_id = _parse_int(row[col_map["道具id"]])
    if item_id ~= nil and item_id ~= 0 then
      local timing_raw = row[col_map["使用时机"]] or ""
      items[#items + 1] = {
        id = item_id,
        name = row[col_map["道具名称"]] or "",
        tier = _parse_int(row[col_map["道具等级"]]),
        shop_currency = row[col_map["黑市支付类型"]] or "",
        shop_price = _parse_int(row[col_map["黑市支付价格"]]),
        weight = _parse_int(row[col_map["随机权重"]]),
        angel_immune = _parse_bool(row[col_map["天使是否免疫"]]),
        timing = timing_map[timing_raw] or "manual",
        usage = row[col_map["操作方式"]] or "",
        description = row[col_map["道具说明"]] or "",
      }
    end
  end
  _write_lua_table(common.join_path(config_dir, "items.lua"), "items", items, {
    "id", "name", "tier", "shop_currency", "shop_price", "weight", "angel_immune", "timing", "usage", "description"
  })

  col_map, rows = _table_from_sheet(vehicles_path)
  local vehicles = {}
  if not release_mode then
    for _, row in ipairs(rows) do
      local vehicle_id = _parse_int(row[col_map["座驾id"]])
      if vehicle_id ~= nil and vehicle_id ~= 0 then
        vehicles[#vehicles + 1] = {
          id = vehicle_id,
          name = row[col_map["座驾名称"]] or "",
          tier = _parse_int(row[col_map["座驾等级"]]),
          dice_count = _parse_int(row[col_map["骰子数"]]),
          indestructible = _parse_bool(row[col_map["是否不可摧毁（免疫导弹、台风等效果）"]]),
        }
      end
    end
  end
  _write_lua_table(common.join_path(config_dir, "vehicles.lua"), "vehicles", vehicles, {
    "id", "name", "tier", "dice_count", "indestructible"
  })

  col_map, rows = _table_from_sheet(skins_path)
  local skins = {}
  for _, row in ipairs(rows) do
    local skin_id = _parse_int(row[col_map["皮肤id"]])
    if skin_id ~= nil and skin_id ~= 0 then
      skins[#skins + 1] = {
        id = skin_id,
        name = row[col_map["皮肤名称"]] or "",
      }
    end
  end
  _write_lua_table(common.join_path(config_dir, "skins.lua"), "skins", skins, {
    "id", "name"
  })

  col_map, rows = _table_from_sheet(market_path)
  local market = {}
  for _, row in ipairs(rows) do
    local order = _parse_int(_value_by_headers(row, col_map, { "排序", "表头排序值" }))
    local product_id = _parse_int(_value_by_headers(row, col_map, { "商品id", "商品ID" }))
    if product_id ~= nil and product_id ~= 0 then
      local page = _value_by_headers(row, col_map, { "分页" }) or ""
      local kind = _infer_market_kind(page, product_id)
      if not (release_mode and kind == "vehicle") then
        local record = {
          order = order,
          product_id = product_id,
          name = _value_by_headers(row, col_map, { "商品名称" }) or "",
          page = page,
          kind = kind,
          currency = _value_by_headers(row, col_map, { "支付类型" }) or "",
          price = _parse_int(_value_by_headers(row, col_map, { "支付价格" })),
          limit = _parse_int(_value_by_headers(row, col_map, { "全局限量" })),
        }
        if order == -1 then
          record.market_enabled = false
        end
        market[#market + 1] = record
      end
    end
  end
  _write_lua_table(common.join_path(config_dir, "market.lua"), "market", market, {
    "order", "product_id", "name", "page", "kind", "currency", "price", "limit", "market_enabled"
  })

  local effect_map = {
    ["获得金币"] = "add_cash",
    ["扣除金币"] = "pay_cash",
    ["按比例扣除金币"] = "percent_pay_cash",
    ["向其他玩家支付金币"] = "pay_others",
    ["向其他玩家收取金币"] = "collect_from_others",
    ["更换座驾"] = "set_vehicle",
    ["强制后退"] = "move_backward",
    ["强制前进"] = "move_forward",
    ["获得道具"] = "grant_item",
    ["丢弃道具"] = "discard_items",
    ["丢弃地块"] = "discard_properties",
    ["拆除建筑"] = "destroy_buildings_on_path",
    ["重置地块"] = "reset_tiles_on_path",
    ["强制移动"] = "forced_move",
  }
  local target_map = {
    ["抽卡玩家"] = "self",
    ["全体玩家"] = "all",
    ["指定地皮"] = "path",
  }
  col_map, rows = _table_from_sheet(chance_path)
  local cards = {}
  for _, row in ipairs(rows) do
    local card_id = _parse_int(row[col_map["事件id"]])
    if card_id ~= nil and card_id ~= 0 then
      local target_raw = row[col_map["事件目标"]] or ""
      local effect_raw = row[col_map["事件类型"]] or ""
      local effect = effect_map[effect_raw] or ""
      if not (release_mode and effect == "set_vehicle") then
        local param = row[col_map["事件参数"]]
        local record = {
          id = card_id,
          description = row[col_map["事件描述"]] or "",
          weight = _parse_int(row[col_map["随机权重"]]),
          negative = _parse_bool(row[col_map["是否负收益"]]),
          target = target_map[target_raw] or "self",
          effect = effect,
        }

        if effect == "add_cash" or effect == "pay_cash" or effect == "pay_others" or effect == "collect_from_others" then
          record.amount = _parse_int(param)
        elseif effect == "percent_pay_cash" then
          record.percent = _parse_int(param)
        elseif effect == "set_vehicle" then
          record.vehicle_id = _parse_int(param)
        elseif effect == "move_backward" or effect == "move_forward" then
          record.steps = _parse_int(param)
        elseif effect == "grant_item" then
          record.item_id = _parse_int(param)
        elseif effect == "discard_items" or effect == "discard_properties" then
          record.count = _parse_int(param)
        elseif effect == "forced_move" then
          local coord = _parse_coord(param)
          if coord ~= nil then
            record.destination_tile_id = coord_to_id[table.concat(coord, ",")]
          end
        end

        cards[#cards + 1] = record
      end
    end
  end
  _write_lua_table(common.join_path(config_dir, "chance_cards.lua"), "chance_cards", cards, {
    "id", "description", "weight", "negative", "target", "effect", "amount", "percent", "vehicle_id", "steps", "item_id", "count", "destination_tile_id"
  })

  col_map, rows = _table_from_sheet(constants_path)
  local constants = {
    pass_start_bonus = 2000,
    hospital_fee = 5000,
    hospital_stay_turns = 2,
    mountain_stay_turns = 2,
    tax_rate = 0.5,
    inventory_slots = 5,
    deity_duration_turns = 5,
    starting_jindou = 0,
    starting_leyuanbi = 0,
  }
  local name_to_key = {
    ["初始金币"] = "starting_cash",
    ["初始金豆"] = "starting_jindou",
    ["初始乐园币"] = "starting_leyuanbi",
    ["初始骰子数"] = "default_dice_count",
    ["操作倒计时（秒）"] = "action_timeout_seconds",
  }
  for _, row in ipairs(rows) do
    local name = row[col_map["常量名称"]]
    if name ~= nil and name_to_key[name] ~= nil then
      constants[name_to_key[name]] = _parse_int(row[col_map["常量参数"]])
    end
  end
  _write_lua_kv(common.join_path(config_dir, "constants.lua"), "constants", constants, {
    "starting_cash", "starting_jindou", "starting_leyuanbi", "default_dice_count", "action_timeout_seconds", "pass_start_bonus", "hospital_fee", "hospital_stay_turns", "mountain_stay_turns", "tax_rate", "inventory_slots", "deity_duration_turns"
  })

  return 0
end

os.exit(main(arg or {}))
