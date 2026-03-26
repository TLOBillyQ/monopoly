local support = require("support.domain_support")
local default_map = require("src.config.content.maps.default_map")
local item_ids = require("src.config.gameplay.item_ids")
local availability = require("src.rules.items.availability")
local inventory = require("src.rules.items.inventory")

local function _new_game()
  return support.new_game({ map = default_map })
end

local _assert_eq = support.assert_eq

local function _test_mine_offer_in_pre_action_and_post_action_only()
  local g = _new_game()
  local p = g:current_player()
  local item_id = item_ids.mine

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
  local item_id = item_ids.roadblock

  local pre_action = availability.analyze_offer(g, p, item_id, "pre_action")
  _assert_eq(pre_action.can_offer, true, "roadblock should be offered in pre_action")
  _assert_eq(pre_action.requires_followup_choice, true, "roadblock pre_action should require followup choice")

  local post_action = availability.analyze_offer(g, p, item_id, "post_action")
  _assert_eq(post_action.can_offer, true, "roadblock should be offered in post_action")
  _assert_eq(post_action.requires_followup_choice, true, "roadblock post_action should require followup choice")
end

local function _test_dice_multiplier_offer_only_in_pre_move()
  local g = _new_game()
  local p = g:current_player()
  local item_id = item_ids.dice_multiplier

  local pre_move = availability.analyze_offer(g, p, item_id, "pre_move")
  _assert_eq(pre_move.can_offer, true, "dice_multiplier should be offered in pre_move")

  local pre_action = availability.analyze_offer(g, p, item_id, "pre_action")
  _assert_eq(pre_action.can_offer, false, "dice_multiplier should not be offered in pre_action")
  _assert_eq(pre_action.deny_reason, "offer_in_phases_not_allowed", "dice_multiplier pre_action deny reason")

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

  local remote = availability.analyze_offer(g, p, item_ids.remote_dice, "pre_action")
  _assert_eq(remote.can_offer, true, "remote_dice should be offered in pre_action")
  _assert_eq(remote.requires_followup_choice, true, "remote_dice should require followup choice")
  _assert_eq(remote.can_execute_now, false, "remote_dice should not execute immediately")

  local roadblock = availability.analyze_offer(g, p, item_ids.roadblock, "post_action")
  _assert_eq(roadblock.requires_followup_choice, true, "roadblock should require followup choice")
end

local function _with_offer_phase_cfg(item_ids_to_patch, fn)
  local original_cfg = inventory.cfg
  support.with_patches({
    {
      target = inventory,
      key = "cfg",
      value = function(item_id)
        local cfg = original_cfg(item_id)
        if item_ids_to_patch[item_id] ~= true or type(cfg) ~= "table" then
          return cfg
        end
        local patched = {}
        for key, value in pairs(cfg) do
          patched[key] = value
        end
        patched.offer_in_phases = { "post_action" }
        return patched
      end,
    },
  }, fn)
end

local function _test_trigger_timing_allowed_handles_missing_and_unknown_inputs()
  _assert_eq(availability.trigger_timing_allowed(nil, "pre_action", true), true, "missing phase should honor allow_missing_phase=true")
  _assert_eq(availability.trigger_timing_allowed(nil, "pre_action", false), false, "missing phase should honor allow_missing_phase=false")
  _assert_eq(availability.trigger_timing_allowed("unknown_phase", "pre_action", true), false, "unknown phase should be rejected")
  _assert_eq(availability.trigger_timing_allowed("pre_action", nil, false), false, "missing timing should be rejected")
  _assert_eq(availability.trigger_timing_allowed("pre_action", "unknown_timing", false), false, "unknown timing should be rejected")
  _assert_eq(availability.trigger_timing_allowed("pre_action", "pre_action", false), true, "pre_action timing should be allowed in pre_action phase")
  _assert_eq(availability.trigger_timing_allowed("pre_action", "turn", false), true, "turn timing should be allowed in pre_action phase")
  _assert_eq(availability.trigger_timing_allowed("post_action", "pre_action", false), false, "pre_action timing should be rejected in post_action phase")
  _assert_eq(availability.trigger_timing_allowed("post_action", "post_action", false), true, "post_action timing should be allowed in post_action phase")
  _assert_eq(availability.trigger_timing_allowed("post_action", "turn", false), true, "turn timing should be allowed in post_action phase")
end

