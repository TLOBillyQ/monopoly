local support = require("TestSupport")
local _new_game = support.new_game
local market_cfg = require("Config.Generated.Market")

local function _contains_product(list, product_id)
  for _, entry in ipairs(list) do
    if entry.product_id == product_id then
      return true
    end
  end
  return false
end

local function _contains_option(options, product_id)
  for _, option in ipairs(options) do
    if option.id == product_id then
      return true
    end
  end
  return false
end

local function _reload_market_service()
  package.loaded["src.game.systems.market.MarketService"] = nil
  package.loaded["src.game.systems.market.service.Context"] = nil
  package.loaded["src.game.systems.market.service.Eligibility"] = nil
  package.loaded["src.game.systems.market.service.Purchase"] = nil
  package.loaded["src.game.systems.market.service.Auto"] = nil
  package.loaded["src.game.systems.market.service.Choice"] = nil
  return require("src.game.systems.market.MarketService")
end

local function _test_ai_skips_auto_buy_at_market()
  local market_service = require("src.game.systems.market.MarketService")
  local g = _new_game()
  local ai_player = g.players[2]
  assert(ai_player.is_ai, "player 2 should be AI")

  g:set_player_cash(ai_player, 1000)

  local before_cash = ai_player.cash
  market_service.auto.execute(g, ai_player)

  assert(ai_player.cash == before_cash, "AI should not spend money on auto_buy")
end

local function _test_market_full_inventory_blocks_items()
  local market_service = require("src.game.systems.market.MarketService")
  local g = _new_game()
  local p = g:current_player()
  g:set_player_cash(p, 999999)
  for _ = 1, p.inventory.max_slots do
    p.inventory:add({ id = 2001 })
  end

  local list = market_service.query.list_available(p, g)
  for _, entry in ipairs(list) do
    assert(entry.kind ~= "item", "item should be excluded when inventory full")
  end
end

local function _test_market_global_limit()
  local market_service = require("src.game.systems.market.MarketService")
  local g = _new_game()
  local p = g:current_player()
  local entry = nil
  for _, cfg in ipairs(market_cfg) do
    if cfg.kind == "item" and cfg.currency == "金币" then
      entry = cfg
      break
    end
  end
  assert(entry, "should find a market item with coin currency")
  g:set_player_cash(p, (entry.price or 0) + 1000)
  g.market_limits[entry.product_id] = 1

  local res = market_service.purchase.execute(g, p, entry.product_id, nil)
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  assert(ok, "first purchase should succeed")

  local list = market_service.query.list_available(p, g)
  for _, item in ipairs(list) do
    assert(item.product_id ~= entry.product_id, "sold out item should be excluded from list")
  end

  local spec = market_service.choice.build(p, g)
  if spec and spec.options then
    for _, option in ipairs(spec.options) do
      assert(option.id ~= entry.product_id, "sold out item should be excluded from choice")
    end
  end
end

