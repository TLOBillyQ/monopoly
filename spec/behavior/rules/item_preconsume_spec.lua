local item_preconsume_policy = require("src.rules.choice.item_preconsume_policy")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _assert_true(value, msg)
  assert(value == true, tostring(msg) .. ": expected true, got " .. tostring(value))
end

local function _assert_false(value, msg)
  assert(value == false, tostring(msg) .. ": expected false, got " .. tostring(value))
end

local function _assert_table(value, msg)
  assert(type(value) == "table", tostring(msg) .. ": expected table, got " .. type(value))
end

describe("item_preconsume_crap_coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("decorate_followup_choice_spec: empty spec gets meta added", function()
    local choice_spec = {}
    local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec)

    _assert_table(result, "result is table")
    _assert_table(result.meta, "meta added to spec")
    _assert_true(result.meta.item_preconsumed, "item_preconsumed set to true")
  end)

  it("decorate_followup_choice_spec: existing meta not overwritten", function()
    local choice_spec = {
      meta = {
        item_preconsumed = false,
        custom_field = "custom_value"
      }
    }
    local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec)

    _assert_table(result.meta, "meta preserved")
    _assert_true(result.meta.item_preconsumed, "item_preconsumed set to true")
    _assert_eq(result.meta.custom_field, "custom_value", "custom field preserved")
  end)

  it("decorate_followup_choice_spec: cancel disabled when function runs", function()
    local choice_spec = {
      allow_cancel = true,
      cancel_label = "Cancel Action"
    }
    local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec)

    _assert_false(result.allow_cancel, "allow_cancel set to false")
    _assert_eq(result.cancel_label, nil, "cancel_label set to nil")
  end)

  it("decorate_followup_choice_spec: context-only flag handled", function()
    local choice_spec = {}
    local context = { context_only = true }
    local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec, context)

    _assert_table(result.meta, "meta created")
    _assert_true(result.meta.item_preconsumed, "item_preconsumed set despite extra context fields")
  end)

  it("decorate_followup_choice_spec: context fields merged into spec", function()
    local choice_spec = {}
    local context = {
      item_id = "item_123",
      player_id = "player_456"
    }
    local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec, context)

    _assert_table(result.meta, "meta created")
    _assert_eq(result.meta.item_id, "item_123", "item_id merged from context")
    _assert_eq(result.meta.player_id, "player_456", "player_id merged from context")
  end)

end)
