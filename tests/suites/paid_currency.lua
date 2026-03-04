local support = require("TestSupport")
local _new_game = support.new_game
local _with_patches = support.with_patches
local runtime_ports = require("src.core.RuntimePorts")

local function _reload_bridge()
  package.loaded["src.game.systems.commerce.PaidCurrencyBridge"] = nil
  return require("src.game.systems.commerce.PaidCurrencyBridge")
end

local function _reload_market()
  package.loaded["src.game.systems.market.MarketService"] = nil
  return require("src.game.systems.market.MarketService")
end

local function _build_fake_env(game, opts)
  opts = opts or {}
  local jindou_commodity = opts.jindou_commodity or 9001
  local leyuanbi_commodity = opts.leyuanbi_commodity or 9002
  local jindou_count = opts.jindou_count or 0
  local leyuanbi_count = opts.leyuanbi_count or 0
  local buy_calls = {}
  local consume_calls = {}
  local handlers = {}
  local role_by_player_id = {}

  local function _new_role(role_id)
    local role = {
      role_id = role_id,
      commodity_count = {
        [jindou_commodity] = jindou_count,
        [leyuanbi_commodity] = leyuanbi_count,
      },
    }
    role.get_roleid = function()
      return role.role_id
    end
    role.get_commodity_count = function(commodity_id)
      return role.commodity_count[commodity_id] or 0
    end
    role.consume_commodity = function(commodity_id, count)
      table.insert(consume_calls, { role_id = role.role_id, commodity_id = commodity_id, count = count })
      role.commodity_count[commodity_id] = (role.commodity_count[commodity_id] or 0) - count
    end
    role.show_goods_purchase_panel = function(goods_id, show_time)
      table.insert(buy_calls, { role_id = role.role_id, goods_id = goods_id, show_time = show_time })
    end
    return role
  end

  for _, player in ipairs(game.players) do
    role_by_player_id[player.id] = _new_role(player.id)
  end

  local goods_list = {
    {
      name = "金豆",
      goods_id = "goods_jindou",
      commodity_infos = { { jindou_commodity, 1 } },
    },
    {
      name = "乐园币",
      goods_id = "goods_leyuanbi",
      commodity_infos = { { leyuanbi_commodity, 1 } },
    },
  }

  local patch_list = {
    {
      key = "GameAPI",
      value = {
        random_int = GameAPI and GameAPI.random_int or function(min, max)
          return min <= max and min or max
        end,
        get_goods_list = function()
          return goods_list
        end,
      },
    },
    {
      target = runtime_ports,
      key = "resolve_role",
      value = function(role_id)
        return role_by_player_id[role_id]
      end,
    },
    { key = "EVENT", value = { SPEC_ROLE_PURCHASE_GOODS = "SPEC_ROLE_PURCHASE_GOODS" } },
    {
      key = "RegisterTriggerEvent",
      value = function(args, callback)
        local role_id = args and args[2] or nil
        handlers[role_id] = callback
      end,
    },
  }

  return {
    patch_list = patch_list,
    role_by_player_id = role_by_player_id,
    buy_calls = buy_calls,
    consume_calls = consume_calls,
    handlers = handlers,
    jindou_commodity = jindou_commodity,
    leyuanbi_commodity = leyuanbi_commodity,
  }
end

local function _test_paid_bridge_sync_balance_from_commodity()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game, { jindou_count = 7, leyuanbi_count = 3 })
  _with_patches(env.patch_list, function()
    local bridge = _reload_bridge()
    bridge.setup_for_game(game)
    assert(game:player_balance(p, "金豆") == 7, "jindou balance should sync from commodity")
    assert(game:player_balance(p, "乐园币") == 3, "leyuanbi balance should sync from commodity")
    local role = env.role_by_player_id[p.id]
    role.commodity_count[env.jindou_commodity] = 11
    bridge.sync_player_currency(game, p, "金豆")
    assert(game:player_balance(p, "金豆") == 11, "sync should refresh jindou balance")
  end)
end

