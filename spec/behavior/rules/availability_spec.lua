local availability = require("src.rules.items.availability")
local item_ids = require("src.config.gameplay.item_ids")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- normalize_integer_field


-- requires_followup_choice


-- resolve_offer_in_phases


-- can_auto_consider_item


-- mark_effect_group_used


-- can_offer_in_phase: target item with no registry


-- analyze_offer

describe("domain availability coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("normalize_integer_field nil not required returns nil", function()
    local target = {}
    local result = availability.normalize_integer_field(target, "missing_key", "choice", nil, false)
    _assert_eq(result, nil, "nil value with required=false should return nil")
  end)

  it("normalize_integer_field nil required asserts", function()
    local target = {}
    local ok = pcall(function()
      availability.normalize_integer_field(target, "missing_key", "choice", nil, true)
    end)
    _assert_eq(ok, false, "nil value with required=true should assert")
  end)

  it("normalize_integer_field numeric converts", function()
    local target = { count = 3 }
    local result = availability.normalize_integer_field(target, "count", "choice", nil, false)
    _assert_eq(result, 3, "numeric value should be converted and returned")
    _assert_eq(target.count, 3, "field should be updated in target")
  end)

  it("requires_followup_choice missile returns true", function()
    _assert_eq(availability.requires_followup_choice(item_ids.missile), true,
      "missile should require followup choice")
  end)

  it("requires_followup_choice unknown returns false", function()
    _assert_eq(availability.requires_followup_choice("unknown_item_id"), false,
      "unknown item should not require followup choice")
  end)

  it("requires_followup_choice roadblock returns true", function()
    _assert_eq(availability.requires_followup_choice(item_ids.roadblock), true,
      "roadblock should require followup choice")
  end)

  it("resolve_offer_in_phases non-table cfg returns nil", function()
    local result = availability.resolve_offer_in_phases("item_id", nil)
    _assert_eq(result, nil, "nil cfg should return nil")
  end)

  it("resolve_offer_in_phases empty offer returns nil", function()
    local result = availability.resolve_offer_in_phases("item_id", { offer_in_phases = {} })
    _assert_eq(result, nil, "empty offer_in_phases should return nil")
  end)

  it("resolve_offer_in_phases non-table offer returns nil", function()
    local result = availability.resolve_offer_in_phases("item_id", { offer_in_phases = "pre_action" })
    _assert_eq(result, nil, "non-table offer_in_phases should return nil")
  end)

  it("resolve_offer_in_phases valid table returns it", function()
    local phases = { "pre_action", "pre_move" }
    local result = availability.resolve_offer_in_phases("item_id", { offer_in_phases = phases })
    _assert_eq(result, phases, "valid offer_in_phases should be returned")
  end)

  it("can_auto_consider_item no cfg returns false", function()
    local result = availability.can_auto_consider_item("nonexistent_item_id_xyz", "pre_action", nil)
    _assert_eq(result, false, "missing item cfg should return false")
  end)

  it("can_auto_consider_item with cfg and phase", function()
    local cfg = { offer_in_phases = { "pre_action" } }
    _assert_eq(availability.can_auto_consider_item("any_id", "pre_action", cfg), true,
      "matching phase should return true")
  end)

  it("can_auto_consider_item with cfg nil phase", function()
    local cfg = { offer_in_phases = { "pre_action" } }
    _assert_eq(availability.can_auto_consider_item("any_id", nil, cfg), true,
      "nil phase with allow_missing should return true via auto consider")
  end)

  it("mark_effect_group_used no cfg is noop", function()
    local game = { turn = { used_effect_groups = {} } }
    availability.mark_effect_group_used(game, "nonexistent_item_xyz")
    _assert_eq(next(game.turn.used_effect_groups), nil, "no cfg should leave used_effect_groups empty")
  end)

  it("mark_effect_group_used no used_effect_groups is noop", function()
    local game = { turn = {} }
    availability.mark_effect_group_used(game, item_ids.missile)
    _assert_eq(game.turn.used_effect_groups, nil, "no used_effect_groups table should remain nil")
  end)

  it("mark_effect_group_used cfg has effect_group but no table is noop", function()
    -- remote_dice has effect_group = "dice_control"; game.turn has no used_effect_groups table
    local game = { turn = {} }
    availability.mark_effect_group_used(game, item_ids.remote_dice)
    _assert_eq(game.turn.used_effect_groups, nil, "nil used_effect_groups should stay nil when cfg has effect_group")
  end)

  it("can_offer_in_phase target item no registry returns false", function()
    local game = { turn = {} }
    local player = { id = 1001 }
    local can, reason = availability.can_offer_in_phase(game, player, item_ids.share_wealth, "pre_action")
    _assert_eq(can, false, "target item with no game registry should not be offerable")
    _assert_eq(reason, "special_condition_failed", "reason should be special_condition_failed")
  end)

  it("analyze_offer missing cfg returns cannot offer", function()
    local game = { turn = {} }
    local player = { id = 1001, inventory = { items = {} } }
    local result = availability.analyze_offer(game, player, "nonexistent_item_xyz", "pre_action")
    _assert_eq(result.can_offer, false, "missing cfg should report cannot offer")
    assert(result.deny_reason ~= nil, "should have deny reason")
  end)

  it("analyze_offer always includes requires_followup", function()
    local game = { turn = {} }
    local player = { id = 1001, inventory = { items = {} } }
    local result = availability.analyze_offer(game, player, item_ids.missile, nil)
    assert(type(result.requires_followup_choice) == "boolean", "should always include requires_followup_choice")
  end)
end)
