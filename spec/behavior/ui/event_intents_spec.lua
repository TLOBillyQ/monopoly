local event_intents = require("src.ui.input.event_intents")

-- warn_label 用 spec_synthetic：负路径 warn 文案带保留前缀，
-- 由 docs/reports/behavior_warns_data.lua 白名单整体豁免。

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_state(opts)
  opts = opts or {}
  return {
    ui_runtime = {
      ui_model = opts.model,
      pending_choice_selected_option_id = opts.selected_option,
      choice_visible_option_ids = opts.visible_ids,
    },
  }
end

describe("event_intents.choice_confirm_intent", function()
  it("returns nil when no choice in model", function()
    local state = _make_state({ model = {} })
    local result = event_intents.choice_confirm_intent(state, "spec_synthetic")
    assert(result == nil, "should return nil when no choice")
  end)

  it("returns choice_select with pending option", function()
    local state = _make_state({
      model = { choice = { id = "c1" } },
      selected_option = "opt_a",
    })
    local result = event_intents.choice_confirm_intent(state, "spec_synthetic")
    assert(result ~= nil, "should return intent")
    _assert_eq(result.type, "choice_select", "type")
    _assert_eq(result.choice_id, "c1", "choice_id")
    _assert_eq(result.option_id, "opt_a", "option_id")
  end)

  it("falls back to first visible option when no pending", function()
    local state = _make_state({
      model = { choice = { id = "c2" } },
      visible_ids = { "first", "second" },
    })
    local result = event_intents.choice_confirm_intent(state, "spec_synthetic")
    assert(result ~= nil, "should return intent")
    _assert_eq(result.option_id, "first", "should use first visible option")
  end)

  it("returns nil when no pending and no visible options", function()
    local state = _make_state({
      model = { choice = { id = "c3" } },
    })
    local result = event_intents.choice_confirm_intent(state, "spec_synthetic")
    assert(result == nil, "should return nil when no option available")
  end)
end)

describe("event_intents.choice_cancel_intent", function()
  it("returns nil when no choice", function()
    local state = _make_state({ model = {} })
    assert(event_intents.choice_cancel_intent(state, "spec_synthetic") == nil,
      "should return nil without choice")
  end)

  it("returns cancel intent when allowed", function()
    local state = _make_state({ model = { choice = { id = "c1" } } })
    local result = event_intents.choice_cancel_intent(state, "spec_synthetic")
    assert(result ~= nil, "should return intent")
    _assert_eq(result.type, "choice_cancel", "type")
    _assert_eq(result.choice_id, "c1", "choice_id")
  end)

  it("returns nil when cancel disallowed", function()
    local state = _make_state({ model = { choice = { id = "c1", allow_cancel = false } } })
    assert(event_intents.choice_cancel_intent(state, "spec_synthetic") == nil,
      "should return nil when allow_cancel is false")
  end)
end)

describe("event_intents.choice_select_intent", function()
  it("returns nil when no choice", function()
    local state = _make_state({ model = {} })
    assert(event_intents.choice_select_intent(state, 1, "spec_synthetic") == nil,
      "should return nil without choice")
  end)

  it("returns select intent by index via visible_ids", function()
    local state = _make_state({
      model = { choice = { id = "c1", options = {} } },
      visible_ids = { "opt_x", "opt_y" },
    })
    local result = event_intents.choice_select_intent(state, 1, "spec_synthetic")
    assert(result ~= nil, "should return intent")
    _assert_eq(result.type, "choice_select", "type")
    _assert_eq(result.option_id, "opt_x", "option_id")
  end)

  it("returns select intent by index via choice options", function()
    local state = _make_state({
      model = { choice = { id = "c1", options = { { id = "o1" }, { id = "o2" } } } },
    })
    local result = event_intents.choice_select_intent(state, 2, "spec_synthetic")
    assert(result ~= nil, "should return intent")
    _assert_eq(result.option_id, "o2", "option_id from choice options")
  end)
end)
