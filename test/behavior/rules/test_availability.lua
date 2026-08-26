local lu = require("luaunit")
local availability = require("src.rules.items.availability")
local item_ids = require("src.config.gameplay.item_ids")
local _config_reset = require("test.support.config_reset")

-- 原生 LuaUnit 迁移:describe/it 拍平为文件级 TestAvailability 类,
-- before_each → setUp(_config_reset 提升为文件级共享),断言切到 lu.assertXxx,
-- 用例数与改写前一一对应(22 例)。

local function _assert_eq(a, b, msg)
  lu.assertEquals(a, b, msg)
end

TestAvailability = {}

function TestAvailability:setUp()
  _config_reset.reset_all()
end

function TestAvailability:test_normalize_integer_field_nil_not_required_returns_nil()
  local target = {}
  local result = availability.normalize_integer_field(target, "missing_key", "choice", nil, false)
  _assert_eq(result, nil, "nil value with required=false should return nil")
end

function TestAvailability:test_normalize_integer_field_nil_required_asserts()
  local target = {}
  local ok, err = pcall(function()
    availability.normalize_integer_field(target, "missing_key", "choice", nil, true)
  end)
  _assert_eq(ok, false, "nil value with required=true should assert")
  -- #293:缺省 field_prefix 回落 "meta"(→ nil 变异)进断言文案。
  lu.assertEvalToTrue(tostring(err):find("meta.missing_key", 1, true) ~= nil,
    "assert should name the meta field; got: " .. tostring(err))
end

function TestAvailability:test_normalize_integer_field_numeric_converts()
  local target = { count = 3 }
  local result = availability.normalize_integer_field(target, "count", "choice", nil, false)
  _assert_eq(result, 3, "numeric value should be converted and returned")
  _assert_eq(target.count, 3, "field should be updated in target")
end

function TestAvailability:test_requires_followup_choice_missile_returns_true()
  _assert_eq(availability.requires_followup_choice(item_ids.missile), true,
    "missile should require followup choice")
end

function TestAvailability:test_requires_followup_choice_unknown_returns_false()
  _assert_eq(availability.requires_followup_choice("unknown_item_id"), false,
    "unknown item should not require followup choice")
end

function TestAvailability:test_requires_followup_choice_roadblock_returns_true()
  _assert_eq(availability.requires_followup_choice(item_ids.roadblock), true,
    "roadblock should require followup choice")
end

function TestAvailability:test_resolve_offer_in_phases_non_table_cfg_returns_nil()
  local result = availability.resolve_offer_in_phases("item_id", nil)
  _assert_eq(result, nil, "nil cfg should return nil")
end

function TestAvailability:test_resolve_offer_in_phases_empty_offer_returns_nil()
  local result = availability.resolve_offer_in_phases("item_id", { offer_in_phases = {} })
  _assert_eq(result, nil, "empty offer_in_phases should return nil")
end

function TestAvailability:test_resolve_offer_in_phases_non_table_offer_returns_nil()
  local result = availability.resolve_offer_in_phases("item_id", { offer_in_phases = "pre_action" })
  _assert_eq(result, nil, "non-table offer_in_phases should return nil")
end

function TestAvailability:test_resolve_offer_in_phases_valid_table_returns_it()
  local phases = { "pre_action", "pre_move" }
  local result = availability.resolve_offer_in_phases("item_id", { offer_in_phases = phases })
  _assert_eq(result, phases, "valid offer_in_phases should be returned")
end

function TestAvailability:test_can_auto_consider_item_no_cfg_returns_false()
  local result = availability.can_auto_consider_item("nonexistent_item_id_xyz", "pre_action", nil)
  _assert_eq(result, false, "missing item cfg should return false")
end

function TestAvailability:test_can_auto_consider_item_with_cfg_and_phase()
  local cfg = { offer_in_phases = { "pre_action" } }
  _assert_eq(availability.can_auto_consider_item("any_id", "pre_action", cfg), true,
    "matching phase should return true")
end

function TestAvailability:test_can_auto_consider_item_with_cfg_nil_phase()
  local cfg = { offer_in_phases = { "pre_action" } }
  _assert_eq(availability.can_auto_consider_item("any_id", nil, cfg), true,
    "nil phase with allow_missing should return true via auto consider")
end

function TestAvailability:test_mark_effect_group_used_no_cfg_is_noop()
  local game = { turn = { used_effect_groups = {} } }
  availability.mark_effect_group_used(game, "nonexistent_item_xyz")
  _assert_eq(next(game.turn.used_effect_groups), nil, "no cfg should leave used_effect_groups empty")
end

