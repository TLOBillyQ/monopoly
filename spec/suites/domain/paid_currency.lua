local support = require("support.domain_support")
local _new_game = support.new_game
local _with_patches = support.with_patches
local market_cfg = require("src.config.content.market")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local logger = require("src.foundation.log.logger")
local paid_goods_cfg = require("src.rules.commerce.paid_goods")
local paid_purchase_port = require("src.rules.market.paid_purchase_port")

local function _reload_bridge()
  package.loaded["src.rules.commerce.paid_currency_bridge"] = nil
  return require("src.rules.commerce.paid_currency_bridge")
end

local function _reload_market()
  package.loaded["src.rules.market"] = nil
  package.loaded["src.rules.market.query.context"] = nil
  package.loaded["src.rules.market.query.eligibility"] = nil
  package.loaded["src.rules.market.purchase.core"] = nil
  package.loaded["src.rules.market.auto"] = nil
  package.loaded["src.rules.market.choice.builder"] = nil
  return require("src.rules.market")
end

local function _find_hidden_paid_entry()
  for _, entry in ipairs(market_cfg) do
    if entry.market_enabled == false and (entry.currency == "金豆" or entry.currency == "乐园币") then
      return entry
    end
  end
  return nil
end

local function _hidden_paid_product_ids()
  local ids = {}
  for _, entry in ipairs(market_cfg) do
    if entry.market_enabled == false and (entry.currency == "金豆" or entry.currency == "乐园币") then
      ids[#ids + 1] = entry.product_id
    end
  end
  return ids
end

local function _build_fake_env(game, opts)
  opts = opts or {}
  local panel_calls = {}
  local role_by_player_id = {}

  local function _new_role(role_id)
    local role = {
      role_id = role_id,
    }
    role.get_roleid = function()
      return role.role_id
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
    panel_calls = panel_calls,
    trigger_handlers = trigger_handlers,
  }
end

local function _with_currency_cfg(cfg, fn)
  _with_patches({
    { target = paid_goods_cfg, key = "enabled", value = true },
    { target = paid_goods_cfg, key = "currencies", value = cfg },
  }, function()
    paid_purchase_port.reset_for_tests()
    paid_purchase_port.configure(require("src.host.paid_purchase_gateway"))
    fn()
  end)
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

local function _test_paid_bridge_external_currency_is_not_managed_and_setup_is_silent()
  local game = _new_game()
  local warns = _collect_warn_logs(function()
    _with_currency_cfg({
      ["金豆"] = { source = "external" },
      ["乐园币"] = { source = "external" },
    }, function()
      local bridge = _reload_bridge()
      bridge.setup_for_game(game)
      assert(bridge.is_paid_currency("金豆") == true, "jindou should remain a paid currency")
      assert(bridge.is_paid_currency("乐园币") == true, "leyuanbi should remain a paid currency")
      assert(bridge.is_managed_currency(game, "金豆") == false, "external jindou should not be locally managed")
      assert(bridge.is_managed_currency(game, "乐园币") == false, "external leyuanbi should not be locally managed")
      assert(bridge.is_currency_channel_ready(game, "金豆") == true, "external paid currency should be ready for goods flow")
      assert(bridge.unavailable_reason(game, "金豆") == nil, "external paid currency should not expose commodity errors")
    end)
  end)
  local joined = table.concat(warns, "\n")
  assert(joined:find("invalid_commodity_id", 1, true) == nil, "external currency setup should not log commodity mapping errors")
  assert(joined:find("paid channel startup unavailable", 1, true) == nil, "external currency setup should not log startup unavailable")
end

