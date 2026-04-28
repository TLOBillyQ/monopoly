local availability = require("src.rules.items.availability")
local item_ids = require("src.config.gameplay.item_ids")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- normalize_integer_field

local function test_normalize_integer_field_nil_not_required_returns_nil()
  local target = {}
  local result = availability.normalize_integer_field(target, "missing_key", "choice", nil, false)
  _assert_eq(result, nil, "nil value with required=false should return nil")
end

local function test_normalize_integer_field_nil_required_asserts()
  local target = {}
  local ok = pcall(function()
    availability.normalize_integer_field(target, "missing_key", "choice", nil, true)
  end)
  _assert_eq(ok, false, "nil value with required=true should assert")
end

local function test_normalize_integer_field_numeric_converts()
  local target = { count = 3 }
  local result = availability.normalize_integer_field(target, "count", "choice", nil, false)
  _assert_eq(result, 3, "numeric value should be converted and returned")
  _assert_eq(target.count, 3, "field should be updated in target")
end

-- requires_followup_choice

local function test_requires_followup_choice_missile_returns_true()
  _assert_eq(availability.requires_followup_choice(item_ids.missile), true,
    "missile should require followup choice")
end

local function test_requires_followup_choice_unknown_returns_false()
  _assert_eq(availability.requires_followup_choice("unknown_item_id"), false,
    "unknown item should not require followup choice")
end

local function test_requires_followup_choice_roadblock_returns_true()
  _assert_eq(availability.requires_followup_choice(item_ids.roadblock), true,
    "roadblock should require followup choice")
end

-- resolve_offer_in_phases

local function test_resolve_offer_in_phases_non_table_cfg_returns_nil()
  local result = availability.resolve_offer_in_phases("item_id", nil)
  _assert_eq(result, nil, "nil cfg should return nil")
end

local function test_resolve_offer_in_phases_empty_offer_in_phases_returns_nil()
  local result = availability.resolve_offer_in_phases("item_id", { offer_in_phases = {} })
  _assert_eq(result, nil, "empty offer_in_phases should return nil")
end

local function test_resolve_offer_in_phases_non_table_offer_returns_nil()
  local result = availability.resolve_offer_in_phases("item_id", { offer_in_phases = "pre_action" })
  _assert_eq(result, nil, "non-table offer_in_phases should return nil")
end

local function test_resolve_offer_in_phases_valid_table_returns_it()
  local phases = { "pre_action", "pre_move" }
  local result = availability.resolve_offer_in_phases("item_id", { offer_in_phases = phases })
  _assert_eq(result, phases, "valid offer_in_phases should be returned")
end

-- can_auto_consider_item

local function test_can_auto_consider_item_no_cfg_returns_false()
  local result = availability.can_auto_consider_item("nonexistent_item_id_xyz", "pre_action", nil)
  _assert_eq(result, false, "missing item cfg should return false")
end

local function test_can_auto_consider_item_with_cfg_and_phase()
  local cfg = { offer_in_phases = { "pre_action" } }
  _assert_eq(availability.can_auto_consider_item("any_id", "pre_action", cfg), true,
    "matching phase should return true")
end

local function test_can_auto_consider_item_with_cfg_nil_phase()
  local cfg = { offer_in_phases = { "pre_action" } }
  _assert_eq(availability.can_auto_consider_item("any_id", nil, cfg), true,
    "nil phase with allow_missing should return true via auto consider")
end

-- mark_effect_group_used

local function test_mark_effect_group_used_no_cfg_is_noop()
  local game = { turn = { used_effect_groups = {} } }
  availability.mark_effect_group_used(game, "nonexistent_item_xyz")
  _assert_eq(next(game.turn.used_effect_groups), nil, "no cfg should leave used_effect_groups empty")
end

local function test_mark_effect_group_used_no_used_effect_groups_is_noop()
  local game = { turn = {} }
  availability.mark_effect_group_used(game, item_ids.missile)
  _assert_eq(game.turn.used_effect_groups, nil, "no used_effect_groups table should remain nil")
end

