local support = require("support.domain_support")
local default_map = require("src.config.content.maps.default_map")
local gameplay_rules = require("src.config.gameplay.rules")
local availability = require("src.rules.items.availability")
local inventory = require("src.rules.items.inventory")

local function _new_game()
  return support.new_game({ map = default_map })
end

local _assert_eq = support.assert_eq

local function _test_mine_offer_in_pre_action_and_post_action_only()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.mine

  local pre_action = availability.analyze_offer(g, p, item_id, "pre_action")
  _assert_eq(pre_action.can_offer, true, "mine should be offered in pre_action")
  _assert_eq(pre_action.can_execute_now, true, "mine pre_action should execute immediately")
  _assert_eq(pre_action.requires_followup_choice, false, "mine should not require followup choice")

  local post_action = availability.analyze_offer(g, p, item_id, "post_action")
  _assert_eq(post_action.can_offer, true, "mine should be offered in post_action")
  _assert_eq(post_action.can_execute_now, true, "mine post_action should execute immediately")
  _assert_eq(post_action.requires_followup_choice, false, "mine post_action should not require followup choice")

  local pre_move = availability.analyze_offer(g, p, item_id, "pre_move")
  _assert_eq(pre_move.can_offer, false, "mine should not be offered outside declared offer phases")
  _assert_eq(pre_move.deny_reason, "offer_in_phases_not_allowed", "mine undeclared phase deny reason")
end

local function _test_roadblock_offer_in_pre_action_and_post_action()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.roadblock

  local pre_action = availability.analyze_offer(g, p, item_id, "pre_action")
  _assert_eq(pre_action.can_offer, true, "roadblock should be offered in pre_action")
  _assert_eq(pre_action.requires_followup_choice, true, "roadblock pre_action should require followup choice")

  local post_action = availability.analyze_offer(g, p, item_id, "post_action")
  _assert_eq(post_action.can_offer, true, "roadblock should be offered in post_action")
  _assert_eq(post_action.requires_followup_choice, true, "roadblock post_action should require followup choice")
end

local function _test_dice_multiplier_offer_only_in_pre_action()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.dice_multiplier

  local pre_action = availability.analyze_offer(g, p, item_id, "pre_action")
  _assert_eq(pre_action.can_offer, true, "dice_multiplier should be offered in pre_action")

  local post_action = availability.analyze_offer(g, p, item_id, "post_action")
  _assert_eq(post_action.can_offer, false, "dice_multiplier should not be offered in post_action")
  _assert_eq(post_action.deny_reason, "offer_in_phases_not_allowed", "dice_multiplier post_action deny reason")
end

local function _test_missing_offer_in_phases_does_not_fallback_to_timing()
  local g = _new_game()
  local p = g:current_player()
  local item_id = 999001
  local original_cfg = inventory.cfg

  support.with_patches({
    {
      target = inventory,
      key = "cfg",
      value = function(target_item_id)
        if target_item_id == item_id then
          return {
            id = item_id,
            name = "timing_only_item",
            timing = "pre_action",
          }
        end
        return original_cfg(target_item_id)
      end,
    },
  }, function()
    local pre_action = availability.analyze_offer(g, p, item_id, "pre_action")
    _assert_eq(pre_action.can_offer, false, "item without offer_in_phases should not use timing fallback")
    _assert_eq(pre_action.deny_reason, "offer_in_phases_not_allowed", "missing offer_in_phases deny reason")

    local post_action = availability.analyze_offer(g, p, item_id, "post_action")
    _assert_eq(post_action.can_offer, false, "item without offer_in_phases should stay hidden in post_action")
    _assert_eq(post_action.deny_reason, "offer_in_phases_not_allowed", "missing offer_in_phases deny reason")
  end)
end

local function _test_followup_choice_flags_for_remote_and_roadblock()
  local g = _new_game()
  local p = g:current_player()

  local remote = availability.analyze_offer(g, p, gameplay_rules.item_ids.remote_dice, "pre_action")
  _assert_eq(remote.can_offer, true, "remote_dice should be offered in pre_action")
  _assert_eq(remote.requires_followup_choice, true, "remote_dice should require followup choice")
  _assert_eq(remote.can_execute_now, false, "remote_dice should not execute immediately")

  local roadblock = availability.analyze_offer(g, p, gameplay_rules.item_ids.roadblock, "post_action")
  _assert_eq(roadblock.requires_followup_choice, true, "roadblock should require followup choice")
end

local function _test_triggered_cards_stay_hidden_from_active_windows()
  local g = _new_game()
  local p = g:current_player()

  local free_rent = availability.analyze_offer(g, p, gameplay_rules.item_ids.free_rent, "pre_action")
  _assert_eq(free_rent.can_offer, false, "free_rent should stay hidden in pre_action")

  local strong = availability.analyze_offer(g, p, gameplay_rules.item_ids.strong, "post_action")
  _assert_eq(strong.can_offer, false, "strong should stay hidden in post_action")

  local tax_free = availability.analyze_offer(g, p, gameplay_rules.item_ids.tax_free, "pre_action")
  _assert_eq(tax_free.can_offer, false, "tax_free should stay hidden in pre_action")

  local steal = availability.analyze_offer(g, p, gameplay_rules.item_ids.steal, "post_action")
  _assert_eq(steal.can_offer, false, "steal should stay hidden in post_action")
end

return {
  name = "item_availability_matrix",
  tests = {
    {
      name = "roadblock_offer_in_pre_action_and_post_action",
      run = _test_roadblock_offer_in_pre_action_and_post_action,
    },
    {
      name = "mine_offer_in_pre_action_and_post_action_only",
      run = _test_mine_offer_in_pre_action_and_post_action_only,
    },
    { name = "dice_multiplier_offer_only_in_pre_action", run = _test_dice_multiplier_offer_only_in_pre_action },
    {
      name = "missing_offer_in_phases_does_not_fallback_to_timing",
      run = _test_missing_offer_in_phases_does_not_fallback_to_timing,
    },
    { name = "followup_choice_flags_for_remote_and_roadblock", run = _test_followup_choice_flags_for_remote_and_roadblock },
    { name = "triggered_cards_stay_hidden_from_active_windows", run = _test_triggered_cards_stay_hidden_from_active_windows },
  },
}
