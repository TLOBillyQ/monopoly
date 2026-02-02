local MarketCfg = require("Config.Generated.Market")
local ItemsCfg = require("Config.Generated.Items")
local VehiclesCfg = require("Config.Generated.Vehicles")
local Logger = require("Components.Logger")
local Inventory = require("Manager.ItemManager.ItemInventory")
local Agent = require("Manager.GameManager.Agent")
local LandChoiceSpecs = require("Manager.LandManager.LandChoiceSpecs")
local MonopolyEvent = require("Globals.MonopolyEvents")
local MarketManager = {}

local function _EmitEvent(kind, payload)
  assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
  TriggerCustomEvent(kind, payload or {})
end

local items_by_id = {}
for _, cfg in ipairs(ItemsCfg) do
  items_by_id[cfg.id] = cfg
end

local vehicles_by_id = {}
for _, cfg in ipairs(VehiclesCfg) do
  vehicles_by_id[cfg.id] = cfg
end

local entries_by_id = {}
for _, entry in ipairs(MarketCfg) do
  entries_by_id[entry.product_id] = entry
end

local function _EntryName(entry)
  if entry.kind == "vehicle" then
    local cfg = vehicles_by_id[entry.product_id]
    if cfg then
      return cfg.name
    end
    if entry.name then
      return entry.name
    end
    return tostring(entry.product_id)
  end
  local cfg = items_by_id[entry.product_id]
  if cfg then
    return cfg.name
  end
  if entry.name then
    return entry.name
  end
  return tostring(entry.product_id)
end

local function _VehicleName(seat_id)
  if seat_id then
    local cfg = vehicles_by_id[seat_id]
    if cfg then
      return cfg.name
    end
    return tostring(seat_id)
  end
  return "无"
end

local function _EntryPrice(entry)
  return entry.price or 0
end

local function _EntryCurrency(entry)
  local currency = entry.currency
  if currency and currency ~= "" then
    return currency
  end
  return "金币"
end

local function _RemainingGlobalLimit(game, product_id)
  assert(game ~= nil, "missing game")
  assert(game.store ~= nil, "missing game.store")
  assert(product_id ~= nil, "missing product_id")
  return game.store:Get({ "market", "global_limits", product_id })
end

local function _CanBuyEntry(game, player, entry)
  if entry.kind == "item" and Inventory.IsFull(player) then
    return false
  end
  local remaining = _RemainingGlobalLimit(game, entry.product_id)
  if remaining <= 0 then
    return false
  end
  local price = _EntryPrice(entry)
  return player:Balance(_EntryCurrency(entry)) >= price
end

function MarketManager.ListBuyable(player, game)
  local list = {}
  for _, entry in ipairs(MarketCfg) do
    if _CanBuyEntry(game, player, entry) then
      table.insert(list, entry)
    end
  end
  table.sort(list, function(a, b)
    return (a.order or 0) < (b.order or 0)
  end)
  return list
end