local function test_mark_effect_group_used_cfg_has_effect_group_but_no_table_is_noop()
  -- remote_dice has effect_group = "dice_control"; game.turn has no used_effect_groups table
  local game = { turn = {} }
  availability.mark_effect_group_used(game, item_ids.remote_dice)
  _assert_eq(game.turn.used_effect_groups, nil, "nil used_effect_groups should stay nil when cfg has effect_group")
end

-- can_offer_in_phase: target item with no registry

local function test_can_offer_in_phase_target_item_no_registry_returns_false()
  local game = { turn = {} }
  local player = { id = 1001 }
  local can, reason = availability.can_offer_in_phase(game, player, item_ids.share_wealth, "pre_action")
  _assert_eq(can, false, "target item with no game registry should not be offerable")
  _assert_eq(reason, "special_condition_failed", "reason should be special_condition_failed")
end

-- analyze_offer

local function test_analyze_offer_missing_cfg_returns_cannot_offer()
  local game = { turn = {} }
  local player = { id = 1001, inventory = { items = {} } }
  local result = availability.analyze_offer(game, player, "nonexistent_item_xyz", "pre_action")
  _assert_eq(result.can_offer, false, "missing cfg should report cannot offer")
  assert(result.deny_reason ~= nil, "should have deny reason")
end

local function test_analyze_offer_always_includes_requires_followup()
  local game = { turn = {} }
  local player = { id = 1001, inventory = { items = {} } }
  local result = availability.analyze_offer(game, player, item_ids.missile, nil)
  assert(type(result.requires_followup_choice) == "boolean", "should always include requires_followup_choice")
end

return {
  name = "domain availability coverage",
  tests = {
    { name = "normalize_integer_field nil not required returns nil", run = test_normalize_integer_field_nil_not_required_returns_nil },
    { name = "normalize_integer_field nil required asserts", run = test_normalize_integer_field_nil_required_asserts },
    { name = "normalize_integer_field numeric converts", run = test_normalize_integer_field_numeric_converts },
    { name = "requires_followup_choice missile returns true", run = test_requires_followup_choice_missile_returns_true },
    { name = "requires_followup_choice unknown returns false", run = test_requires_followup_choice_unknown_returns_false },
    { name = "requires_followup_choice roadblock returns true", run = test_requires_followup_choice_roadblock_returns_true },
    { name = "resolve_offer_in_phases non-table cfg returns nil", run = test_resolve_offer_in_phases_non_table_cfg_returns_nil },
    { name = "resolve_offer_in_phases empty offer returns nil", run = test_resolve_offer_in_phases_empty_offer_in_phases_returns_nil },
    { name = "resolve_offer_in_phases non-table offer returns nil", run = test_resolve_offer_in_phases_non_table_offer_returns_nil },
    { name = "resolve_offer_in_phases valid table returns it", run = test_resolve_offer_in_phases_valid_table_returns_it },
    { name = "can_auto_consider_item no cfg returns false", run = test_can_auto_consider_item_no_cfg_returns_false },
    { name = "can_auto_consider_item with cfg and phase", run = test_can_auto_consider_item_with_cfg_and_phase },
    { name = "can_auto_consider_item with cfg nil phase", run = test_can_auto_consider_item_with_cfg_nil_phase },
    { name = "mark_effect_group_used no cfg is noop", run = test_mark_effect_group_used_no_cfg_is_noop },
    { name = "mark_effect_group_used no used_effect_groups is noop", run = test_mark_effect_group_used_no_used_effect_groups_is_noop },
    { name = "mark_effect_group_used cfg has effect_group but no table is noop", run = test_mark_effect_group_used_cfg_has_effect_group_but_no_table_is_noop },
    { name = "can_offer_in_phase target item no registry returns false", run = test_can_offer_in_phase_target_item_no_registry_returns_false },
    { name = "analyze_offer missing cfg returns cannot offer", run = test_analyze_offer_missing_cfg_returns_cannot_offer },
    { name = "analyze_offer always includes requires_followup", run = test_analyze_offer_always_includes_requires_followup },
  },
}