local function _test_rent_response_cards_require_land_tile_and_other_owner()
  _with_offer_phase_cfg({
    [item_ids.free_rent] = true,
  }, function()
    local g = _new_game()
    local p = g:current_player()
    local item_id = item_ids.free_rent

    g.board = nil
    local no_board_ok, no_board_reason = availability.can_offer_in_phase(g, p, item_id, "post_action")
    _assert_eq(no_board_ok, false, "rent response card should be unavailable without board")
    _assert_eq(no_board_reason, "special_condition_failed", "missing board should fail through special condition")

    g.board = _new_game().board
    g:update_player_position(p, 9999)
    local no_tile_ok, no_tile_reason = availability.can_offer_in_phase(g, p, item_id, "post_action")
    _assert_eq(no_tile_ok, false, "rent response card should be unavailable without tile")
    _assert_eq(no_tile_reason, "special_condition_failed", "missing tile should fail through special condition")

    local start_tile = assert(g.board:get_tile(1), "default map should expose start tile")
    g:update_player_position(p, 1)
    local non_land_ok, non_land_reason = availability.can_offer_in_phase(g, p, item_id, "post_action")
    _assert_eq(non_land_ok, false, "rent response card should be unavailable on non-land tile")
    _assert_eq(non_land_reason, "special_condition_failed", "non-land tile should fail through special condition")

    local land_index = 3
    local land_tile = assert(g.board:get_tile(land_index), "default map should expose land tile for rent response test")
    g:update_player_position(p, land_index)
    g:set_tile_owner(land_tile, p.id)
    g:set_player_property(p, land_tile.id, true)
    local self_owned_ok, self_owned_reason = availability.can_offer_in_phase(g, p, item_id, "post_action")
    _assert_eq(self_owned_ok, false, "rent response card should be unavailable on self-owned land")
    _assert_eq(self_owned_reason, "special_condition_failed", "self-owned land should fail through special condition")

    g:set_player_property(p, land_tile.id, false)
    g:set_tile_owner(land_tile, g.players[2].id)
    local rival_owned_ok, rival_owned_reason = availability.can_offer_in_phase(g, p, item_id, "post_action")
    _assert_eq(rival_owned_ok, true, "free_rent should be available on rival-owned land")
    _assert_eq(rival_owned_reason, "ok", "free_rent should pass special condition on rival-owned land")
  end)
end

local function _test_strong_card_requires_enough_balance_for_rent_response()
  _with_offer_phase_cfg({
    [item_ids.strong] = true,
  }, function()
    local g = _new_game()
    local p = g:current_player()
    local land_index = 3
    local land_tile = assert(g.board:get_tile(land_index), "default map should expose land tile for strong-card test")
    g:update_player_position(p, land_index)
    g:set_tile_owner(land_tile, g.players[2].id)
    g:set_tile_level(land_tile, 2)
    local rent_value = require("src.rules.commerce.property_value").total_invested(land_tile, 2)

    g:set_player_cash(p, rent_value)
    local exact_cash_ok, exact_cash_reason = availability.can_offer_in_phase(g, p, item_ids.strong, "post_action")
    _assert_eq(exact_cash_ok, true, "strong card should be available when balance equals rent value")
    _assert_eq(exact_cash_reason, "ok", "strong card should be allowed when balance equals rent value")

    g:set_player_cash(p, rent_value - 1)
    local low_cash_ok, low_cash_reason = availability.can_offer_in_phase(g, p, item_ids.strong, "post_action")
    _assert_eq(low_cash_ok, false, "strong card should be unavailable when balance is below rent value")
    _assert_eq(low_cash_reason, "special_condition_failed", "strong card should fail special condition when balance is low")
  end)
end

local function _test_triggered_cards_stay_hidden_from_active_windows()
  local g = _new_game()
  local p = g:current_player()

  local free_rent = availability.analyze_offer(g, p, item_ids.free_rent, "pre_action")
  _assert_eq(free_rent.can_offer, false, "free_rent should stay hidden in pre_action")

  local strong = availability.analyze_offer(g, p, item_ids.strong, "post_action")
  _assert_eq(strong.can_offer, false, "strong should stay hidden in post_action")

  local tax_free = availability.analyze_offer(g, p, item_ids.tax_free, "pre_action")
  _assert_eq(tax_free.can_offer, false, "tax_free should stay hidden in pre_action")

  local steal = availability.analyze_offer(g, p, item_ids.steal, "post_action")
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
    { name = "dice_multiplier_offer_only_in_pre_move", run = _test_dice_multiplier_offer_only_in_pre_move },
    {
      name = "missing_offer_in_phases_does_not_fallback_to_timing",
      run = _test_missing_offer_in_phases_does_not_fallback_to_timing,
    },
    { name = "followup_choice_flags_for_remote_and_roadblock", run = _test_followup_choice_flags_for_remote_and_roadblock },
    {
      name = "trigger_timing_allowed_handles_missing_and_unknown_inputs",
      run = _test_trigger_timing_allowed_handles_missing_and_unknown_inputs,
    },
    {
      name = "rent_response_cards_require_land_tile_and_other_owner",
      run = _test_rent_response_cards_require_land_tile_and_other_owner,
    },
    {
      name = "strong_card_requires_enough_balance_for_rent_response",
      run = _test_strong_card_requires_enough_balance_for_rent_response,
    },
    { name = "triggered_cards_stay_hidden_from_active_windows", run = _test_triggered_cards_stay_hidden_from_active_windows },
  },
}
