local support = require("TestSupport")
local _new_game = support.new_game

local function _test_ai_skips_auto_buy_at_market()
  local market = require("src.game.market.Market")
  local g = _new_game()
  local ai_player = g.players[2]
  assert(ai_player.is_ai, "player 2 should be AI")

  g:set_player_cash(ai_player, 1000)

  local before_cash = ai_player.cash
  market.auto_buy(g, ai_player)

  assert(ai_player.cash == before_cash, "AI should not spend money on auto_buy")
end

local function _test_market_full_inventory_blocks_items()
  local market = require("src.game.market.Market")
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
  local market = require("src.game.market.Market")
  local market_cfg = require("Config.Generated.Market")
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

return {
  _test_ai_skips_auto_buy_at_market,
  _test_market_full_inventory_blocks_items,
  _test_market_global_limit,
}
