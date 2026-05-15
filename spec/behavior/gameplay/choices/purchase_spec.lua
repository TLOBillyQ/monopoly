local function _reload_module(module_name, overrides, fn)
  local original = {}
  for key, value in pairs(overrides or {}) do
    original[key] = package.loaded[key]
    package.loaded[key] = value
  end
  local original_module = package.loaded[module_name]
  package.loaded[module_name] = nil
  local ok, result = pcall(function()
    local loaded = require(module_name)
    return fn(loaded)
  end)
  package.loaded[module_name] = original_module
  for key, value in pairs(original) do
    package.loaded[key] = value
  end
  if not ok then
    error(result)
  end
  return result
end


-- T8 tests for _handle_paid_purchase in purchase.lua

describe("choices_purchase", function()
  it("_test_purchase_execute_paid_purchase_success_and_failure", function()
    local start_calls = {}
    _reload_module("src.rules.market.purchase.core", {
      ["src.rules.market.query.context"] = {
        entry_by_id = function(product_id)
          return { product_id = product_id, kind = "item", currency = "金豆", name = "Paid Item" }
        end,
        entry_currency = function(entry)
          return entry.currency
        end,
        is_paid_currency = function(currency)
          return currency == "金豆"
        end,
      },
      ["src.rules.market.purchase.policy"] = {
        validate_entry = function()
          return { ok = true }
        end,
      },
      ["src.rules.market.purchase.local_purchase"] = {
        execute = function()
          error("local purchase should not run for paid currency")
        end,
      },
      ["src.rules.market.choice.feedback"] = {
        emit_buy_failed = function(player, entry, reason, body)
          start_calls[#start_calls + 1] = { failed = true, reason = reason, body = body }
        end,
      },
      ["src.rules.market.purchase.paid_purchase_callback"] = {
        handle = function() end,
      },
      ["src.rules.ports.paid_purchase"] = {
        setup_for_game = function() end,
        start = function(_, _, entry)
          start_calls[#start_calls + 1] = { failed = false, product_id = entry.product_id }
          if #start_calls == 1 then
            return true
          end
          return false, "gateway_down"
        end,
      },
    }, function(purchase)
      local game = {}
      local player = { id = 3, name = "Buyer" }
      local success = purchase.execute(game, player, "2001", {})
      assert(success.ok == true and success.deferred_fulfillment == true, "paid purchase should defer fulfillment on success")
      local failure = purchase.execute(game, player, "2001", {})
      assert(failure.ok == false and failure.reason == "gateway_down", "paid purchase failure should preserve gateway reason")
    end)
    assert(#start_calls == 3, "expected success start, failed start, and failure feedback")
    assert(start_calls[1].product_id == 2001, "product id should be normalized before start")
    assert(start_calls[3].failed == true and start_calls[3].reason == "gateway_down", "failure should emit feedback")
  end)

  it("_test_handle_paid_purchase_logs_warning_on_failure", function()
    local start_calls = {}
    local warn_calls = {}
    _reload_module("src.rules.market.purchase.core", {
      ["src.rules.market.query.context"] = {
        entry_by_id = function(product_id)
          return { product_id = product_id, kind = "item", currency = "金豆", name = "Paid Item" }
        end,
        entry_currency = function(entry)
          return entry.currency
        end,
        is_paid_currency = function(currency)
          return currency == "金豆"
        end,
      },
      ["src.rules.market.purchase.policy"] = {
        validate_entry = function()
          return { ok = true }
        end,
      },
      ["src.rules.market.purchase.local_purchase"] = {
        execute = function()
          error("local purchase should not run for paid currency")
        end,
      },
      ["src.rules.market.choice.feedback"] = {
        emit_buy_failed = function(player, entry, reason, body)
          start_calls[#start_calls + 1] = { failed = true, reason = reason, body = body }
        end,
      },
      ["src.rules.market.purchase.paid_purchase_callback"] = {
        handle = function() end,
      },
      ["src.rules.ports.paid_purchase"] = {
        setup_for_game = function() end,
        start = function(_, _, entry)
          return false, "payment_gateway_error"
        end,
      },
      ["src.foundation.log"] = {
        warn = function(...)
          warn_calls[#warn_calls + 1] = table.concat({ ... }, " ")
        end,
      },
    }, function(purchase)
      local game = {}
      local player = { id = 3, name = "Buyer" }
      local result = purchase.execute(game, player, "2001", {})
      assert(result.ok == false, "should fail when gateway returns error")
      assert(#warn_calls >= 1, "should log warning when gateway returns error")
      assert(string.find(warn_calls[1], "market paid purchase blocked:", 1, true) ~= nil,
        "warning should use the single-path message")
    end)
  end)

  it("_test_handle_paid_purchase_success_path", function()
    local start_calls = {}
    _reload_module("src.rules.market.purchase.core", {
      ["src.rules.market.query.context"] = {
        entry_by_id = function(product_id)
          return { product_id = product_id, kind = "item", currency = "金豆", name = "Paid Item" }
        end,
        entry_currency = function(entry)
          return entry.currency
        end,
        is_paid_currency = function(currency)
          return currency == "金豆"
        end,
      },
      ["src.rules.market.purchase.policy"] = {
        validate_entry = function()
          return { ok = true }
        end,
      },
      ["src.rules.market.purchase.local_purchase"] = {
        execute = function()
          error("local purchase should not run for paid currency")
        end,
      },
      ["src.rules.market.choice.feedback"] = {
        emit_buy_failed = function() end,
      },
      ["src.rules.market.purchase.paid_purchase_callback"] = {
        handle = function() end,
      },
      ["src.rules.ports.paid_purchase"] = {
        setup_for_game = function() end,
        start = function(_, _, entry)
          start_calls[#start_calls + 1] = { product_id = entry.product_id }
          return true
        end,
      },
    }, function(purchase)
      local game = {}
      local player = { id = 3, name = "Buyer" }
      local result = purchase.execute(game, player, "2001", {})
      assert(result.ok == true, "should succeed when gateway returns true")
      assert(result.deferred_fulfillment == true, "should indicate deferred fulfillment")
      assert(result.kind == "item", "should preserve entry kind")
      assert(result.product_id == 2001, "should preserve product_id")
      assert(#start_calls == 1, "should call start once")
    end)
  end)
end)
