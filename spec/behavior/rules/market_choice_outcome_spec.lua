local function _reload_module(overrides, fn)
  local originals = {}
  for key, value in pairs(overrides) do
    originals[key] = package.loaded[key]
    package.loaded[key] = value
  end
  local target_key = "src.rules.market.choice"
  local original_module = package.loaded[target_key]
  package.loaded[target_key] = nil
  local ok, result = pcall(function()
    return fn(require(target_key))
  end)
  package.loaded[target_key] = original_module
  for key, value in pairs(originals) do
    package.loaded[key] = value
  end
  if not ok then error(result, 2) end
  return result
end

local function _base_overrides()
  return {
    ["src.rules.market.query"] = {
      context = {
        entry_by_id = function() return nil end,
        entry_currency = function() return "金币" end,
        entry_market_enabled = function() return true end,
        entry_name = function() return "item" end,
        entry_price = function() return 100 end,
      },
      eligibility = {
        sorted_entries = function() return {} end,
        can_buy_entry = function() return false end,
        is_sold_out = function() return false end,
      },
    },
    ["src.config.choice.contract"] = {
      resolve_owner_role_id = function(c) return c.owner_role_id end,
    },
    ["src.rules.ports.intent_output"] = {
      open_choice = function() return {} end,
      push_popup = function() return true end,
    },
    ["src.state.dirty_tracker"] = {
      mark = function() end,
    },
  }
end

local function _make_game()
  return { dirty = {}, turn = {} }
end

