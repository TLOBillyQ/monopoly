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

local function _make_query_mock(overrides)
  overrides = overrides or {}
  return {
    context = {
      entry_by_id = overrides.entry_by_id or function(product_id)
        return { product_id = product_id, kind = "item", currency = "金豆", name = "Paid Item" }
      end,
      entry_currency = overrides.entry_currency or function(entry)
        return entry.currency
      end,
      entry_price = overrides.entry_price or function(entry)
        return entry.price or 0
      end,
      entry_name = overrides.entry_name or function(entry)
        return entry.name or tostring(entry.product_id)
      end,
      is_paid_currency = overrides.is_paid_currency or function(currency)
        return currency == "金豆"
      end,
      entry_market_enabled = overrides.entry_market_enabled or function() return true end,
      remaining_global_limit = overrides.remaining_global_limit or function() return 99 end,
      try_charge_player = overrides.try_charge_player or function() return true end,
      consume_global_limit = overrides.consume_global_limit or function() end,
    },
    eligibility = {},
  }
end

local function _make_choice_mock(feedback_fn)
  return {
    feedback = {
      emit_buy_failed = feedback_fn or function() end,
    },
    session = { refresh_after_paid_callback = function() end },
    builder = {},
    outcome = {},
  }
end

describe("choices_purchase", function()
  it("_test_purchase_execute_paid_purchase_success_and_failure", function()
    local start_calls = {}
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock(),
      ["src.rules.market.choice"] = _make_choice_mock(function(player, entry, reason, body)
        start_calls[#start_calls + 1] = { failed = true, reason = reason, body = body }
      end),
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
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock(),
      ["src.rules.market.choice"] = _make_choice_mock(function(player, entry, reason, body)
        start_calls[#start_calls + 1] = { failed = true, reason = reason, body = body }
      end),
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
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock(),
      ["src.rules.market.choice"] = _make_choice_mock(),
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

  it("purchase_execute_rejects_disabled_and_sold_out_entries", function()
    local failures = {}
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock({
        entry_by_id = function(product_id)
          return { product_id = product_id, kind = "item", currency = "金币", name = "Blocked Item" }
        end,
        entry_market_enabled = function()
          return false
        end,
        is_paid_currency = function()
          return false
        end,
      }),
      ["src.rules.market.choice"] = _make_choice_mock(function(_, entry, reason, body)
        failures[#failures + 1] = { entry = entry, reason = reason, body = body }
      end),
    }, function(purchase)
      local result = purchase.execute({}, { id = 3, name = "Buyer" }, "2001")
      assert(result.ok == false, "disabled entries should be rejected")
      assert(result.reason == "disabled", "disabled entries should keep disabled reason")
    end)
    assert(#failures == 1, "disabled rejection should emit feedback")
    assert(failures[1].reason == "disabled", "disabled feedback should keep reason")
    assert(failures[1].body == "Buyer 该商品暂不可购买", "disabled feedback should keep body")

    failures = {}
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock({
        entry_by_id = function(product_id)
          return { product_id = product_id, kind = "item", currency = "金币", name = "Sold Out Item" }
        end,
        remaining_global_limit = function()
          return 0
        end,
        is_paid_currency = function()
          return false
        end,
      }),
      ["src.rules.market.choice"] = _make_choice_mock(function(_, entry, reason, body)
        failures[#failures + 1] = { entry = entry, reason = reason, body = body }
      end),
    }, function(purchase)
      local result = purchase.execute({ market_limits = { [2001] = 0 } }, { id = 3, name = "Buyer" }, "2001")
      assert(result.ok == false, "sold out entries should be rejected")
      assert(result.reason == "sold_out", "sold out entries should keep sold_out reason")
    end)
    assert(#failures == 1, "sold out rejection should emit feedback")
    assert(failures[1].reason == "sold_out", "sold out feedback should keep reason")
    assert(failures[1].body == "Buyer 该商品已售罄", "sold out feedback should keep body")
  end)

  it("purchase_execute_local_item_success_keeps_payload_and_exact_balance_boundary", function()
    local entry = { product_id = 1, kind = "item", currency = "金币", price = 7, name = "路障卡" }
    local give_calls = {}
    local give_contexts = {}
    local limit_consumed = {}
    local emitted = {}
    local published = {}
    local is_full_calls = 0

    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock({
        entry_by_id = function()
          return entry
        end,
        is_paid_currency = function()
          return false
        end,
        consume_global_limit = function(_, product_id)
          limit_consumed[#limit_consumed + 1] = product_id
        end,
      }),
      ["src.rules.items.inventory"] = {
        is_full = function()
          is_full_calls = is_full_calls + 1
          return is_full_calls > 1
        end,
        give = function(_, product_id, context)
          give_calls[#give_calls + 1] = product_id
          give_contexts[#give_contexts + 1] = context
        end,
      },
      ["src.foundation.events"] = {
        market = { bought_item = "mk.bought_item" },
        emit = function(kind, payload)
          emitted[#emitted + 1] = { kind = kind, payload = payload }
        end,
      },
      ["src.rules.ports.event_feed"] = {
        publish = function(_, payload)
          published[#published + 1] = payload
        end,
      },
      ["src.rules.market.choice"] = _make_choice_mock(),
    }, function(purchase)
      local game = {
        player_cash = function()
          return 7
        end,
      }
      local result = purchase.execute(game, { id = 3, name = "Buyer" }, "1")
      assert(result.ok == true, "exact balance should be enough to buy")
      assert(result.kind == "item", "local purchase should report item kind")
      assert(result.product_id == 1, "local purchase should keep normalized product id")
      assert(result.inventory_full_after == true, "result should report inventory fullness after giving item")
      assert(result.fulfilled_now == true, "local item purchase should fulfill immediately")
    end)

    assert(give_calls[1] == 1, "purchase should give the item")
    assert(give_contexts[1] and give_contexts[1].game ~= nil, "purchase should pass game context to inventory give")
    assert(limit_consumed[1] == 1, "purchase should consume global market limit")
    assert(emitted[1].kind == "mk.bought_item", "purchase should emit bought item event")
    assert(emitted[1].payload.price == 7, "bought item payload should keep price")
    assert(emitted[1].payload.currency == "金币", "bought item payload should keep currency")
    assert(published[1].kind == "item_acquired", "purchase should publish item acquired feed")
    assert(published[1].text == "Buyer 在黑市购买 路障卡 花费 7 金币", "feed should use priced success text")
  end)

  it("purchase_execute_reports_local_item_failures", function()
    local failures = {}
    local entry = { product_id = 2001, kind = "item", currency = "金币", price = 7, name = "路障卡" }

    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock({
        entry_by_id = function()
          return entry
        end,
        is_paid_currency = function()
          return false
        end,
      }),
      ["src.rules.market.choice"] = _make_choice_mock(function(_, _, reason, body)
        failures[#failures + 1] = { reason = reason, body = body }
      end),
    }, function(purchase)
      local game = {
        player_cash = function()
          return 6
        end,
      }
      local result = purchase.execute(game, { id = 3, name = "Buyer" }, "2001")
      assert(result.ok == false, "insufficient balance should fail")
      assert(result.reason == "insufficient_balance", "insufficient balance should keep reason")
      assert(result.option_id == 2001, "insufficient balance should keep option id")
    end)
    assert(failures[1].reason == "insufficient_balance", "insufficient balance should emit reason")
    assert(failures[1].body == "Buyer 余额不足", "insufficient balance should emit body")

    failures = {}
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock({
        entry_by_id = function()
          return entry
        end,
        is_paid_currency = function()
          return false
        end,
      }),
      ["src.rules.items.inventory"] = {
        is_full = function()
          return true
        end,
        give = function()
          error("full inventory should not receive item")
        end,
      },
      ["src.rules.market.choice"] = _make_choice_mock(function(_, _, reason, body)
        failures[#failures + 1] = { reason = reason, body = body }
      end),
    }, function(purchase)
      local game = {
        player_cash = function()
          return 7
        end,
      }
      local result = purchase.execute(game, { id = 3, name = "Buyer" }, "2001")
      assert(result.ok == false, "full inventory should fail")
      assert(result.reason == "inventory_full", "full inventory should keep reason")
    end)
    assert(failures[1].reason == "inventory_full", "full inventory should emit reason")
    assert(failures[1].body == "Buyer 卡槽已满", "full inventory should emit body")

    failures = {}
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock({
        entry_by_id = function()
          return entry
        end,
        is_paid_currency = function()
          return false
        end,
        try_charge_player = function()
          return false
        end,
      }),
      ["src.rules.items.inventory"] = {
        is_full = function()
          return false
        end,
        give = function()
          error("charge failure should not receive item")
        end,
      },
      ["src.rules.market.choice"] = _make_choice_mock(function(_, _, reason, body)
        failures[#failures + 1] = { reason = reason, body = body }
      end),
    }, function(purchase)
      local game = {
        player_cash = function()
          return 7
        end,
      }
      local result = purchase.execute(game, { id = 3, name = "Buyer" }, "2001")
      assert(result.ok == false, "charge failure should fail")
      assert(result.reason == "charge_failed", "charge failure should keep reason")
    end)
    assert(failures[1].reason == "charge_failed", "charge failure should emit reason")
    assert(failures[1].body == "Buyer 支付失败", "charge failure should emit body")
  end)

  it("purchase_execute_rejects_invalid_product_ids_before_lookup", function()
    local lookups = 0
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock({
        entry_by_id = function(product_id)
          lookups = lookups + 1
          return { product_id = product_id, kind = "item", currency = "金币", price = 1, name = "Item" }
        end,
        is_paid_currency = function()
          return false
        end,
      }),
      ["src.rules.market.choice"] = _make_choice_mock(),
      ["src.foundation.log"] = { warn = function() end },
    }, function(purchase)
      assert(purchase.execute({}, { id = 3, name = "Buyer" }, "0") == false,
        "zero product id should be rejected")
      assert(purchase.execute({}, { id = 3, name = "Buyer" }, "-1") == false,
        "negative product id should be rejected")
      assert(purchase.execute({}, { id = 3, name = "Buyer" }, "bad") == false,
        "non-numeric product id should be rejected")
    end)
    assert(lookups == 0, "invalid product ids should not hit catalog lookup")
  end)

  it("paid_purchase_callback_clears_in_flight_and_fulfills_item", function()
    local entry = { product_id = 2001, kind = "item", currency = "金豆", price = 5, name = "Paid Item" }
    local callback = nil
    local give_calls = {}
    local charge_calls = 0
    local refreshed = 0
    local emitted = {}
    local published = {}

    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock({
        entry_by_id = function()
          return entry
        end,
        try_charge_player = function()
          charge_calls = charge_calls + 1
          return true
        end,
      }),
      ["src.rules.items.inventory"] = {
        is_full = function()
          return false
        end,
        give = function(_, product_id)
          give_calls[#give_calls + 1] = product_id
        end,
      },
      ["src.rules.ports.paid_purchase"] = {
        setup_for_game = function(_, on_purchase)
          callback = on_purchase
        end,
        start = function()
          return true
        end,
      },
      ["src.foundation.ports.runtime_ports"] = {
        schedule = function(_, fn)
          assert(type(fn) == "function", "paid purchase should schedule in-flight cleanup")
        end,
      },
      ["src.foundation.events"] = {
        market = { bought_item = "mk.bought_item" },
        emit = function(kind, payload)
          emitted[#emitted + 1] = { kind = kind, payload = payload }
        end,
      },
      ["src.rules.ports.event_feed"] = {
        publish = function(_, payload)
          published[#published + 1] = payload
        end,
      },
      ["src.rules.market.choice"] = {
        feedback = { emit_buy_failed = function() end },
        session = {
          refresh_after_paid_callback = function()
            refreshed = refreshed + 1
          end,
        },
      },
    }, function(purchase)
      local game = {}
      local player = { id = 3, name = "Buyer" }
      local started = purchase.execute(game, player, "2001")
      assert(started.ok == true, "paid purchase should start")
      assert(game._market_paid_in_flight["3:2001"] == true, "paid purchase should mark in-flight")
      assert(callback(game, player, entry) == true, "paid callback should fulfill item")
      assert(game._market_paid_in_flight["3:2001"] == nil, "paid callback should clear in-flight")
    end)

    assert(give_calls[1] == 2001, "paid callback should give item")
    assert(charge_calls == 0, "paid callback fulfillment should skip local charge")
    assert(refreshed == 1, "paid callback success should refresh market choice")
    assert(emitted[1].payload.price == 5, "paid callback event should keep price")
    assert(emitted[1].payload.currency == "金豆", "paid callback event should keep currency")
    assert(published[1].text == "Buyer 在黑市购买 Paid Item 成功", "paid callback feed should use unpriced text")
  end)

  it("paid_purchase_paths_report_gateway_fallback_and_callback_failure", function()
    local failures = {}
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock(),
      ["src.rules.ports.paid_purchase"] = {
        setup_for_game = function() end,
        start = function()
          return false, nil
        end,
      },
      ["src.rules.market.choice"] = _make_choice_mock(function(_, _, reason, body)
        failures[#failures + 1] = { reason = reason, body = body }
      end),
    }, function(purchase)
      local result = purchase.execute({}, { id = 3, name = "Buyer" }, "2001")
      assert(result.ok == false, "gateway failure should fail")
      assert(result.reason == "paid_purchase_start_failed", "nil gateway reason should use fallback")
    end)
    assert(failures[1].reason == "paid_purchase_start_failed", "gateway fallback should emit fallback reason")
    assert(failures[1].body == "Buyer 购买通道暂不可用", "gateway fallback should emit body")

    failures = {}
    local callback = nil
    local refreshed = 0
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock(),
      ["src.rules.items.inventory"] = {
        is_full = function()
          return false
        end,
        give = function()
          error("unsupported callback entry should not give item")
        end,
      },
      ["src.rules.ports.paid_purchase"] = {
        setup_for_game = function(_, on_purchase)
          callback = on_purchase
        end,
        start = function()
          return true
        end,
      },
      ["src.foundation.ports.runtime_ports"] = {
        schedule = function() end,
      },
      ["src.rules.market.choice"] = {
        feedback = {
          emit_buy_failed = function(_, _, reason, body)
            failures[#failures + 1] = { reason = reason, body = body }
          end,
        },
        session = {
          refresh_after_paid_callback = function()
            refreshed = refreshed + 1
          end,
        },
      },
    }, function(purchase)
      local game = {}
      local player = { id = 3, name = "Buyer" }
      purchase.execute(game, player, "2001")
      assert(callback(game, player, { product_id = 5001, kind = "skin", currency = "金豆", name = "Skin" }) == false,
        "paid callback should reject unsupported entries")
    end)
    assert(failures[1].reason == "unsupported_kind", "unsupported callback entry should emit reason")
    assert(refreshed == 0, "unsupported callback entry should not refresh market choice")

    failures = {}
    callback = nil
    refreshed = 0
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock(),
      ["src.rules.items.inventory"] = {
        is_full = function()
          return true
        end,
        give = function()
          error("callback failure should not give item")
        end,
      },
      ["src.rules.ports.paid_purchase"] = {
        setup_for_game = function(_, on_purchase)
          callback = on_purchase
        end,
        start = function()
          return true
        end,
      },
      ["src.foundation.ports.runtime_ports"] = {
        schedule = function() end,
      },
      ["src.rules.market.choice"] = {
        feedback = {
          emit_buy_failed = function(_, _, reason, body)
            failures[#failures + 1] = { reason = reason, body = body }
          end,
        },
        session = {
          refresh_after_paid_callback = function()
            refreshed = refreshed + 1
          end,
        },
      },
    }, function(purchase)
      local game = {}
      local player = { id = 3, name = "Buyer" }
      purchase.execute(game, player, "2001")
      assert(callback(game, player, { product_id = 2001, kind = "item", currency = "金豆", name = "Paid Item" }) == false,
        "callback fulfillment failure should return false")
    end)
    assert(failures[1].reason == "inventory_full", "callback failure should emit fulfillment reason")
    assert(refreshed == 0, "callback failure should not refresh market choice")
  end)

  it("purchase_execute_rejects_non_item_entries", function()
    local failures = {}
    _reload_module("src.rules.market.purchase", {
      ["src.rules.market.query"] = _make_query_mock({
        entry_by_id = function(product_id)
          return { product_id = product_id, kind = "skin", currency = "金币", name = "Retired Skin" }
        end,
        is_paid_currency = function()
          return false
        end,
      }),
      ["src.rules.market.choice"] = _make_choice_mock(function(_, entry, reason, body)
        failures[#failures + 1] = { entry = entry, reason = reason, body = body }
      end),
    }, function(purchase)
      local game = {}
      local player = { id = 3, name = "Buyer" }
      local result = purchase.execute(game, player, "5001", {})
      assert(result.ok == false, "skin entries should be rejected by black-market purchase")
      assert(result.reason == "unsupported_kind", "skin rejection should use unsupported_kind")
    end)
    assert(#failures == 1, "rejected skin purchase should emit feedback")
    assert(failures[1].entry.product_id == 5001, "feedback should include rejected entry")
    assert(failures[1].reason == "unsupported_kind", "feedback should keep unsupported_kind reason")
  end)
end)