function MarketManager.BuildChoiceSpec(player, game)
  local options = {}
  local body_lines = {}
  for _, entry in ipairs(MarketManager.ListBuyable(player, game)) do
    local name = _EntryName(entry)
    local price = _EntryPrice(entry)
    local currency = _EntryCurrency(entry)
    local label = name .. " - " .. price .. " " .. currency
    table.insert(body_lines, label)
    table.insert(options, { id = entry.product_id, label = label })
  end

  if #options == 0 then
    return nil, { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 暂无可购买商品" } }
  end

  return {
    kind = "market_buy",
    title = "黑市",
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "不买",
    meta = { player_id = player.id },
  }
end

local function _ConsumeGlobalLimit(game, product_id)
  assert(game ~= nil, "missing game")
  assert(game.store ~= nil, "missing game.store")
  assert(product_id ~= nil, "missing product_id")
  local remaining = assert(_RemainingGlobalLimit(game, product_id), "missing global limit")
  local next_remaining = remaining - 1
  if next_remaining < 0 then
    next_remaining = 0
  end
  game.store:Set({ "market", "global_limits", product_id }, next_remaining)
end

function MarketManager.BuyWithOpts(game, player, product_id, opts)
  opts = opts or {}
  if type(product_id) ~= "number" or product_id <= 0 then
    Logger.Warn("invalid market product id:", tostring(product_id))
    return false
  end
  local entry = entries_by_id[product_id]
  assert(entry ~= nil, "missing market entry: " .. tostring(product_id))

  local remaining = _RemainingGlobalLimit(game, product_id)
  if remaining <= 0 then
    _EmitEvent(MonopolyEvent.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "sold_out",
      popup = { title = "黑市", body = player.name .. " 该商品已售罄" },
    })
    return { ok = false }
  end

  local price = _EntryPrice(entry)
  local currency = _EntryCurrency(entry)
  if player:Balance(currency) < price then
    _EmitEvent(MonopolyEvent.market.buy_failed, {
      player = player,
      entry = entry,
      reason = "insufficient_balance",
      popup = { title = "黑市", body = player.name .. " 余额不足" },
    })
    return { ok = false }
  end

  if entry.kind == "item" then
    if Inventory.IsFull(player) then
      _EmitEvent(MonopolyEvent.market.buy_failed, {
        player = player,
        entry = entry,
        reason = "inventory_full",
        popup = { title = "黑市", body = player.name .. " 卡槽已满" },
      })
      return { ok = false }
    end
    player:DeductBalance(currency, price)
    Inventory.Give(player, product_id)
    _ConsumeGlobalLimit(game, product_id)
    _EmitEvent(MonopolyEvent.market.bought_item, {
      player = player,
      entry = entry,
      price = price,
      currency = currency,
      text = player.name .. " 在黑市购买 " .. _EntryName(entry) .. " 花费 " .. price .. " " .. currency,
    })
    return true
  end

  if player.seat_id and not opts.skip_vehicle_prompt then
    local current_name = _VehicleName(player.seat_id)
    local next_name = _EntryName(entry)
    return {
      ok = false,
      intent = {
        kind = "need_choice",
        choice_spec = LandChoiceSpecs.BuildUseSkip(
          "market_vehicle_replace",
          "是否更换座驾",
          {
            "当前座驾：" .. current_name,
            "新座驾：" .. next_name,
            "价格：" .. tostring(price) .. " " .. currency,
          },
          { player_id = player.id, product_id = entry.product_id },
          { use = "更换", skip = "算了" }
        ),
      },
    }
  end

  player:DeductBalance(currency, price)

  assert(game ~= nil, "missing game")
  assert(game.SetPlayerSeat ~= nil, "missing game.SetPlayerSeat")
  game:SetPlayerSeat(player, product_id)
  _ConsumeGlobalLimit(game, product_id)
  _EmitEvent(MonopolyEvent.market.bought_vehicle, {
    player = player,
    entry = entry,
    price = price,
    currency = currency,
    text = player.name .. " 在黑市购买座驾 " .. _EntryName(entry) .. " 花费 " .. price .. " " .. currency,
  })
  return true
end

function MarketManager.AutoBuy(game, player)
  if Agent.IsAutoPlayer(player) then
    _EmitEvent(MonopolyEvent.market.auto_skip, {
      player = player,
      text = player.name .. " (AI) 到达黑市，选择不购买",
    })
    return
  end

  local list = MarketManager.ListBuyable(player, game)
  table.sort(list, function(a, b)
    return (_EntryPrice(a) or 0) < (_EntryPrice(b) or 0)
  end)
  if #list > 0 then
    local chosen = nil
    for _, entry in ipairs(list) do
      if entry.kind ~= "vehicle" or not player.seat_id then
        chosen = entry
        break
      end
    end
    if chosen then
      MarketManager.BuyWithOpts(game, player, chosen.product_id, { skip_vehicle_prompt = true })
    end
  end
end

return MarketManager


