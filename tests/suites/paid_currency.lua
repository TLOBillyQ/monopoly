local support = require("TestSupport")
local _new_game = support.new_game
local _with_patches = support.with_patches
local runtime_ports = require("src.core.RuntimePorts")
local logger = require("src.core.Logger")
local paid_goods_cfg = require("src.game.systems.commerce.config.RuntimePaidGoods")

local function _reload_bridge()
  package.loaded["src.game.systems.commerce.PaidCurrencyBridge"] = nil
  return require("src.game.systems.commerce.PaidCurrencyBridge")
end

local function _reload_market()
  package.loaded["src.game.systems.market.MarketService"] = nil
  package.loaded["src.game.systems.market.service.Context"] = nil
  package.loaded["src.game.systems.market.service.Eligibility"] = nil
  package.loaded["src.game.systems.market.service.Purchase"] = nil
  package.loaded["src.game.systems.market.service.Auto"] = nil
  package.loaded["src.game.systems.market.service.Choice"] = nil
  return require("src.game.systems.market.MarketService")
end

local function _build_fake_env(game, opts)
  opts = opts or {}
  local jindou_commodity = opts.jindou_commodity or 9001
  local leyuanbi_commodity = opts.leyuanbi_commodity or 9002
  local jindou_count = opts.jindou_count or 0
  local leyuanbi_count = opts.leyuanbi_count or 0
  local consume_calls = {}
  local panel_calls = {}
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
      table.insert(panel_calls, { role_id = role.role_id, goods_id = goods_id, show_time = show_time })
    end
    return role
  end

  for _, player in ipairs(game.players) do
    role_by_player_id[player.id] = _new_role(player.id)
  end

  local goods_list = opts.goods_list or {
    { name = "强征卡", goods_id = "goods_strong_card" },
    { name = "财神卡", goods_id = "goods_god_rich" },
  }

  local trigger_handlers = {}
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
    {
      key = "EVENT",
      value = { SPEC_ROLE_PURCHASE_GOODS = "SPEC_ROLE_PURCHASE_GOODS" },
    },
    {
      key = "RegisterTriggerEvent",
      value = function(args, callback)
        local role_id = args and args[2] or nil
        trigger_handlers[role_id] = callback
      end,
    },
  }

  return {
    patch_list = patch_list,
    role_by_player_id = role_by_player_id,
    consume_calls = consume_calls,
    panel_calls = panel_calls,
    trigger_handlers = trigger_handlers,
    jindou_commodity = jindou_commodity,
    leyuanbi_commodity = leyuanbi_commodity,
  }
end

local function _with_currency_cfg(cfg, fn)
  _with_patches({
    { target = paid_goods_cfg, key = "enabled", value = true },
    { target = paid_goods_cfg, key = "currencies", value = cfg },
  }, fn)
end

local function _collect_warn_logs(run)
  local warns = {}
  _with_patches({
    {
      target = logger,
      key = "warn",
      value = function(...)
        warns[#warns + 1] = table.concat({ ... }, " ")
      end,
    },
  }, run)
  return warns
end

local function _test_paid_bridge_sync_balance_from_commodity()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game, { jindou_count = 7, leyuanbi_count = 3 })
  _with_currency_cfg({
    ["金豆"] = { commodity_id = env.jindou_commodity, unit_value = 1 },
    ["乐园币"] = { commodity_id = env.leyuanbi_commodity, unit_value = 1 },
  }, function()
    _with_patches(env.patch_list, function()
      local bridge = _reload_bridge()
      bridge.setup_for_game(game)
      assert(game:player_balance(p, "金豆") == 7, "jindou balance should sync from commodity")
      assert(game:player_balance(p, "乐园币") == 3, "leyuanbi balance should sync from commodity")
    end)
  end)
end

local function _test_invalid_commodity_mapping_only_affects_display_channel()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game, { jindou_count = 0 })

  _with_currency_cfg({
    ["金豆"] = { commodity_id = 0, unit_value = 1 },
    ["乐园币"] = { commodity_id = 0, unit_value = 1 },
  }, function()
    _with_patches(env.patch_list, function()
      local bridge = _reload_bridge()
      local market = _reload_market()
      bridge.setup_for_game(game)
      assert(bridge.is_managed_currency(game, "金豆") == false, "invalid commodity mapping should disable display sync")

      local result = market.purchase.execute(game, p, 2009, nil)
      assert(type(result) == "table" and result.ok == true, "paid purchase should still start via goods panel")
      assert(result.deferred_fulfillment == true, "paid purchase should defer fulfillment to purchase callback")
      assert(#env.panel_calls == 1, "paid purchase should open goods purchase panel")
      assert(#env.consume_calls == 0, "paid purchase should not consume commodity locally")
    end)
  end)
end

local function _test_market_paid_purchase_requires_goods_mapping()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game, {
    goods_list = {
      { name = "不存在的商品", goods_id = "goods_unknown" },
    },
  })

  local warns = _collect_warn_logs(function()
    _with_currency_cfg({
      ["金豆"] = { commodity_id = env.jindou_commodity, unit_value = 1 },
      ["乐园币"] = { commodity_id = env.leyuanbi_commodity, unit_value = 1 },
    }, function()
      _with_patches(env.patch_list, function()
        local market = _reload_market()
        local result = market.purchase.execute(game, p, 2009, nil)
        assert(type(result) == "table" and result.ok == false, "missing goods mapping should reject paid purchase")
        assert(result.reason == "goods_mapping_missing", "missing goods mapping reason should be explicit")
        assert(#env.panel_calls == 0, "missing goods mapping should not open purchase panel")
      end)
    end)
  end)
  local joined = table.concat(warns, "\n")
  assert(joined:find("market paid goods mapping missing:", 1, true) ~= nil, "should log missing paid goods mapping")
end

local function _test_paid_purchase_callback_fulfills_item()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game)
  local before_limit = game.market_limits[2009]
  local before_count = p.inventory:count()

  _with_currency_cfg({
    ["金豆"] = { commodity_id = env.jindou_commodity, unit_value = 1 },
    ["乐园币"] = { commodity_id = env.leyuanbi_commodity, unit_value = 1 },
  }, function()
    _with_patches(env.patch_list, function()
      local market = _reload_market()
      local result = market.purchase.execute(game, p, 2009, nil)
      assert(type(result) == "table" and result.ok == true and result.deferred_fulfillment == true,
        "paid purchase should enter deferred mode")

      local cb = env.trigger_handlers[p.id]
      assert(type(cb) == "function", "purchase callback should be registered")
      cb(nil, nil, { role = env.role_by_player_id[p.id], goods_id = "goods_strong_card" })
      assert(p.inventory:count() == before_count + 1, "purchase callback should grant item")
      assert(game.market_limits[2009] == before_limit - 1, "purchase callback should consume global market limit")
    end)
  end)
end

return {
  name = "paid_currency",
  tests = {
    { name = "paid_bridge_sync_balance_from_commodity", run = _test_paid_bridge_sync_balance_from_commodity },
    { name = "invalid_commodity_mapping_only_affects_display_channel", run = _test_invalid_commodity_mapping_only_affects_display_channel },
    { name = "market_paid_purchase_requires_goods_mapping", run = _test_market_paid_purchase_requires_goods_mapping },
    { name = "paid_purchase_callback_fulfills_item", run = _test_paid_purchase_callback_fulfills_item },
  },
}