local function _make_choice()
  return { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
end

local function _make_player()
  return { id = 1, name = "Alice" }
end

local function _make_entry(kind)
  return { kind = kind or "item", product_id = 101 }
end

describe("market_choice_outcome", function()
  it("_test_deferred_fulfillment_keeps_market_open", function()
    _reload_module(_base_overrides(), function(choice)
      choice.builder.build = function()
        return { title="T", body_lines={}, options={{}}, allow_cancel=true, cancel_label="X",
                 active_tab="item", page_index=1, page_count=1, owner_role_id=1, meta={} }
      end
      local game = _make_game()
      local ch = _make_choice()
      local player = _make_player()
      local entry = _make_entry("item")
      local finish_called = false
      local finish_choice = function() finish_called = true end

      local r = choice.outcome.resolve_purchase(game, ch, player, entry, { ok = true, deferred_fulfillment = true }, finish_choice)
      assert(r and r.stay == true, "deferred_fulfillment should keep market open")
      assert(not finish_called, "finish_choice should not be called on deferred fulfillment")
    end)
  end)

  it("_test_item_fulfilled_now_keeps_market_open", function()
    _reload_module(_base_overrides(), function(choice)
      choice.builder.build = function()
        return { title="T", body_lines={}, options={{}}, allow_cancel=true, cancel_label="X",
                 active_tab="item", page_index=1, page_count=1, owner_role_id=1, meta={} }
      end
      local game = _make_game()
      local ch = _make_choice()
      local player = _make_player()
      local entry = _make_entry("item")
      local finish_called = false

      local r = choice.outcome.resolve_purchase(game, ch, player, entry,
        { ok = true, fulfilled_now = true }, function() finish_called = true end)
      assert(r and r.stay == true, "item fulfilled_now should keep market open")
      assert(not finish_called, "finish_choice not called")
    end)
  end)

  it("_test_non_item_fulfilled_now_calls_finish", function()
    _reload_module(_base_overrides(), function(choice)
      local finish_called = false
      local game = _make_game()
      local ch = _make_choice()
      local player = _make_player()
      local entry = _make_entry("non_item")

      choice.outcome.resolve_purchase(game, ch, player, entry,
        { ok = true, fulfilled_now = true }, function() finish_called = true end)
      assert(finish_called, "non-item fulfilled_now should call finish_choice")
    end)
  end)

  it("_test_item_fulfilled_now_with_inventory_full_emits_feedback", function()
    local inventory_full_emitted = false
    local overrides = _base_overrides()
    _reload_module(overrides, function(choice)
      choice.builder.build = function()
        return { title="T", body_lines={}, options={{}}, allow_cancel=true, cancel_label="X",
                 active_tab="item", page_index=1, page_count=1, owner_role_id=1, meta={} }
      end
      choice.feedback.emit_inventory_full = function() inventory_full_emitted = true end

      local game = _make_game()
      local ch = _make_choice()
      local player = _make_player()
      local entry = _make_entry("item")

      local r = choice.outcome.resolve_purchase(game, ch, player, entry,
        { ok = true, fulfilled_now = true, inventory_full_after = true }, function() end)
      assert(r and r.stay == true, "should stay open")
      assert(inventory_full_emitted, "should emit inventory full feedback")
    end)
  end)

  it("_test_purchase_failure_stays_open_when_rebuild_succeeds", function()
    _reload_module(_base_overrides(), function(choice)
      choice.builder.build = function()
        return { title="T", body_lines={}, options={{}}, allow_cancel=true, cancel_label="X",
                 active_tab="item", page_index=1, page_count=1, owner_role_id=1, meta={} }
      end
      local game = _make_game()
      local ch = _make_choice()
      local player = _make_player()
      local entry = _make_entry("item")
      local finish_called = false

      local r = choice.outcome.resolve_purchase(game, ch, player, entry,
        { ok = false, reason = "not_enough_coins" }, function() finish_called = true end)
      assert(r and r.stay == true, "purchase failure with rebuild should stay open")
      assert(not finish_called, "finish_choice not called on failure+rebuild")
    end)
  end)

  it("_test_purchase_failure_calls_finish_when_rebuild_fails", function()
    _reload_module(_base_overrides(), function(choice)
      choice.builder.build = function() return nil end
      local game = _make_game()
      local ch = _make_choice()
      local player = _make_player()
      local entry = _make_entry("item")
      local finish_called = false

      choice.outcome.resolve_purchase(game, ch, player, entry,
        { ok = false }, function() finish_called = true end)
      assert(finish_called, "purchase failure with failed rebuild should call finish_choice")
    end)
  end)

  it("_test_need_choice_intent_stays_open", function()
    local open_choice_called = false
    local overrides = _base_overrides()
    overrides["src.rules.ports.intent_output"] = {
      open_choice = function(_, spec, _)
        open_choice_called = true
        return spec
      end,
      push_popup = function() return true end,
    }
    _reload_module(overrides, function(choice)
      local game = _make_game()
      local ch = _make_choice()
      local player = _make_player()
      local entry = _make_entry("item")
      local finish_called = false
      local fake_spec = { kind = "some_choice" }

      local r = choice.outcome.resolve_purchase(game, ch, player, entry,
        { ok = nil, intent = { kind = "need_choice", choice_spec = fake_spec } },
        function() finish_called = true end)
      assert(r and r.stay == true, "need_choice intent should keep market open")
      assert(open_choice_called, "should call open_choice")
      assert(not finish_called, "finish_choice not called")
    end)
  end)

  it("_test_no_intent_calls_finish", function()
    _reload_module(_base_overrides(), function(choice)
      local finish_called = false
      local game = _make_game()
      local ch = _make_choice()
      local player = _make_player()
      local entry = _make_entry("item")

      choice.outcome.resolve_purchase(game, ch, player, entry,
        { ok = nil }, function() finish_called = true end)
      assert(finish_called, "no intent should call finish_choice")
    end)
  end)

  it("_test_non_table_result_calls_finish", function()
    _reload_module(_base_overrides(), function(choice)
      local finish_called = false
      local game = _make_game()
      local ch = _make_choice()
      local player = _make_player()
      local entry = _make_entry("item")

      choice.outcome.resolve_purchase(game, ch, player, entry,
        "some_string_result", function() finish_called = true end)
      assert(finish_called, "non-table result should call finish_choice")
    end)
  end)

  it("_test_missing_finish_choice_raises", function()
    _reload_module(_base_overrides(), function(choice)
      local ok = pcall(function()
        choice.outcome.resolve_purchase({}, {}, {}, {}, {}, nil)
      end)
      assert(ok == false, "nil finish_choice should raise")
    end)
  end)
end)
