local paid_goods_cfg = require("src.game.systems.commerce.config.RuntimePaidGoods")
local logger = require("src.core.Logger")
local number_utils = require("src.core.NumberUtils")
local runtime_ports = require("src.core.RuntimePorts")

local bridge = {}

local game_context_field = "__paid_currency_bridge_ctx"

local function _new_context(game)
  return {
    game = game,
    resolved_by_currency = {},
    status_by_currency = {},
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

local function _warn_mapping_missing_once(ctx, currency, reason, cfg_entry)
  local warned = ctx.mapping_warned_by_currency or {}
  ctx.mapping_warned_by_currency = warned
  if warned[currency] then
    return
  end
  warned[currency] = true
  logger.warn(
    "paid currency mapping unavailable:",
    tostring(currency),
    "reason=" .. tostring(reason or "mapping_missing"),
    "commodity_id=" .. tostring(cfg_entry and cfg_entry.commodity_id or nil)
  )
end

local function _build_resolved_entry(commodity_id, unit_value)
  return {
    commodity_id = commodity_id,
    unit_value = unit_value,
    source = "commodity",
  }
end

local function _resolve_currency_entry(currency, cfg_entry)
  local unit_value = cfg_entry and cfg_entry.unit_value or 1
  if not number_utils.is_numeric(unit_value) or unit_value <= 0 then
    logger.warn("paid currency invalid unit_value:", tostring(currency), tostring(unit_value))
    return nil, "invalid_unit_value"
  end

  local commodity_id = number_utils.to_integer(cfg_entry and cfg_entry.commodity_id or nil)
  if commodity_id == nil or commodity_id <= 0 then
    return nil, "invalid_commodity_id"
  end

  return _build_resolved_entry(commodity_id, unit_value), nil
end

local function _resolve_currency_mapping(ctx)
  ctx.resolved_by_currency = {}
  ctx.status_by_currency = {}
  ctx.mapping_warned_by_currency = {}
  if paid_goods_cfg.enabled ~= true then
    return
  end

  local currencies = paid_goods_cfg.currencies or {}
  for currency, cfg_entry in pairs(currencies) do
    local resolved, reason = _resolve_currency_entry(currency, cfg_entry)
    if resolved then
      ctx.resolved_by_currency[currency] = resolved
      ctx.status_by_currency[currency] = {
        state = "ready",
        source = resolved.source,
      }
    else
      ctx.status_by_currency[currency] = {
        state = "unavailable",
        reason = reason or "mapping_missing",
      }
      _warn_mapping_missing_once(ctx, currency, reason or "mapping_missing", cfg_entry)
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

local function _log_release_unavailable_channels(ctx)
  if not _is_release_build() then
    return
  end
  for currency, status in pairs(ctx.status_by_currency or {}) do
    if status and status.state == "unavailable" then
      logger.warn(
        "paid channel startup unavailable:",
        "currency=" .. tostring(currency),
        "reason=" .. tostring(status.reason or "mapping_missing"),
        "release=true"
      )
    end
  end
end

local function _probe_currency_query_ready(game, resolved)
  if not (game and game.players and resolved) then
    return false
  end
  for _, player in ipairs(game.players) do
    local role = _resolve_role(player)
    if role and role.get_commodity_count then
      local ok, count = pcall(role.get_commodity_count, resolved.commodity_id)
      if ok and number_utils.is_numeric(count) then
        return true
      end
    end
  end
  return false
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
    logger.warn("paid currency amount not aligned:", tostring(currency), tostring(amount), tostring(unit_value))
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
  _resolve_currency_mapping(ctx)
  for currency, resolved in pairs(ctx.resolved_by_currency) do
    if not _probe_currency_query_ready(game, resolved) then
      ctx.resolved_by_currency[currency] = nil
      ctx.status_by_currency[currency] = {
        state = "unavailable",
        reason = "commodity_query_unavailable",
      }
      _warn_mapping_missing_once(ctx, currency, "commodity_query_unavailable", {
        commodity_id = resolved.commodity_id,
      })
    end
  end
  _log_release_unavailable_channels(ctx)
  if not game or not game.players then
    return
  end
  for _, player in ipairs(game.players) do
    for currency in pairs(ctx.resolved_by_currency) do
      bridge.sync_player_currency(game, player, currency)
    end
  end
end

return bridge
