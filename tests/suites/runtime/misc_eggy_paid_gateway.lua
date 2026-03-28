local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local with_patches = support.with_patches

local function _test_eggy_paid_gateway_callback_missing_goods_id()
  local gateway = require("src.host.paid_purchase_gateway")
  local game = { players = {} }
  local rt = gateway._runtime(game)
  local warned = nil

  with_patches({
    {
      target = require("src.core.utils.logger"),
      key = "warn",
      value = function(msg)
        warned = msg
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, {})
  end)

  _assert_eq(warned, "market paid callback ignored: goods_id missing", "should warn when goods_id is missing")
end

local function _test_eggy_paid_gateway_callback_empty_goods_id()
  local gateway = require("src.host.paid_purchase_gateway")
  local game = { players = {} }
  local rt = gateway._runtime(game)
  local warned = nil

  with_patches({
    {
      target = require("src.core.utils.logger"),
      key = "warn",
      value = function(msg)
        warned = msg
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "" })
  end)

  _assert_eq(warned, "market paid callback ignored: goods_id missing", "should warn when goods_id is empty")
end

local function _test_eggy_paid_gateway_callback_missing_pending()
  local gateway = require("src.host.paid_purchase_gateway")
  local game = { players = {} }
  local rt = gateway._runtime(game)
  local warned = nil

  with_patches({
    {
      target = require("src.core.utils.logger"),
      key = "warn",
      value = function(msg, ctx1, ctx2)
        warned = msg .. " " .. tostring(ctx1) .. " " .. tostring(ctx2)
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123" })
  end)

  assert(warned and warned:find("pending missing", 1, true), "should warn when pending is missing: " .. tostring(warned))
end

local function _test_eggy_paid_gateway_callback_missing_player()
  local gateway = require("src.host.paid_purchase_gateway")
  local game = {
    players = {},
    find_player_by_id = function()
      return nil
    end,
  }
  local rt = gateway._runtime(game)
  gateway._push_pending(rt, 5, { player_id = 99, product_id = 1001, goods_id = "goods_123" })
  local warned = nil

  with_patches({
    {
      target = require("src.core.utils.logger"),
      key = "warn",
      value = function(msg, ctx)
        warned = msg .. " " .. tostring(ctx)
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
  end)

  assert(warned and warned:find("player missing", 1, true), "should warn when player is missing: " .. tostring(warned))
end

local function _test_eggy_paid_gateway_callback_missing_entry()
  local gateway = require("src.host.paid_purchase_gateway")
  local mock_player = { id = 99 }
  local game = {
    players = { mock_player },
    find_player_by_id = function()
      return mock_player
    end,
  }
  local rt = gateway._runtime(game)
  gateway._push_pending(rt, 5, { player_id = 99, product_id = 9999, goods_id = "goods_123" })
  local warned = nil

  with_patches({
    {
      target = require("src.rules.market.query.context"),
      key = "entry_by_id",
      value = function()
        return nil
      end,
    },
    {
      target = require("src.core.utils.logger"),
      key = "warn",
      value = function(msg, ctx)
        warned = msg .. " " .. tostring(ctx)
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
  end)

  assert(warned and warned:find("market entry missing", 1, true), "should warn when entry is missing: " .. tostring(warned))
end

local function _test_eggy_paid_gateway_callback_success_with_on_purchase()
  local gateway = require("src.host.paid_purchase_gateway")
  local mock_player = { id = 99 }
  local mock_entry = { product_id = 1001, name = "Test Item" }
  local game = {
    players = { mock_player },
    find_player_by_id = function()
      return mock_player
    end,
  }
  local rt = gateway._runtime(game)
  local purchase_called = false
  rt.on_purchase = function(g, p, e, pending)
    purchase_called = true
    _assert_eq(g, game, "game should match")
    _assert_eq(p, mock_player, "player should match")
    _assert_eq(e, mock_entry, "entry should match")
    _assert_eq(pending.product_id, 1001, "pending product_id should match")
  end
  gateway._push_pending(rt, 5, { player_id = 99, product_id = 1001, goods_id = "goods_123" })

  with_patches({
    {
      target = require("src.rules.market.query.context"),
      key = "entry_by_id",
      value = function(id)
        if id == 1001 then return mock_entry end
        return nil
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
  end)

  _assert_eq(purchase_called, true, "on_purchase should be called")
end

local function _test_eggy_paid_gateway_callback_success_without_on_purchase()
  local gateway = require("src.host.paid_purchase_gateway")
  local mock_player = { id = 99 }
  local mock_entry = { product_id = 1001, name = "Test Item" }
  local game = {
    players = { mock_player },
    find_player_by_id = function()
      return mock_player
    end,
  }
  local rt = gateway._runtime(game)
  gateway._push_pending(rt, 5, { player_id = 99, product_id = 1001, goods_id = "goods_123" })

  with_patches({
    {
      target = require("src.rules.market.query.context"),
      key = "entry_by_id",
      value = function(id)
        if id == 1001 then return mock_entry end
        return nil
      end,
    },
  }, function()
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
  end)

  -- No error means success - on_purchase is optional
end

local function _test_eggy_paid_gateway_start_missing_purchase_api()
  local gateway = require("src.host.paid_purchase_gateway")
  local game = {
    players = {
      { id = 1 },
    },
  }
  local entry = {
    product_id = 2009,
    name = "强征卡",
    currency = "金豆",
    market_enabled = true,
  }

  with_patches({
    {
      key = "GameAPI",
      value = {
        get_goods_list = function()
          return {
            { name = "强征卡", goods_id = "goods_strong_card" },
          }
        end,
      },
    },
    {
      target = require("src.core.ports.runtime_ports"),
      key = "resolve_role",
      value = function()
        return {
          get_roleid = function()
            return 1
          end,
        }
      end,
    },
  }, function()
    local ok, reason = gateway.start(game, game.players[1], entry)
    _assert_eq(ok, false, "start should reject when purchase api is missing")
    _assert_eq(reason, "purchase_api_missing", "start should return explicit missing api reason")
  end)
end

return {
  { name = "eggy_paid_gateway_callback_missing_goods_id", run = _test_eggy_paid_gateway_callback_missing_goods_id },
  { name = "eggy_paid_gateway_callback_empty_goods_id", run = _test_eggy_paid_gateway_callback_empty_goods_id },
  { name = "eggy_paid_gateway_callback_missing_pending", run = _test_eggy_paid_gateway_callback_missing_pending },
  { name = "eggy_paid_gateway_callback_missing_player", run = _test_eggy_paid_gateway_callback_missing_player },
  { name = "eggy_paid_gateway_callback_missing_entry", run = _test_eggy_paid_gateway_callback_missing_entry },
  { name = "eggy_paid_gateway_callback_success_with_on_purchase", run = _test_eggy_paid_gateway_callback_success_with_on_purchase },
  { name = "eggy_paid_gateway_callback_success_without_on_purchase", run = _test_eggy_paid_gateway_callback_success_without_on_purchase },
  { name = "eggy_paid_gateway_start_missing_purchase_api", run = _test_eggy_paid_gateway_start_missing_purchase_api },
}
