local support = require("TestSupport")
local _new_game = support.new_game

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

local function _test_ai_skips_auto_buy_at_market()
  local market = require("game.shop")
  local g = _new_game()
  local ai_player = g.players[2]
  assert(ai_player.is_ai, "player 2 should be AI")

  g:set_player_cash(ai_player, 1000)

  local before_cash = ai_player.cash
  market.auto_buy(g, ai_player)

  assert(ai_player.cash == before_cash, "AI should not spend money on auto_buy")
end

local function _test_market_full_inventory_blocks_items()
  local market = require("game.shop")
  local g = _new_game()
  local p = g:current_player()
  g:set_player_cash(p, 999999)
  for _ = 1, p.inventory.max_slots do
    p.inventory:add({ id = 2001 })
  end

  local list = market.list_buyable(p, g)
  for _, entry in ipairs(list) do
    assert(entry.kind ~= "item", "item should be excluded when inventory full")
  end
end

local function _test_market_global_limit()
  local market = require("game.shop")
  local market_cfg = require("cfg.Generated.Market")
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

  local res = market.buy_with_opts(g, p, entry.product_id, nil)
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  assert(ok, "first purchase should succeed")

  local list = market.list_buyable(p, g)
  for _, item in ipairs(list) do
    assert(item.product_id ~= entry.product_id, "sold out item should be excluded from list")
  end

  local spec = market.build_choice_spec(p, g)
  if spec and spec.options then
    for _, option in ipairs(spec.options) do
      assert(option.id ~= entry.product_id, "sold out item should be excluded from choice")
    end
  end
end

local function _test_market_disabled_products_hidden()
  local market = require("game.shop")
  local g = _new_game()
  local p = g:current_player()
  g:set_player_balance(p, "金豆", 999999)

  local blocked_product_ids = { 4007, 4008, 4009 }

  local list = market.list_buyable(p, g)
  for _, product_id in ipairs(blocked_product_ids) do
    assert(not _contains_product(list, product_id), "disabled product should be hidden: " .. tostring(product_id))
  end

  local spec = market.build_choice_spec(p, g)
  if spec and spec.options then
    for _, product_id in ipairs(blocked_product_ids) do
      assert(not _contains_option(spec.options, product_id), "disabled option should be hidden: " .. tostring(product_id))
    end
  end
end

local function _test_buy_disabled_market_product_rejected()
  local market = require("game.shop")
  local g = _new_game()
  local p = g:current_player()
  g:set_player_balance(p, "金豆", 999999)

  local blocked_product_id = 4007
  local before_balance = g:player_balance(p, "金豆")
  local before_seat_id = p.seat_id

  local res = market.buy_with_opts(g, p, blocked_product_id, nil)
  assert(type(res) == "table" and res.ok == false, "disabled market product should be rejected")
  assert(g:player_balance(p, "金豆") == before_balance, "balance should not change when buying disabled product")
  assert(p.seat_id == before_seat_id, "seat should not change when buying disabled product")
end

local function _test_market_vehicle_hidden_when_feature_disabled()
  local market = require("game.shop")
  local g = _new_game()
  local p = g:current_player()
  g:set_player_balance(p, "金豆", 999999)

  local vehicle_product_id = 4001
  local list = market.list_buyable(p, g)
  assert(not _contains_product(list, vehicle_product_id), "vehicle should be hidden when feature disabled")

  local spec = market.build_choice_spec(p, g)
  if spec and spec.options then
    assert(not _contains_option(spec.options, vehicle_product_id), "vehicle option should be hidden when feature disabled")
  end
end

local function _test_buy_vehicle_rejected_when_feature_disabled()
  local market = require("game.shop")
  local g = _new_game()
  local p = g:current_player()
  g:set_player_balance(p, "金豆", 999999)

  local vehicle_product_id = 4001
  local before_balance = g:player_balance(p, "金豆")
  local before_seat_id = p.seat_id
  local res = market.buy_with_opts(g, p, vehicle_product_id, nil)

  assert(type(res) == "table" and res.ok == false, "vehicle buy should be rejected when feature disabled")
  assert(g:player_balance(p, "金豆") == before_balance, "balance should not change when vehicle buy is rejected")
  assert(p.seat_id == before_seat_id, "seat should not change when vehicle buy is rejected")
end

return {
  _test_ai_skips_auto_buy_at_market,
  _test_market_full_inventory_blocks_items,
  _test_market_global_limit,
  _test_market_disabled_products_hidden,
  _test_buy_disabled_market_product_rejected,
  _test_market_vehicle_hidden_when_feature_disabled,
  _test_buy_vehicle_rejected_when_feature_disabled,
}