function TestAvailability:test_mark_effect_group_used_no_used_effect_groups_is_noop()
  local game = { turn = {} }
  availability.mark_effect_group_used(game, item_ids.missile)
  _assert_eq(game.turn.used_effect_groups, nil, "no used_effect_groups table should remain nil")
end

function TestAvailability:test_mark_effect_group_used_cfg_has_effect_group_but_no_table_is_noop()
  -- remote_dice has effect_group = "dice_control"; game.turn has no used_effect_groups table
  local game = { turn = {} }
  availability.mark_effect_group_used(game, item_ids.remote_dice)
  _assert_eq(game.turn.used_effect_groups, nil, "nil used_effect_groups should stay nil when cfg has effect_group")
end

function TestAvailability:test_can_offer_in_phase_target_item_no_registry_returns_false()
  local game = { turn = {} }
  local player = { id = 1001 }
  local can, reason = availability.can_offer_in_phase(game, player, item_ids.share_wealth, "pre_action")
  _assert_eq(can, false, "target item with no game registry should not be offerable")
  _assert_eq(reason, "special_condition_failed", "reason should be special_condition_failed")
end

function TestAvailability:test_analyze_offer_missing_cfg_returns_cannot_offer()
  local game = { turn = {} }
  local player = { id = 1001, inventory = { items = {} } }
  local result = availability.analyze_offer(game, player, "nonexistent_item_xyz", "pre_action")
  _assert_eq(result.can_offer, false, "missing cfg should report cannot offer")
  lu.assertNotNil(result.deny_reason, "should have deny reason")
end

function TestAvailability:test_analyze_offer_always_includes_requires_followup()
  local game = { turn = {} }
  local player = { id = 1001, inventory = { items = {} } }
  local result = availability.analyze_offer(game, player, item_ids.missile, nil)
  lu.assertIsBoolean(result.requires_followup_choice, "should always include requires_followup_choice")
end

-- 穷神卡是负面道具：所有对手都有天使守护时应无合适目标（unusable_card_tip_001）。
function TestAvailability:test_can_offer_in_phase_poor_card_denied_when_all_opponents_have_angel()
  local bootstrap = require("src.rules.bootstrap")
  local deity_ops = require("src.player.actions.deity")
  local opponent = { id = 1002, status = { deity = { type = "angel", remaining = 5 } } }
  local game = {
    players = { { id = 1001 }, opponent },
    registries = bootstrap.create_registries(),
    turn = {},
  }
  game.player_has_deity = deity_ops.player_has_deity
  game.angel_immune_to_item = deity_ops.angel_immune_to_item
  local can, reason = availability.can_offer_in_phase(game, game.players[1], item_ids.poor, "pre_action")
  _assert_eq(can, false, "angel-protected opponents should leave no target for poor card")
  _assert_eq(reason, "special_condition_failed", "reason should be special_condition_failed")
end

-- #205:强征卡现金检查拆为独立拒绝原因,与「没有合适目标」区分开。
function TestAvailability:test_can_offer_in_phase_strong_card_short_of_cash_returns_insufficient_funds()
  local support = require("test.support.shared_support")
  local g = support.new_game()
  local p1, p2 = g.players[1], g.players[2]
  local idx, tile_ref = support.first_land_tile(g.board)
  g:set_tile_owner(tile_ref, p2.id)
  g:set_tile_level(tile_ref, 1)
  g:update_player_position(p1, idx)
  g:set_player_cash(p1, 0)
  local can, reason = availability.can_offer_in_phase(g, p1, item_ids.strong, "pre_action")
  _assert_eq(can, false, "cash-short strong card should not be offerable")
  _assert_eq(reason, "insufficient_funds", "cash failure gets its own deny reason")
end

function TestAvailability:test_can_offer_in_phase_strong_card_without_rent_context_stays_special_condition_failed()
  local support = require("test.support.shared_support")
  local g = support.new_game()
  local can, reason = availability.can_offer_in_phase(g, g.players[1], item_ids.strong, "pre_action")
  _assert_eq(can, false, "no opponent tile underfoot means no strong-card target")
  _assert_eq(reason, "special_condition_failed", "missing rent context stays the no-target reason")
end



function TestAvailability:test_offer_phase_missing_phase_param_is_denied()
  -- #293:offer_window.allowed 的 allow_missing_phase(false→true 变异)未测——
  -- 带 offer_in_phases 的卡在 phase=nil 时必须被拒。
  local support = require("test.support.shared_support")
  local g = support.new_game()
  local can, reason = availability.can_offer_in_phase(g, g.players[1], item_ids.remote_dice, nil)
  _assert_eq(can, false, "offer_in_phases item with nil phase must be denied")
  _assert_eq(reason, "offer_in_phases_not_allowed", "denial reason should be the phase restriction")
end

return TestAvailability
