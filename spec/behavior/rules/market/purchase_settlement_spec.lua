-- purchase_settlement.resolve verdict 契约直测。
-- 由 market_choice_outcome_spec 十用例迁来:{stay}/finish_called → keep_open true/false。
local function _with_modules(overrides, fn)
  local saved = {}
  for key, value in pairs(overrides) do
    saved[key] = package.loaded[key]
    package.loaded[key] = value
  end
  for _, key in ipairs({ "src.rules.market.choice", "src.rules.market.purchase_settlement" }) do
    saved[key] = saved[key] or package.loaded[key]
    package.loaded[key] = nil
  end
  local ok, result = pcall(function()
    local choice = require("src.rules.market.choice")
    return fn(require("src.rules.market.purchase_settlement"), choice)
  end)
  for key, value in pairs(saved) do package.loaded[key] = value end
  if not ok then error(result, 2) end
  return result
end

local function _base_overrides()
  return {
    ["src.rules.market.query"] = {
      context = {
        entry_by_id = function() return nil end, entry_currency = function() return "金币" end,
        entry_market_enabled = function() return true end, entry_name = function() return "item" end,
        entry_price = function() return 100 end,
      },
      eligibility = {
        sorted_entries = function() return {} end, can_buy_entry = function() return false end,
        is_sold_out = function() return false end,
      },
    },
    ["src.config.choice.contract"] = { resolve_owner_role_id = function(c) return c.owner_role_id end },
    ["src.rules.ports.intent_output"] = { open_choice = function() return {} end, push_popup = function() return true end },
    ["src.state.dirty_tracker"] = { mark = function() end },
  }
end

local function _game() return { dirty = {}, turn = {} } end
local function _choice() return { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 } end
local function _player() return { id = 1, name = "Alice" } end
local function _entry(kind) return { kind = kind or "item", product_id = 101 } end
local function _rebuildable(choice)
  choice.builder.build = function()
    return { title="T", body_lines={}, options={{}}, allow_cancel=true, cancel_label="X",
             active_tab="item", page_index=1, page_count=1, owner_role_id=1, meta={} }
  end
end

describe("market purchase_settlement.resolve", function()
  it("deferred fulfillment keeps market open", function()
    _with_modules(_base_overrides(), function(settlement, choice)
      _rebuildable(choice)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), { ok = true, deferred_fulfillment = true })
      assert(v.keep_open == true, "deferred should keep open")
    end)
  end)

  it("item fulfilled_now keeps market open", function()
    _with_modules(_base_overrides(), function(settlement, choice)
      _rebuildable(choice)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), { ok = true, fulfilled_now = true })
      assert(v.keep_open == true, "item fulfilled should keep open")
    end)
  end)

  it("non-item fulfilled_now does not keep open", function()
    _with_modules(_base_overrides(), function(settlement)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("non_item"), { ok = true, fulfilled_now = true })
      assert(v.keep_open == false, "non-item fulfilled should not keep open")
    end)
  end)

  it("item fulfilled with full inventory emits feedback and keeps open", function()
    local emitted = false
    _with_modules(_base_overrides(), function(settlement, choice)
      _rebuildable(choice)
      choice.feedback.emit_inventory_full = function() emitted = true end
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"),
        { ok = true, fulfilled_now = true, inventory_full_after = true })
      assert(v.keep_open == true, "should keep open")
      assert(emitted, "should emit inventory full feedback")
    end)
  end)

  it("failure keeps open when rebuild succeeds", function()
    _with_modules(_base_overrides(), function(settlement, choice)
      _rebuildable(choice)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), { ok = false, reason = "not_enough_coins" })
      assert(v.keep_open == true, "failure + rebuild should keep open")
    end)
  end)

  it("failure does not keep open when rebuild fails", function()
    _with_modules(_base_overrides(), function(settlement, choice)
      choice.builder.build = function() return nil end
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), { ok = false })
      assert(v.keep_open == false, "failure + failed rebuild should not keep open")
    end)
  end)

  it("need_choice intent dispatches open_choice and keeps open", function()
    local opened = false
    local overrides = _base_overrides()
    overrides["src.rules.ports.intent_output"] = {
      open_choice = function(_, spec) opened = true; return spec end,
      push_popup = function() return true end,
    }
    _with_modules(overrides, function(settlement)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"),
        { ok = nil, intent = { kind = "need_choice", choice_spec = { kind = "sub" } } })
      assert(v.keep_open == true, "need_choice intent should keep open")
      assert(opened, "should dispatch open_choice")
    end)
  end)

  it("no intent does not keep open", function()
    _with_modules(_base_overrides(), function(settlement)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), { ok = nil })
      assert(v.keep_open == false, "no intent should not keep open")
    end)
  end)

  it("non-table result does not keep open", function()
    _with_modules(_base_overrides(), function(settlement)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), "some_string")
      assert(v.keep_open == false, "non-table should not keep open")
    end)
  end)
end)