local function _test_external_paid_currency_still_starts_goods_purchase_panel()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game)

  _with_currency_cfg({
    ["金豆"] = { source = "external" },
    ["乐园币"] = { source = "external" },
  }, function()
    _with_patches(env.patch_list, function()
      local bridge = _reload_bridge()
      local market = _reload_market()
      bridge.setup_for_game(game)
      assert(bridge.is_managed_currency(game, "金豆") == false, "external paid currency should not enable display sync")

      local result = market.purchase.execute(game, p, 2009, nil)
      assert(type(result) == "table" and result.ok == true, "paid purchase should still start via goods panel")
      assert(result.deferred_fulfillment == true, "paid purchase should defer fulfillment to purchase callback")
      assert(#env.panel_calls == 1, "paid purchase should open goods purchase panel")
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
      ["金豆"] = { source = "external" },
      ["乐园币"] = { source = "external" },
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

local function _test_market_paid_purchase_warns_missing_mapping_only_once_per_product()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game, {
    goods_list = {
      { name = "不存在的商品", goods_id = "goods_unknown" },
    },
  })

  local warns = _collect_warn_logs(function()
    _with_currency_cfg({
      ["金豆"] = { source = "external" },
      ["乐园币"] = { source = "external" },
    }, function()
      _with_patches(env.patch_list, function()
        local market = _reload_market()
        local first = market.purchase.execute(game, p, 2009, nil)
        local second = market.purchase.execute(game, p, 2009, nil)
        assert(type(first) == "table" and first.ok == false, "first missing mapping should reject paid purchase")
        assert(type(second) == "table" and second.ok == false, "second missing mapping should still reject paid purchase")
      end)
    end)
  end)

  local warn_count = 0
  for _, warn in ipairs(warns) do
    if warn:find("market paid goods mapping missing:", 1, true) ~= nil then
      warn_count = warn_count + 1
    end
  end
  assert(warn_count == 1, "missing mapping should only warn once per product_id")
end

local function _test_hidden_paid_entries_do_not_log_mapping_missing()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game, {
    goods_list = {
      { name = "强征卡", goods_id = "goods_strong_card" },
    },
  })

  local warns = _collect_warn_logs(function()
    _with_currency_cfg({
      ["金豆"] = { source = "external" },
      ["乐园币"] = { source = "external" },
    }, function()
      _with_patches(env.patch_list, function()
        local market = _reload_market()
        local result = market.purchase.execute(game, p, 2009, nil)
        assert(type(result) == "table" and result.ok == true, "enabled paid item should still start purchase flow")
        assert(result.deferred_fulfillment == true, "enabled paid item should stay deferred")
        assert(#env.panel_calls == 1, "enabled paid item should open purchase panel")
      end)
    end)
  end)

  local joined = table.concat(warns, "\n")
  for _, product_id in ipairs(_hidden_paid_product_ids()) do
    assert(joined:find("product_id=" .. tostring(product_id), 1, true) == nil,
      "hidden paid entry should not emit missing mapping warning: " .. tostring(product_id))
  end
end

local function _test_paid_purchase_without_purchase_api_returns_explicit_reason()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game)
  env.role_by_player_id[p.id].show_goods_purchase_panel = nil

  _with_currency_cfg({
    ["金豆"] = { source = "external" },
    ["乐园币"] = { source = "external" },
  }, function()
    _with_patches(env.patch_list, function()
      local market = _reload_market()
      local result = market.purchase.execute(game, p, 2009, nil)
      assert(type(result) == "table" and result.ok == false, "missing purchase api should reject paid purchase")
      assert(result.reason == "purchase_api_missing", "missing purchase api reason should stay explicit")
      assert(#env.panel_calls == 0, "missing purchase api should not open purchase panel")
    end)
  end)
end

local function _test_hidden_paid_product_is_rejected_before_mapping()
  local hidden_entry = _find_hidden_paid_entry()
  if hidden_entry == nil then
    return
  end

  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game, {
    goods_list = {
      { name = "强征卡", goods_id = "goods_strong_card" },
    },
  })

  local warns = _collect_warn_logs(function()
    _with_currency_cfg({
      ["金豆"] = { source = "external" },
      ["乐园币"] = { source = "external" },
    }, function()
      _with_patches(env.patch_list, function()
        local market = _reload_market()
        local result = market.purchase.execute(game, p, hidden_entry.product_id, nil)
        assert(type(result) == "table" and result.ok == false, "hidden paid product should be rejected")
        assert(result.reason == "disabled" or result.reason == "vehicle_disabled",
          "hidden paid product should fail via market policy, not goods mapping")
        assert(#env.panel_calls == 0, "hidden paid product should not open purchase panel")
      end)
    end)
  end)

  local joined = table.concat(warns, "\n")
  assert(joined:find("product_id=" .. tostring(hidden_entry.product_id), 1, true) == nil,
    "hidden paid product rejection should not depend on its paid goods mapping warning")
end

local function _test_paid_purchase_callback_fulfills_item()
  local game = _new_game()
  local p = game.players[1]
  local env = _build_fake_env(game)
  local before_limit = game.market_limits[2009]
  local before_count = p.inventory:count()

  _with_currency_cfg({
    ["金豆"] = { source = "external" },
    ["乐园币"] = { source = "external" },
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
    {
      name = "paid_bridge_external_currency_is_not_managed_and_setup_is_silent",
      run = _test_paid_bridge_external_currency_is_not_managed_and_setup_is_silent,
    },
    {
      name = "external_paid_currency_still_starts_goods_purchase_panel",
      run = _test_external_paid_currency_still_starts_goods_purchase_panel,
    },
    { name = "market_paid_purchase_requires_goods_mapping", run = _test_market_paid_purchase_requires_goods_mapping },
    {
      name = "market_paid_purchase_warns_missing_mapping_only_once_per_product",
      run = _test_market_paid_purchase_warns_missing_mapping_only_once_per_product,
    },
    { name = "hidden_paid_entries_do_not_log_mapping_missing", run = _test_hidden_paid_entries_do_not_log_mapping_missing },
    {
      name = "paid_purchase_without_purchase_api_returns_explicit_reason",
      run = _test_paid_purchase_without_purchase_api_returns_explicit_reason,
    },
    { name = "hidden_paid_product_is_rejected_before_mapping", run = _test_hidden_paid_product_is_rejected_before_mapping },
    { name = "paid_purchase_callback_fulfills_item", run = _test_paid_purchase_callback_fulfills_item },
  },
}
