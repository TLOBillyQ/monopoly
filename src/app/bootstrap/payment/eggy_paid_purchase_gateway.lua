local logger = require("src.core.utils.logger")
local number_utils = require("src.core.utils.number_utils")
local runtime_ports = require("src.core.ports.runtime_ports")

local gateway = {}

local runtime_field = "__market_paid_runtime"
local panel_show_seconds = 10.0

local function _context()
  return require("src.game.systems.market.application.context")
end

local function _new_runtime()
  return {
    goods_id_by_product_id = {},
    product_id_by_goods_id = {},
    warned_missing_by_product_id = {},
    registered_role_ids = {},
    pending_by_role_id = {},
    on_purchase = nil,
    setup_done = false,
  }
end

local function _runtime(game)
  local rt = game[runtime_field]
  if not rt then
    rt = _new_runtime()
    game[runtime_field] = rt
  end
  return rt
end

local function _resolve_role(player)
  if not player or player.id == nil then
    return nil
  end
  local ok, role = pcall(runtime_ports.resolve_role, player.id)
  if not ok then
    return nil
  end
  return role
end

local function _resolve_role_id(player, role)
  if role and type(role.get_roleid) == "function" then
    local ok, role_id = pcall(role.get_roleid)
    if ok and role_id ~= nil then
      return role_id
    end
  end
  return player and player.id or nil
end

local function _warn_mapping_missing_once(rt, entry, reason)
  local product_id = entry and entry.product_id or nil
  if product_id == nil then
    return
  end
  if rt.warned_missing_by_product_id[product_id] then
    return
  end
  rt.warned_missing_by_product_id[product_id] = true
  logger.warn(
    "market paid goods mapping missing:",
    "product_id=" .. tostring(product_id),
    "name=" .. tostring(entry and entry.name or ""),
    "currency=" .. tostring(entry and entry.currency or ""),
    "reason=" .. tostring(reason or "mapping_missing")
  )
end

local function _load_goods_list()
  if not (GameAPI and type(GameAPI.get_goods_list) == "function") then
    return nil
  end
  local ok, list = pcall(GameAPI.get_goods_list)
  if ok and type(list) == "table" then
    return list
  end
  return nil
end

local function _index_goods_by_name(goods_list)
  local goods_by_name = {}
  local duplicate_name = {}
  if type(goods_list) ~= "table" then
    return goods_by_name, duplicate_name
  end
  for _, goods in ipairs(goods_list) do
    local name = goods and goods.name or nil
    if type(name) == "string" and name ~= "" then
      if goods_by_name[name] and goods_by_name[name] ~= goods then
        duplicate_name[name] = true
      else
        goods_by_name[name] = goods
      end
    end
  end
  return goods_by_name, duplicate_name
end

local function _should_map_paid_entry(context_service, entry)
  local currency = context_service.entry_currency(entry)
  return context_service.is_paid_currency(currency)
    and context_service.entry_market_enabled(entry)
    and context_service.entry_vehicle_enabled(entry)
end

local function _record_goods_mapping(rt, entry, market_name, goods_id, duplicate_name)
  rt.goods_id_by_product_id[entry.product_id] = goods_id
  local mapped_product_id = rt.product_id_by_goods_id[goods_id]
  if mapped_product_id == nil then
    rt.product_id_by_goods_id[goods_id] = entry.product_id
  elseif mapped_product_id ~= entry.product_id then
    logger.warn(
      "market paid goods ambiguous goods_id:",
      "goods_id=" .. tostring(goods_id),
      "product_id=" .. tostring(entry.product_id),
      "mapped_product_id=" .. tostring(mapped_product_id)
    )
  end
  if duplicate_name[market_name] then
    logger.warn(
      "market paid goods duplicate name match:",
      "name=" .. tostring(market_name),
      "product_id=" .. tostring(entry.product_id)
    )
  end
end

local function _resolve_missing_mapping_reason(goods_list)
  if type(goods_list) == "table" then
    return "name_mapping_not_found"
  end
  return "goods_list_unavailable"
end

local function _build_goods_mappings(game)
  local rt = _runtime(game)
  rt.goods_id_by_product_id = {}
  rt.product_id_by_goods_id = {}
  rt.warned_missing_by_product_id = {}

  local goods_list = _load_goods_list()
  local goods_by_name, duplicate_name = _index_goods_by_name(goods_list)
  local context_service = _context()
  for _, entry in ipairs(context_service.entries()) do
    if _should_map_paid_entry(context_service, entry) then
      local market_name = entry and entry.name or nil
      local goods = market_name and goods_by_name[market_name] or nil
      local goods_id = goods and goods.goods_id or nil
      if goods_id ~= nil and goods_id ~= "" then
        _record_goods_mapping(rt, entry, market_name, goods_id, duplicate_name)
      else
        _warn_mapping_missing_once(rt, entry, _resolve_missing_mapping_reason(goods_list))
      end
    end
  end