local function _test_skin_entry_can_buy_but_no_effect()
  local injected = {
    order = -1,
    product_id = 5999,
    name = "测试皮肤",
    page = "皮肤商店",
    kind = "skin",
    currency = "金币",
    price = 1,
    limit = 1,
    market_enabled = true,
  }
  market_cfg[#market_cfg + 1] = injected
  local ok, err = pcall(function()
    local market_service = _reload_market_service()
    local g = _new_game()
    local p = g:current_player()
    g:set_player_cash(p, 999999)

    local list = market_service.query.list_available(p, g)
    assert(_contains_product(list, injected.product_id), "skin entry should be available when market_enabled=true")

    local before_count = p.inventory:count()
    local before_balance = g:player_balance(p, "金币")
    local before_seat_id = p.seat_id
    local before_limit = g.market_limits[injected.product_id]
    local res = market_service.purchase.execute(g, p, injected.product_id, nil)
    local purchase_ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
    assert(purchase_ok == true, "skin entry purchase should succeed as placeholder flow")
    assert(g:player_balance(p, "金币") == before_balance - (injected.price or 0), "balance should be charged for skin purchase")
    assert(g.market_limits[injected.product_id] == before_limit - 1, "skin purchase should consume global limit")
    assert(p.inventory:count() == before_count, "skin purchase should not change inventory")
    assert(p.seat_id == before_seat_id, "skin purchase should not change seat")
  end)
  market_cfg[#market_cfg] = nil
  _reload_market_service()
  if not ok then
    error(err)
  end
end

local function _test_market_disabled_products_hidden()
  local market_service = require("src.game.systems.market.MarketService")
  local g = _new_game()
  local p = g:current_player()
  g:set_player_balance(p, "金豆", 999999)

  local blocked_product_ids = { 4007, 4008, 4009 }

  local list = market_service.query.list_available(p, g)
  for _, product_id in ipairs(blocked_product_ids) do
    assert(not _contains_product(list, product_id), "disabled product should be hidden: " .. tostring(product_id))
  end

  local spec = market_service.choice.build(p, g)
  if spec and spec.options then
    for _, product_id in ipairs(blocked_product_ids) do
      assert(not _contains_option(spec.options, product_id), "disabled option should be hidden: " .. tostring(product_id))
    end
  end
end

local function _test_buy_disabled_market_product_rejected()
  local market_service = require("src.game.systems.market.MarketService")
  local g = _new_game()
  local p = g:current_player()
  g:set_player_balance(p, "金豆", 999999)

  local blocked_product_id = 4007
  local before_balance = g:player_balance(p, "金豆")
  local before_seat_id = p.seat_id

  local res = market_service.purchase.execute(g, p, blocked_product_id, nil)
  assert(type(res) == "table" and res.ok == false, "disabled market product should be rejected")
  assert(g:player_balance(p, "金豆") == before_balance, "balance should not change when buying disabled product")
  assert(p.seat_id == before_seat_id, "seat should not change when buying disabled product")
end

local function _test_market_vehicle_hidden_when_feature_disabled()
  local market_service = require("src.game.systems.market.MarketService")
  local g = _new_game()
  local p = g:current_player()
  g:set_player_balance(p, "金豆", 999999)

  local vehicle_product_id = 4001
  local list = market_service.query.list_available(p, g)
  assert(not _contains_product(list, vehicle_product_id), "vehicle should be hidden when feature disabled")

  local spec = market_service.choice.build(p, g)
  if spec and spec.options then
    assert(not _contains_option(spec.options, vehicle_product_id), "vehicle option should be hidden when feature disabled")
  end
end

local function _test_buy_vehicle_rejected_when_feature_disabled()
  local market_service = require("src.game.systems.market.MarketService")
  local g = _new_game()
  local p = g:current_player()
  g:set_player_balance(p, "金豆", 999999)

  local vehicle_product_id = 4001
  local before_balance = g:player_balance(p, "金豆")
  local before_seat_id = p.seat_id
  local res = market_service.purchase.execute(g, p, vehicle_product_id, nil)

  assert(type(res) == "table" and res.ok == false, "vehicle buy should be rejected when feature disabled")
  assert(g:player_balance(p, "金豆") == before_balance, "balance should not change when vehicle buy is rejected")
  assert(p.seat_id == before_seat_id, "seat should not change when vehicle buy is rejected")
end

return {
  name = "market",
  tests = {
    { name = "ai_skips_auto_buy_at_market", run = _test_ai_skips_auto_buy_at_market },
    { name = "market_full_inventory_blocks_items", run = _test_market_full_inventory_blocks_items },
    { name = "market_global_limit", run = _test_market_global_limit },
    { name = "market_disabled_products_hidden", run = _test_market_disabled_products_hidden },
    { name = "buy_disabled_market_product_rejected", run = _test_buy_disabled_market_product_rejected },
    { name = "skin_entry_can_buy_but_no_effect", run = _test_skin_entry_can_buy_but_no_effect },
    { name = "market_vehicle_hidden_when_feature_disabled", run = _test_market_vehicle_hidden_when_feature_disabled },
    { name = "buy_vehicle_rejected_when_feature_disabled", run = _test_buy_vehicle_rejected_when_feature_disabled },
  },
}
