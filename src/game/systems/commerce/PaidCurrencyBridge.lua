local paid_goods_cfg = require("src.game.systems.commerce.config.RuntimePaidGoods")
local logger = require("src.core.Logger")
local number_utils = require("src.core.NumberUtils")
local runtime_ports = require("src.core.RuntimePorts")

local bridge = {}

local game_context_field = "__paid_currency_bridge_ctx"
local goods_name_sample_limit = 8

local function _new_context(game)
  return {
    game = game,
    resolved_by_currency = {},
    status_by_currency = {},
    player_id_by_role_id = {},
    registered_role_ids = {},
    mapping_warned_by_currency = {},
  }
end

local function _read_truthy_flag(raw)
  if raw == true then
    return true
  end
  if raw == 1 then
    return true
  end
  if raw == "1" then
    return true
  end
  if raw == "true" then
    return true
  end
  if raw == "TRUE" then
    return true
  end
  return false
end

local function _is_release_build()
  local globals = _G
  local raw = globals and globals.RELEASE_BUILD or nil
  return _read_truthy_flag(raw)
end

local function _resolve_context(game)
  assert(game ~= nil, "missing game context")
  local ctx = game[game_context_field]
  if not ctx then
    ctx = _new_context(game)
    game[game_context_field] = ctx
  end
  return ctx
end

local function _list_goods()
  if not (GameAPI and GameAPI.get_goods_list) then
    return {}
  end
  local ok, goods_list = pcall(GameAPI.get_goods_list)
  if not ok or type(goods_list) ~= "table" then
    return {}
  end
  return goods_list
end

local function _goods_by_name(goods_list)
  local lookup = {}
  for _, goods in ipairs(goods_list or {}) do
    local name = goods and goods.name or nil
    if name and name ~= "" then
      lookup[name] = goods
    end
  end
  return lookup
end

local function _resolve_goods_names(cfg_entry)
  local names = {}
  if cfg_entry and cfg_entry.goods_name then
    table.insert(names, cfg_entry.goods_name)
  end
  if cfg_entry and type(cfg_entry.goods_names) == "table" then
    for _, name in ipairs(cfg_entry.goods_names) do
      table.insert(names, name)
    end
  end
  return names
end