end

local function _resolve_goods_id(game, entry)
  local rt = _runtime(game)
  local goods_id = rt.goods_id_by_product_id[entry.product_id]
  if goods_id == nil or goods_id == "" then
    _warn_mapping_missing_once(rt, entry, "name_mapping_not_found")
    return nil, "goods_mapping_missing"
  end
  return goods_id, nil
end

local function _pending_queue(rt, role_id)
  local queue = rt.pending_by_role_id[role_id]
  if type(queue) ~= "table" then
    queue = {}
    rt.pending_by_role_id[role_id] = queue
  end
  return queue
end

local function _push_pending(rt, role_id, pending)
  local queue = _pending_queue(rt, role_id)
  queue[#queue + 1] = pending
end

local function _consume_pending(rt, role_id, goods_id)
  local queue = rt.pending_by_role_id[role_id]
  if type(queue) ~= "table" then
    return nil
  end
  local target_goods_id = tostring(goods_id)
  for index, pending in ipairs(queue) do
    if tostring(pending.goods_id) == target_goods_id then
      table.remove(queue, index)
      if #queue == 0 then
        rt.pending_by_role_id[role_id] = nil
      end
      return pending
    end
  end
  return nil
end

local function _register_purchase_event_for_role(game, player)
  if not RegisterTriggerEvent or not EVENT or not EVENT.SPEC_ROLE_PURCHASE_GOODS then
    return
  end
  local role = _resolve_role(player)
  if not role then
    return
  end
  local role_id = _resolve_role_id(player, role)
  if role_id == nil then
    return
  end
  local rt = _runtime(game)
  if rt.registered_role_ids[role_id] then
    return
  end
  RegisterTriggerEvent({ EVENT.SPEC_ROLE_PURCHASE_GOODS, role_id }, function(_, _, data)
    local goods_id = data and data.goods_id or nil
    if goods_id == nil or goods_id == "" then
      logger.warn("market paid callback ignored: goods_id missing")
      return
    end
    local callback_role = data and data.role or nil
    local callback_role_id = _resolve_role_id(nil, callback_role)
    local pending = callback_role_id and _consume_pending(rt, callback_role_id, goods_id) or nil
    if not pending then
      logger.warn("market paid callback ignored: pending missing", "role_id=" .. tostring(callback_role_id), "goods_id=" .. tostring(goods_id))
      return
    end
    local callback_player = game:find_player_by_id(pending.player_id)
    if not callback_player then
      logger.warn("market paid callback ignored: player missing", "player_id=" .. tostring(pending.player_id))
      return
    end
  local entry = _context().entry_by_id(pending.product_id)
    if not entry then
      logger.warn("market paid callback ignored: market entry missing", "product_id=" .. tostring(pending.product_id))
      return
    end
    if type(rt.on_purchase) == "function" then
      rt.on_purchase(game, callback_player, entry, pending)
    end
  end)
  rt.registered_role_ids[role_id] = true
end

function gateway.setup_for_game(game, on_purchase)
  local rt = _runtime(game)
  if type(on_purchase) == "function" then
    rt.on_purchase = on_purchase
  end
  if rt.setup_done == true then
    return
  end
  _build_goods_mappings(game)
  local players = game and game.players or nil
  if type(players) ~= "table" then
    rt.setup_done = true
    return
  end
  for _, player in ipairs(players) do
    _register_purchase_event_for_role(game, player)
  end
  rt.setup_done = true
end

function gateway.can_start(game, player, entry)
  gateway.setup_for_game(game)
  local goods_id, goods_reason = _resolve_goods_id(game, entry)
  if goods_id == nil then
    return false, goods_reason or "goods_mapping_missing"
  end
  local role = _resolve_role(player)
  if not role then
    return false, "role_unresolved"
  end
  if type(role.show_goods_purchase_panel) ~= "function" then
    return false, "purchase_api_missing"
  end
  return true, goods_id
end

function gateway.start(game, player, entry)
  local ok_ready, goods_or_reason = gateway.can_start(game, player, entry)
  if not ok_ready then
    return false, goods_or_reason
  end
  local goods_id = goods_or_reason
  local role = _resolve_role(player)
  if not role then
    return false, "role_unresolved"
  end
  local ok_call = pcall(role.show_goods_purchase_panel, goods_id, panel_show_seconds)
  if not ok_call then
    return false, "panel_call_failed"
  end
  local role_id = _resolve_role_id(player, role)
  if role_id == nil then
    return false, "role_id_missing"
  end
  local rt = _runtime(game)
  _push_pending(rt, role_id, {
    player_id = player.id,
    product_id = entry.product_id,
    goods_id = goods_id,
  })
  return true, nil
end

return gateway
