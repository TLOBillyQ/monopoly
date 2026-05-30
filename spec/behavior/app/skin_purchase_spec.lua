local support = require("spec.support.shared_support")
local with_patches = support.with_patches

local skin_purchase = require("src.app.host_integrations.skin_purchase")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local logger = require("src.foundation.log")

local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _purchase_skin(overrides)
  local skin = {
    unlock = "purchase",
    product_id = 5001,
    name = "Test Skin",
    currency = "beans",
    price = 30,
  }
  for key, value in pairs(overrides or {}) do
    skin[key] = value
  end
  return skin
end

local function _state_for_player(player)
  return {
    game = {
      find_player_by_id = function(_, role_id)
        if tostring(role_id) == tostring(player.id) then
          return player
        end
        return nil
      end,
    },
  }
end

describe("skin_purchase", function()
  after_each(function()
    paid_purchase_port.reset_for_tests()
  end)

  it("starts_paid_purchase_with_skin_entry_and_fulfills_success_callback", function()
    local player = { id = 9 }
    local state = _state_for_player(player)
    local skin = _purchase_skin()
    local captured = nil
    local fulfilled = 0

    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function(game, start_player, entry)
          captured = { game = game, player = start_player, entry = entry }
          return true
        end,
      },
    }, function()
      local started = skin_purchase.start(state, 9, skin, function()
        fulfilled = fulfilled + 1
      end)

      _assert_eq(started, true, "skin purchase should start")
      _assert_eq(captured.entry.on_purchase(), true, "successful fulfillment should report true")
    end)

    _assert_eq(captured and captured.game, state.game, "entry should use state game")
    _assert_eq(captured and captured.player, player, "entry should use resolved player")
    _assert_eq(captured and captured.entry.kind, "skin", "entry should be tagged as skin")
    _assert_eq(captured and captured.entry.product_id, skin.product_id, "entry should keep product id")
    _assert_eq(captured and captured.entry.name, skin.name, "entry should keep display name")
    _assert_eq(captured and captured.entry.currency, skin.currency, "entry should keep currency")
    _assert_eq(captured and captured.entry.price, skin.price, "entry should keep price")
    _assert_eq(fulfilled, 1, "purchase callback should run once")
  end)

  it("configure_installs_skin_panel_purchase_callback", function()
    local player = { id = 7 }
    local state = _state_for_player(player)
    local configured = nil
    local start_count = 0

    skin_purchase.configure({
      configure_purchase = function(callback)
        configured = callback
      end,
    })

    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function()
          start_count = start_count + 1
          return true
        end,
      },
    }, function()
      _assert_eq(type(configured), "function", "configure should install purchase callback")
      _assert_eq(configured(7, _purchase_skin(), function() end, state), true, "configured callback should delegate to start")
    end)

    _assert_eq(start_count, 1, "configured callback should start one purchase")
  end)

  it("rejects_invalid_context_before_gateway", function()
    local warnings = {}

    with_patches({
      {
        target = logger,
        key = "warn",
        value = function(...)
          warnings[#warnings + 1] = table.concat({ ... }, " ")
        end,
      },
    }, function()
      _assert_eq(skin_purchase.start({ game = {} }, 1, _purchase_skin(), nil), false, "missing callback should reject")
      _assert_eq(skin_purchase.start({ game = {} }, 1, { unlock = "gift", product_id = 1 }, function() end), false,
        "non-purchase skin should reject")
      _assert_eq(skin_purchase.start(nil, 1, _purchase_skin(), function() end), false, "missing game should reject")
      _assert_eq(skin_purchase.start({ game = {} }, 1, _purchase_skin(), function() end), false,
        "missing player lookup should reject")
      _assert_eq(skin_purchase.start({ game = { find_player_by_id = function() return nil end } }, 1, _purchase_skin(), function() end), false,
        "missing player should reject")
    end)

    assert(#warnings >= 5, "invalid paths should warn")
  end)

  it("rejects_invalid_purchase_inputs_before_gateway_with_valid_context", function()
    local player = { id = 6 }
    local state = _state_for_player(player)
    local start_count = 0

    with_patches({
      {
        target = logger,
        key = "warn",
        value = function() end,
      },
      {
        target = paid_purchase_port,
        key = "start",
        value = function()
          start_count = start_count + 1
          return true
        end,
      },
    }, function()
      _assert_eq(skin_purchase.start(state, 6, _purchase_skin(), nil), false,
        "missing callback should reject before gateway")
      _assert_eq(skin_purchase.start(state, 6, nil, function() end), false,
        "nil skin should reject before gateway")
      _assert_eq(skin_purchase.start(state, 6, { unlock = "gift", product_id = 1 }, function() end), false,
        "non-purchase skin should reject before gateway")
      _assert_eq(skin_purchase.start(state, 6, { unlock = "purchase" }, function() end), false,
        "purchase skin without product_id should reject before gateway")
    end)

    _assert_eq(start_count, 0, "invalid purchase inputs must not call gateway")
  end)

  it("returns_false_when_gateway_errors_or_rejects", function()
    local player = { id = 3 }
    local state = _state_for_player(player)
    local warnings = {}

    with_patches({
      {
        target = logger,
        key = "warn",
        value = function(...)
          warnings[#warnings + 1] = table.concat({ ... }, " ")
        end,
      },
      {
        target = paid_purchase_port,
        key = "start",
        value = function()
          error("gateway boom")
        end,
      },
    }, function()
      _assert_eq(skin_purchase.start(state, 3, _purchase_skin(), function() end), false, "gateway error should be caught")
    end)

    with_patches({
      {
        target = logger,
        key = "warn",
        value = function(...)
          warnings[#warnings + 1] = table.concat({ ... }, " ")
        end,
      },
      {
        target = paid_purchase_port,
        key = "start",
        value = function()
          return false, "goods_mapping_missing"
        end,
      },
    }, function()
      _assert_eq(skin_purchase.start(state, 3, _purchase_skin(), function() end), false,
        "gateway rejection should return false")
    end)

    assert(warnings[1] and warnings[1]:find("skin_purchase: start failed", 1, true) ~= nil,
      "gateway error should be logged")
    assert(warnings[2] and warnings[2]:find("skin_purchase: start rejected", 1, true) ~= nil,
      "gateway rejection should be logged")
  end)

  it("purchase_entry_returns_false_when_fulfillment_callback_errors", function()
    local player = { id = 4 }
    local state = _state_for_player(player)
    local captured_entry = nil
    local warnings = {}

    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function(_, _, entry)
          captured_entry = entry
          return true
        end,
      },
    }, function()
      _assert_eq(skin_purchase.start(state, 4, _purchase_skin(), function()
        error("fulfillment boom")
      end), true, "purchase should start before fulfillment")
    end)

    with_patches({
      {
        target = logger,
        key = "warn",
        value = function(...)
          warnings[#warnings + 1] = table.concat({ ... }, " ")
        end,
      },
    }, function()
      _assert_eq(captured_entry.on_purchase(), false, "failing fulfillment should return false")
    end)

    assert(warnings[1] and warnings[1]:find("skin_purchase: fulfillment failed", 1, true) ~= nil,
      "fulfillment failure should be logged")
  end)
end)