local function _sample_goods_names(goods_list)
  local out = {}
  for _, goods in ipairs(goods_list or {}) do
    local name = goods and goods.name or nil
    if name and name ~= "" then
      out[#out + 1] = tostring(name)
      if #out >= goods_name_sample_limit then
        break
      end
    end
  end
  if #out == 0 then
    return "none"
  end
  return table.concat(out, ",")
end

local function _warn_mapping_missing_once(ctx, currency, reason, cfg_entry, goods_count, sample_names)
  local warned = ctx.mapping_warned_by_currency or {}
  ctx.mapping_warned_by_currency = warned
  if warned[currency] then
    return
  end
  warned[currency] = true
  local expected_names = table.concat(_resolve_goods_names(cfg_entry), ",")
  if expected_names == "" then
    expected_names = "none"
  end
  logger.warn(
    "paid goods mapping missing:",
    tostring(currency),
    "reason=" .. tostring(reason or "mapping_missing"),
    "expected_names=" .. expected_names,
    "goods_count=" .. tostring(goods_count),
    "goods_names_sample=" .. tostring(sample_names)
  )
end

local function _build_resolved_entry(goods_id, commodity_id, unit_value, source, goods_name)
  return {
    goods_id = goods_id,
    commodity_id = commodity_id,
    unit_value = unit_value,
    source = source,
    goods_name = goods_name,
  }
end

local function _resolve_currency_entry_by_ids(currency, cfg_entry, unit_value)
  local goods_id = cfg_entry and cfg_entry.goods_id or nil
  local commodity_id = cfg_entry and cfg_entry.commodity_id or nil
  if goods_id == nil and commodity_id == nil then
    return nil
  end
  local resolved_commodity_id = number_utils.to_integer(commodity_id)
  if not goods_id or goods_id == "" or not resolved_commodity_id or resolved_commodity_id <= 0 then
    return false, "invalid_static_ids"
  end
  return _build_resolved_entry(goods_id, resolved_commodity_id, unit_value, "id", nil), nil
end

local function _resolve_currency_entry(ctx, goods_lookup, currency, cfg_entry, goods_count, sample_names)
  local unit_value = cfg_entry and cfg_entry.unit_value or 1
  if not number_utils.is_numeric(unit_value) or unit_value <= 0 then
    logger.warn("paid goods invalid unit_value:", tostring(currency), tostring(unit_value))
    return nil
  end

  local by_ids, by_ids_err = _resolve_currency_entry_by_ids(currency, cfg_entry, unit_value)
  if by_ids then
    return by_ids, nil
  end
  if by_ids == false then
    return nil, by_ids_err
  end

  for _, name in ipairs(_resolve_goods_names(cfg_entry)) do
    local goods = goods_lookup[name]
    local commodity_infos = goods and goods.commodity_infos or nil
    local first = commodity_infos and commodity_infos[1] or nil
    local commodity_id = first and first[1] or nil
    if goods and goods.goods_id and commodity_id then
      local resolved_commodity_id = number_utils.to_integer(commodity_id)
      if resolved_commodity_id and resolved_commodity_id > 0 then
        return _build_resolved_entry(goods.goods_id, resolved_commodity_id, unit_value, "name", name), nil
      end
    end
  end

  return nil, "name_mapping_not_found"
end

local function _resolve_goods_mapping(ctx)
  ctx.resolved_by_currency = {}
  ctx.status_by_currency = {}
  ctx.mapping_warned_by_currency = {}
  if paid_goods_cfg.enabled ~= true then
    return
  end

  local goods_list = _list_goods()
  local goods_lookup = _goods_by_name(goods_list)
  local goods_count = #goods_list
  local sample_names = _sample_goods_names(goods_list)
  local currencies = paid_goods_cfg.currencies or {}
  for currency, cfg_entry in pairs(currencies) do
    local resolved, reason = _resolve_currency_entry(ctx, goods_lookup, currency, cfg_entry, goods_count, sample_names)
    if resolved then
      ctx.resolved_by_currency[currency] = resolved
      ctx.status_by_currency[currency] = {
        state = "ready",
        source = resolved.source,
      }
    else
      local expected_names = table.concat(_resolve_goods_names(cfg_entry), ",")
      if expected_names == "" then
        expected_names = "none"
      end
      ctx.status_by_currency[currency] = {
        state = "unavailable",
        reason = reason or "mapping_missing",
      }
      _warn_mapping_missing_once(ctx, currency, reason or "mapping_missing", cfg_entry, goods_count, sample_names)
    end
  end
end

local function _resolve_role(player)
  if not player or not player.id then
    return nil
  end
  local ok, role = pcall(runtime_ports.resolve_role, player.id)
  if not ok then
    return nil
  end
  return role
end

local function _sync_all_managed_currencies(ctx, game, player)
  for currency in pairs(ctx.resolved_by_currency) do
    bridge.sync_player_currency(game, player, currency)
  end
end

local function _register_purchase_event(ctx, role_id)
  if ctx.registered_role_ids[role_id] then
    return
  end
  if not RegisterTriggerEvent then
    return
  end
  if not (EVENT and EVENT.SPEC_ROLE_PURCHASE_GOODS) then
    return
  end
  RegisterTriggerEvent({ EVENT.SPEC_ROLE_PURCHASE_GOODS, role_id }, function(_, _, _)
    local game = ctx.game
    if not game or not game.players then
      return
    end
    local player_id = ctx.player_id_by_role_id[role_id]
    local player = player_id and game:find_player_by_id(player_id) or nil
    if not player then
      return
    end
    _sync_all_managed_currencies(ctx, game, player)

    local pending = game.turn and game.turn.pending_choice or nil
    local meta = pending and pending.meta or nil
    if not (pending and pending.kind == "market_buy" and meta and meta.await_paid_topup == true) then
      return
    end
    local pending_player_id = number_utils.to_integer(meta.player_id)
    if pending_player_id ~= player.id then
      return
    end
    local option_id = number_utils.to_integer(meta.await_paid_topup_option_id)
    if option_id == nil or pending.id == nil then
      return
    end
    meta.await_paid_topup = nil
    meta.await_paid_topup_option_id = nil
    game:dispatch_action({
      type = "choice_select",
      choice_id = pending.id,
      option_id = option_id,
      actor_role_id = player.id,
    })
  end)
  ctx.registered_role_ids[role_id] = true
end

local function _bind_player_role(ctx, player)
  local role = _resolve_role(player)
  if not role then
    return
  end
  if not role.get_roleid then
    return
  end
  local ok, role_id = pcall(role.get_roleid)
  if not ok or not role_id then
    return
  end
  ctx.player_id_by_role_id[role_id] = player.id
  _register_purchase_event(ctx, role_id)
end

function bridge.is_managed_currency(game, currency)
  if paid_goods_cfg.enabled ~= true then
    return false
  end
  local ctx = _resolve_context(game)
  return ctx.resolved_by_currency[currency] ~= nil
end

function bridge.is_paid_currency(currency)
  if paid_goods_cfg.enabled ~= true then
    return false
  end
  local key = currency and tostring(currency) or nil
  if not key then
    return false
  end
  local currencies = paid_goods_cfg.currencies or {}
  return currencies[key] ~= nil
end

function bridge.is_channel_enforced()
  return _is_release_build()
end

function bridge.is_currency_channel_ready(game, currency)
  if not bridge.is_paid_currency(currency) then
    return true
  end
  return bridge.is_managed_currency(game, currency)
end

function bridge.unavailable_reason(game, currency)
  local ctx = _resolve_context(game)
  local status = ctx.status_by_currency and ctx.status_by_currency[currency] or nil
  if status and status.state == "unavailable" then
    return status.reason or "mapping_missing"
  end
  return nil
end

function bridge.sync_player_currency(game, player, currency)
  local ctx = _resolve_context(game)
  local resolved = ctx.resolved_by_currency[currency]
  if not resolved then
    return false
  end
  local role = _resolve_role(player)
  if not role or not role.get_commodity_count then
    return false
  end
  local ok, count = pcall(role.get_commodity_count, resolved.commodity_id)
  if not ok or not number_utils.is_numeric(count) then
    return false
  end
  local balance = count * resolved.unit_value
  game:set_player_balance(player, currency, balance)
  return true
end

function bridge.open_purchase_panel(game, player, currency)
  local ctx = _resolve_context(game)
  local resolved = ctx.resolved_by_currency[currency]
  if not resolved then
    logger.warn("open purchase panel failed: unresolved currency mapping", tostring(currency))
    return false
  end
  local role = _resolve_role(player)
  if not role or not role.show_goods_purchase_panel then
    logger.warn("open purchase panel failed: role api missing show_goods_purchase_panel", tostring(currency))
    return false
  end
  local show_time = paid_goods_cfg.panel_show_time or 10.0
  local ok = pcall(role.show_goods_purchase_panel, resolved.goods_id, show_time)
  if not ok then
    logger.warn(
      "open purchase panel failed: call error",
      "currency=" .. tostring(currency),
      "goods_id=" .. tostring(resolved.goods_id)
    )
  end
  return ok
end

function bridge.consume_currency(game, player, currency, amount)
  local ctx = _resolve_context(game)
  local resolved = ctx.resolved_by_currency[currency]
  if not resolved then
    return false
  end
  if amount <= 0 then
    return true
  end

  local unit_value = resolved.unit_value
  local raw_need = amount / unit_value
  local need_count = math.floor(raw_need + 0.00001)
  if math.abs(raw_need - need_count) > 0.00001 then
    logger.warn("paid goods amount not aligned:", tostring(currency), tostring(amount), tostring(unit_value))
    return false
  end

  local role = _resolve_role(player)
  if not role or not role.get_commodity_count or not role.consume_commodity then
    return false
  end

  local ok_count, has_count = pcall(role.get_commodity_count, resolved.commodity_id)
  if not ok_count or not number_utils.is_numeric(has_count) or has_count < need_count then
    bridge.sync_player_currency(game, player, currency)
    return false
  end

  local ok_consume = pcall(role.consume_commodity, resolved.commodity_id, need_count)
  if not ok_consume then
    bridge.sync_player_currency(game, player, currency)
    return false
  end

  bridge.sync_player_currency(game, player, currency)
  return true
end

function bridge.setup_for_game(game)
  local ctx = _resolve_context(game)
  ctx.game = game
  ctx.player_id_by_role_id = {}
  _resolve_goods_mapping(ctx)
  if not game or not game.players then
    return
  end
  for _, player in ipairs(game.players) do
    _bind_player_role(ctx, player)
    _sync_all_managed_currencies(ctx, game, player)
  end
end

return bridge
