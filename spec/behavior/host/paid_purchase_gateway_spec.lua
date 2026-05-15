local support = require("spec.support.runtime_support")
local _assert_eq = support.assert_eq
local with_patches = support.with_patches

describe("suites.runtime.misc_eggy_paid_gateway", function()
  it("eggy_paid_gateway_callback_missing_goods_id", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local game = { players = {} }
    local rt = gateway._runtime(game)
    local warned = nil

    with_patches({
      {
        target = require("src.foundation.log"),
        key = "warn",
        value = function(msg)
          warned = msg
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, {})
    end)

    _assert_eq(warned, "market paid callback ignored: goods_id missing", "should warn when goods_id is missing")
  end)

  it("eggy_paid_gateway_callback_empty_goods_id", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local game = { players = {} }
    local rt = gateway._runtime(game)
    local warned = nil

    with_patches({
      {
        target = require("src.foundation.log"),
        key = "warn",
        value = function(msg)
          warned = msg
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, { goods_id = "" })
    end)

    _assert_eq(warned, "market paid callback ignored: goods_id missing", "should warn when goods_id is empty")
  end)

  it("eggy_paid_gateway_callback_missing_pending", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local game = { players = {} }
    local rt = gateway._runtime(game)
    local warned = nil

    with_patches({
      {
        target = require("src.foundation.log"),
        key = "warn",
        value = function(msg, ctx1, ctx2)
          warned = msg .. " " .. tostring(ctx1) .. " " .. tostring(ctx2)
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123" })
    end)

    assert(warned and warned:find("pending missing", 1, true), "should warn when pending is missing: " .. tostring(warned))
  end)

  it("eggy_paid_gateway_callback_missing_player", function()
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
        target = require("src.foundation.log"),
        key = "warn",
        value = function(msg, ctx)
          warned = msg .. " " .. tostring(ctx)
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
    end)

    assert(warned and warned:find("player missing", 1, true), "should warn when player is missing: " .. tostring(warned))
  end)

  it("eggy_paid_gateway_callback_missing_entry", function()
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
        target = require("src.foundation.log"),
        key = "warn",
        value = function(msg, ctx)
          warned = msg .. " " .. tostring(ctx)
        end,
      },
    }, function()
      gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })
    end)

    assert(warned and warned:find("market entry missing", 1, true), "should warn when entry is missing: " .. tostring(warned))
  end)

  it("eggy_paid_gateway_callback_success_with_on_purchase", function()
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
    gateway._push_pending(rt, 5, { player_id = 99, product_id = 1001, entry = mock_entry, goods_id = "goods_123" })
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })

    _assert_eq(purchase_called, true, "on_purchase should be called")
  end)

  it("eggy_paid_gateway_callback_success_without_on_purchase", function()
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
    gateway._push_pending(rt, 5, { player_id = 99, product_id = 1001, entry = mock_entry, goods_id = "goods_123" })
    gateway._on_purchase_goods_callback(game, rt, { goods_id = "goods_123", role = { get_roleid = function() return 5 end } })

    -- No error means success - on_purchase is optional
  end)

  it("eggy_paid_gateway_start_missing_purchase_api", function()
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
        target = require("src.foundation.ports.runtime_ports"),
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
  end)

  it("eggy_paid_gateway_start_uses_zero_arity_role_id_and_dot_panel_args", function()
    local gateway = require("src.host.paid_purchase_gateway")
    local player = { id = 1 }
    local game = {
      players = { player },
    }
    local entry = {
      product_id = 2009,
      name = "强征卡",
      currency = "金豆",
      market_enabled = true,
    }
    local panel_call = nil

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
        target = require("src.foundation.ports.runtime_ports"),
        key = "resolve_role",
        value = function(role_id)
          if role_id ~= player.id then
            return nil
          end
          return {
            get_roleid = function(...)
              _assert_eq(select("#", ...), 0, "get_roleid should be called without implicit self")
              return 77
            end,
            show_goods_purchase_panel = function(...)
              _assert_eq(select("#", ...), 2, "show_goods_purchase_panel should receive exactly goods_id and show_time")
              panel_call = {
                goods_id = select(1, ...),
                show_time = select(2, ...),
              }
            end,
          }
        end,
      },
    }, function()
      local ok, reason = gateway.start(game, player, entry)
      _assert_eq(ok, true, "start should succeed with valid zero-arity role api")
      _assert_eq(reason, nil, "start should not return error on valid host api")
    end)

    _assert_eq(panel_call and panel_call.goods_id, "goods_strong_card", "panel should receive mapped goods id")
    _assert_eq(panel_call and panel_call.show_time, 10.0, "panel should receive configured show time")

    local rt = gateway._runtime(game)
    _assert_eq(type(rt.pending_by_role_id[77]), "table", "pending queue should use resolved host role id")
    _assert_eq(rt.pending_by_role_id[77][1].goods_id, "goods_strong_card", "pending queue should store goods id under host role id")
    _assert_eq(rt.pending_by_role_id[77][1].entry, entry, "pending queue should carry original market entry")
  end)
end)
