local paid_goods_cfg = require("Config.RuntimePaidGoods")
local logger = require("src.core.Logger")

local bridge = {}

local game_context_field = "__paid_currency_bridge_ctx"

local function _new_context(game)
  return {
    game = game,
    resolved_by_currency = {},
    player_id_by_role_id = {},
    registered_role_ids = {},
  }
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

local function _resolve_currency_entry(goods_lookup, currency, cfg_entry)
  local unit_value = cfg_entry and cfg_entry.unit_value or 1
  if type(unit_value) ~= "number" or unit_value <= 0 then
    logger.warn("paid goods invalid unit_value:", tostring(currency), tostring(unit_value))
    return nil
  end

  for _, name in ipairs(_resolve_goods_names(cfg_entry)) do
    local goods = goods_lookup[name]
    local commodity_infos = goods and goods.commodity_infos or nil
    local first = commodity_infos and commodity_infos[1] or nil
    local commodity_id = first and first[1] or nil
    if goods and goods.goods_id and commodity_id then
      return {
        goods_id = goods.goods_id,
        commodity_id = commodity_id,
        unit_value = unit_value,
        goods_name = name,
      }
    end
  end

  logger.warn("paid goods mapping missing:", tostring(currency))
  return nil
end

local function _resolve_goods_mapping(ctx)
  ctx.resolved_by_currency = {}
  if paid_goods_cfg.enabled ~= true then
    return
  end

  local goods_lookup = _goods_by_name(_list_goods())
  local currencies = paid_goods_cfg.currencies or {}
  for currency, cfg_entry in pairs(currencies) do
    local resolved = _resolve_currency_entry(goods_lookup, currency, cfg_entry)
    if resolved then
      ctx.resolved_by_currency[currency] = resolved
    end
  end
end

local function _resolve_role(player)
  if not (GameAPI and GameAPI.get_role) then
    return nil
  end
  if not player or not player.id then
    return nil
  end
  local ok, role = pcall(GameAPI.get_role, player.id)
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
    local player = player_id and game.players[player_id] or nil
    if not player then
      return
    end
    _sync_all_managed_currencies(ctx, game, player)
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
  if not ok or type(count) ~= "number" then
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
    return false
  end
  local role = _resolve_role(player)
  if not role or not role.show_goods_purchase_panel then
    return false
  end
  local show_time = paid_goods_cfg.panel_show_time or 10.0
  local ok = pcall(role.show_goods_purchase_panel, resolved.goods_id, show_time)
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
  if not ok_count or type(has_count) ~= "number" or has_count < need_count then
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