local function _test_market_buy_managed_currency_consumes_commodity()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game, { jindou_count = 10 })
  _with_patches(env.patch_list, function()
    local bridge = _reload_bridge()
    local market = _reload_market()
    bridge.setup_for_game(game)
    local ok = market.purchase.execute(game, p, 2009, nil)
    assert(ok == true, "managed currency purchase should succeed")
    assert(#env.consume_calls == 1, "managed currency purchase should consume commodity")
    assert(env.consume_calls[1].count == 5, "consume count should match item price")
    assert(game:player_balance(p, "金豆") == 5, "jindou balance should be reduced after purchase")
  end)
end

local function _test_market_insufficient_managed_currency_opens_panel()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game, { jindou_count = 1 })
  _with_patches(env.patch_list, function()
    local bridge = _reload_bridge()
    local market = _reload_market()
    bridge.setup_for_game(game)
    local result = market.purchase.execute(game, p, 2009, nil)
    assert(type(result) == "table" and result.ok == false, "insufficient managed currency should fail")
    assert(#env.consume_calls == 0, "insufficient balance should not consume commodity")
    assert(#env.buy_calls == 1, "insufficient balance should open purchase panel")
    assert(env.buy_calls[1].goods_id == "goods_jindou", "purchase panel should target configured jindou goods")
  end)
end

local function _test_purchase_event_syncs_balance()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game, { jindou_count = 2 })
  _with_patches(env.patch_list, function()
    local bridge = _reload_bridge()
    bridge.setup_for_game(game)
    local role = env.role_by_player_id[p.id]
    role.commodity_count[env.jindou_commodity] = 9
    local cb = env.handlers[p.id]
    assert(type(cb) == "function", "purchase event callback should be registered for role")
    cb(nil, nil, { role = role, goods_id = "goods_jindou" })
    assert(game:player_balance(p, "金豆") == 9, "purchase event should refresh jindou balance")
  end)
end

local function _test_bridge_isolates_context_between_games()
  local g1 = _new_game()
  local g2 = _new_game()
  g2.players[1].id = 101
  g2.players[2].id = 102

  local roles = {
    [1] = {
      role_id = 1,
      commodity_count = { [9001] = 6, [9002] = 0 },
      get_roleid = nil,
      get_commodity_count = nil,
      consume_commodity = nil,
      show_goods_purchase_panel = function() end,
    },
    [101] = {
      role_id = 101,
      commodity_count = { [9001] = 20, [9002] = 0 },
      get_roleid = nil,
      get_commodity_count = nil,
      consume_commodity = nil,
      show_goods_purchase_panel = function() end,
    },
  }
  roles[1].get_roleid = function() return roles[1].role_id end
  roles[1].get_commodity_count = function(commodity_id) return roles[1].commodity_count[commodity_id] or 0 end
  roles[1].consume_commodity = function(commodity_id, count)
    roles[1].commodity_count[commodity_id] = (roles[1].commodity_count[commodity_id] or 0) - count
  end
  roles[101].get_roleid = function() return roles[101].role_id end
  roles[101].get_commodity_count = function(commodity_id) return roles[101].commodity_count[commodity_id] or 0 end
  roles[101].consume_commodity = function(commodity_id, count)
    roles[101].commodity_count[commodity_id] = (roles[101].commodity_count[commodity_id] or 0) - count
  end

  _with_patches({
    { key = "GameAPI", value = {
      random_int = function(min) return min end,
      get_goods_list = function()
        return {
          { name = "金豆", goods_id = "goods_jindou", commodity_infos = { { 9001, 1 } } },
          { name = "乐园币", goods_id = "goods_leyuanbi", commodity_infos = { { 9002, 1 } } },
        }
      end,
    } },
    { target = runtime_ports, key = "resolve_role", value = function(role_id)
      return roles[role_id]
    end },
    { key = "EVENT", value = { SPEC_ROLE_PURCHASE_GOODS = "SPEC_ROLE_PURCHASE_GOODS" } },
    { key = "RegisterTriggerEvent", value = function() end },
  }, function()
    local bridge = _reload_bridge()
    bridge.setup_for_game(g1)
    bridge.setup_for_game(g2)

    assert(g1:player_balance(g1.players[1], "金豆") == 6, "game1 initial managed balance expected")
    assert(g2:player_balance(g2.players[1], "金豆") == 20, "game2 initial managed balance expected")

    local ok = bridge.consume_currency(g1, g1.players[1], "金豆", 5)
    assert(ok == true, "game1 consume should succeed with own context")
    assert(g1:player_balance(g1.players[1], "金豆") == 1, "game1 balance should update after consume")
    assert(g2:player_balance(g2.players[1], "金豆") == 20, "game2 balance should remain unchanged")
  end)
end

local function _test_bridge_setup_works_when_sandbox_blocks_mode_metatable()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game, { jindou_count = 4 })
  local base_setmetatable = setmetatable
  local patch_list = {}
  for _, patch in ipairs(env.patch_list) do
    table.insert(patch_list, patch)
  end
  table.insert(patch_list, {
    key = "setmetatable",
    value = function(tbl, mt)
      if type(mt) == "table" and (mt.__mode ~= nil or mt.__gc ~= nil) then
        error("sandbox metatable mode is not supported")
      end
      return base_setmetatable(tbl, mt)
    end,
  })

  _with_patches(patch_list, function()
    local bridge = _reload_bridge()
    bridge.setup_for_game(game)
    assert(game:player_balance(p, "金豆") == 4, "setup should succeed under sandbox metatable restrictions")
  end)
end

return {
  name = "paid_currency",
  tests = {
    { name = "paid_bridge_sync_balance_from_commodity", run = _test_paid_bridge_sync_balance_from_commodity },
    { name = "market_buy_managed_currency_consumes_commodity", run = _test_market_buy_managed_currency_consumes_commodity },
    { name = "market_insufficient_managed_currency_opens_panel", run = _test_market_insufficient_managed_currency_opens_panel },
    { name = "purchase_event_syncs_balance", run = _test_purchase_event_syncs_balance },
    { name = "bridge_isolates_context_between_games", run = _test_bridge_isolates_context_between_games },
    { name = "bridge_setup_works_when_sandbox_blocks_mode_metatable", run = _test_bridge_setup_works_when_sandbox_blocks_mode_metatable },
  },
}
