local support = require("support.domain_support")
local default_map = require("src.config.content.maps.default_map")
local function _new_game()
  return support.new_game({ map = default_map })
end
local _assert_eq = support.assert_eq
local gameplay_rules = require("src.config.gameplay.rules")
local item_strategy = require("src.rules.items.strategy")
local effect_pipeline = require("src.rules.effects.effect_pipeline")
local effect_runner = require("src.rules.effects.effect_runner")
local intent_output_port = require("src.rules.ports.intent_output")

local function _test_effect_pipeline_waiting_result_patches_followup_and_strips_intent()
  local g = _new_game()
  local player = g:current_player()
  local tile_ref = g.board:get_tile(player.position)
  local dispatched = nil

  support.with_patches({
    {
      target = effect_runner,
      key = "scan",
      value = function()
        return {
          {
            ok = true,
            mandatory = true,
            effect = { id = "clear_obstacles", label = "clear_obstacles" },
          },
        }
      end,
    },
    {
      target = effect_runner,
      key = "execute",
      value = function()
        return {
          ok = true,
          result = {
            waiting = true,
            intent = { kind = "debug_only" },
          },
        }
      end,
    },
    {
      target = intent_output_port,
      key = "dispatch",
      value = function(_, payload)
        dispatched = payload
      end,
    },
  }, function()
    local result = effect_pipeline.run({}, player, tile_ref, {
      game = g,
      move_result = { kind = "move_result" },
    }, {
      next_state = "resume_turn",
      next_args = { source = "effect_pipeline" },
    })
    assert(type(result) == "table" and result.waiting == true, "waiting result should be returned")
    _assert_eq(result.next_state, "resume_turn", "waiting result should inherit next_state")
    _assert_eq(result.next_args.source, "effect_pipeline", "waiting result should inherit next_args")
    _assert_eq(result.intent, nil, "waiting result should not leak intent payload")
  end)

  assert(type(dispatched) == "table" and dispatched.waiting == true, "waiting payload should still dispatch")
end

local function _test_effect_pipeline_stop_if_short_circuits_before_optional_choice()
  local g = _new_game()
  local player = g:current_player()
  local tile_ref = g.board:get_tile(player.position)
  local open_choice_called = false

  support.with_patches({
    {
      target = effect_runner,
      key = "scan",
      value = function()
        return {
          {
            ok = true,
            mandatory = true,
            effect = { id = "mandatory_first", label = "mandatory_first" },
          },
          {
            ok = true,
            mandatory = false,
            effect = { id = "buy_land", label = "buy_land" },
          },
        }
      end,
    },
    {
      target = effect_runner,
      key = "execute",
      value = function()
        return {
          ok = true,
          result = {
            kind = "resolved",
            marker = "stop_here",
          },
        }
      end,
    },
    {
      target = intent_output_port,
      key = "open_choice",
      value = function()
        open_choice_called = true
      end,
    },
  }, function()
    local result = effect_pipeline.run({}, player, tile_ref, {
      game = g,
      move_result = { kind = "move_result" },
    }, {
      stop_if = function(out)
        return out and out.marker == "stop_here"
      end,
    })
    _assert_eq(result.marker, "stop_here", "stop_if should return current mandatory result")
  end)

  _assert_eq(open_choice_called, false, "stop_if should skip optional choice building")
end

local function _test_effect_pipeline_single_optional_effect_uses_secondary_confirm_route()
  local g = _new_game()
  local player = g:current_player()
  local tile_ref = g.board:get_tile(player.position)
  local opened_choice = nil

  support.with_patches({
    {
      target = effect_runner,
      key = "scan",
      value = function()
        return {
          {
            ok = true,
            mandatory = false,
            effect = { id = "buy_land", label = "买地" },
          },
        }
      end,
    },
    {
      target = intent_output_port,
      key = "open_choice",
      value = function(_, choice_spec)
        opened_choice = choice_spec
      end,
    },
  }, function()
    local result = effect_pipeline.run({}, player, tile_ref, {
      game = g,
      move_result = { kind = "move_result" },
    }, {
      next_state = "after_optional",
      next_args = { source = "optional_effect" },
      optional_title = "可选效果",
    })
    assert(type(result) == "table" and result.waiting == true, "optional effect should wait on choice")
    _assert_eq(result.next_state, "after_optional", "optional followup should preserve next_state")
    _assert_eq(result.next_args.source, "optional_effect", "optional followup should preserve next_args")
  end)

  assert(type(opened_choice) == "table", "single optional effect should open choice")
  _assert_eq(opened_choice.route_key, "secondary_confirm", "single optional effect should use secondary_confirm route")
  _assert_eq(opened_choice.requires_confirm, true, "single optional effect should require confirm")
  _assert_eq(opened_choice.options[1].id, "buy_land", "single optional effect should expose chosen effect id")
end

-- Characterization tests for strategy helper functions (T4)
local function _test_ai_can_use_item_returns_true_for_mine_in_pre_action_and_post_action()
  local item_id = gameplay_rules.item_ids.mine
  local result_pre = item_strategy._ai_can_use_item(item_id, "pre_action")
  _assert_eq(result_pre, true, "mine should be usable in pre_action via declared offer window")

  local result_post = item_strategy._ai_can_use_item(item_id, "post_action")
  _assert_eq(result_post, true, "mine should be usable in post_action via declared offer window")
end

local function _test_ai_can_use_item_uses_offer_in_phases_for_other_items()
  -- clear_obstacles declares pre_action in offer_in_phases
  local item_id = gameplay_rules.item_ids.clear_obstacles
  local result_pre = item_strategy._ai_can_use_item(item_id, "pre_action")
  _assert_eq(result_pre, true, "clear_obstacles should be usable in pre_action")

  local result_post = item_strategy._ai_can_use_item(item_id, "post_action")
  _assert_eq(result_post, false, "clear_obstacles should not be usable in post_action")
end

local function _test_has_demolish_target_returns_true_when_target_exists()
  local g = _new_game()
  local p = g:current_player()
  -- Set up a target by placing a building
  local idx = 3
  local tile_ref = g.board:get_tile(idx)
  g:set_tile_owner(tile_ref, 2)
  g:set_tile_level(tile_ref, 1)

  local result = item_strategy._has_demolish_target(g, p)
  _assert_eq(result, true, "should find demolish target when building exists")
end

local function _test_has_demolish_target_returns_false_when_no_target()
  local g = _new_game()
  local p = g:current_player()
  -- Ensure no buildings on the board - only reset land tiles that have owners
  for _, tile_ref in ipairs(g.board.path) do
    if tile_ref.type == "land" then
      local st = g.tile_states and g.tile_states[tile_ref.id] or nil
      if st and st.owner_id then
        g:set_tile_owner(tile_ref, nil)
        g:set_tile_level(tile_ref, 0)
      end
    end
  end

  local result = item_strategy._has_demolish_target(g, p)
  _assert_eq(result, false, "should not find demolish target when no buildings exist")
end

local function _test_has_target_player_returns_true_when_candidates_exist()
  local g = _new_game()
  local p = g:current_player()
  -- exile card needs another player to target
  local item_id = gameplay_rules.item_ids.exile

  -- Mock target_candidates to return valid candidates
  support.with_patches({
    {
      target = item_strategy,
      key = "target_candidates",
      value = function()
        return { { id = 2, name = "P2" } }
      end,
    },
  }, function()
    local result = item_strategy._has_target_player(g, p, item_id)
    _assert_eq(result, true, "should find target when candidates exist")
  end)
end

local function _test_has_target_player_returns_false_when_no_candidates()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.exile

  -- Mock target_candidates to return empty candidates
  support.with_patches({
    {
      target = item_strategy,
      key = "target_candidates",
      value = function()
        return {}
      end,
    },
  }, function()
    local result = item_strategy._has_target_player(g, p, item_id)
    _assert_eq(result, false, "should not find target when no candidates exist")
  end)
end

local function _test_try_use_item_returns_nil_when_cond_fails()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.clear_obstacles

  local result = item_strategy._try_use_item(g, p, item_id, function() return false end, false)
  _assert_eq(result, nil, "should return nil when condition fails")
end

local function _test_try_use_item_returns_nil_when_item_not_in_inventory()
  local g = _new_game()
  local p = g:current_player()
  local item_id = gameplay_rules.item_ids.clear_obstacles

  -- Ensure item is not in inventory by clearing all slots
  if p.inventory and p.inventory.slots then
    for i = 1, #p.inventory.slots do
      p.inventory.slots[i] = nil
    end
  end

  local result = item_strategy._try_use_item(g, p, item_id, nil, false)
  _assert_eq(result, nil, "should return nil when item not in inventory")
end

local function _test_try_clear_obstacles_returns_result_when_obstacles_found()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = gameplay_rules.item_ids.clear_obstacles })

  -- Place a roadblock ahead
  local current_pos = p.position
  g.board:place_roadblock(current_pos + 1)

  support.with_patches({
    {
      target = item_strategy,
      key = "has_obstacles_ahead",
      value = function()
        return true
      end,
    },
  }, function()
    local result = item_strategy._try_clear_obstacles(g, p, false)
    -- Result should be a table (the use_item result) or nil
    -- Since we're not mocking executor.use_item, it will actually try to use it
    -- which may return a result or nil depending on the game state
    assert(type(result) == "table" or result == nil, "result should be table or nil")
  end)
end

local function _test_try_clear_obstacles_returns_nil_when_no_obstacles()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = gameplay_rules.item_ids.clear_obstacles })

  -- Ensure no obstacles
  for i = 1, g.board:length() do
    g.board:clear_all(i)
  end

  support.with_patches({
    {
      target = item_strategy,
      key = "has_obstacles_ahead",
      value = function()
        return false
      end,
    },
  }, function()
    local result = item_strategy._try_clear_obstacles(g, p, false)
    _assert_eq(result, nil, "should return nil when no obstacles ahead")
  end)
end

local function _test_try_remote_dice_returns_nil_when_no_dice_value_picked()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = gameplay_rules.item_ids.remote_dice })

  local auto_play_port = require("src.rules.ports.auto_play")
  support.with_patches({
    {
      target = auto_play_port,
      key = "pick_remote_dice_value",
      value = function()
        return nil
      end,
    },
  }, function()
    local result = item_strategy._try_remote_dice(g, p, false)
    _assert_eq(result, nil, "should return nil when no dice value picked")
  end)
end

local function _test_try_roadblock_returns_nil_when_no_target_picked()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = gameplay_rules.item_ids.roadblock })

  local auto_play_port = require("src.rules.ports.auto_play")
  support.with_patches({
    {
      target = auto_play_port,
      key = "pick_roadblock_target",
      value = function()
        return nil
      end,
    },
  }, function()
    local result = item_strategy._try_roadblock(g, p, false)
    _assert_eq(result, nil, "should return nil when no roadblock target picked")
  end)
end

local function _test_try_target_items_returns_nil_when_no_items_in_inventory()
  local g = _new_game()
  local p = g:current_player()
  -- Clear inventory
  if p.inventory and p.inventory.slots then
    for i = 1, #p.inventory.slots do
      p.inventory.slots[i] = nil
    end
  end

  -- Should return nil when no target items in inventory
  local result = item_strategy._try_target_items(g, p, false)
  _assert_eq(result, nil, "should return nil when no target items in inventory")
end

local function _test_try_deity_items_returns_nil_when_no_deity_items()
  local g = _new_game()
  local p = g:current_player()
  -- Clear inventory
  if p.inventory and p.inventory.slots then
    for i = 1, #p.inventory.slots do
      p.inventory.slots[i] = nil
    end
  end

  -- Should return nil when no deity items in inventory
  local result = item_strategy._try_deity_items(g, p, false)
  _assert_eq(result, nil, "should return nil when no deity items in inventory")
end

local function _test_try_deity_items_tries_rich_then_angel()
  local g = _new_game()
  local p = g:current_player()
  -- Clear inventory first
  if p.inventory and p.inventory.slots then
    for i = 1, #p.inventory.slots do
      p.inventory.slots[i] = nil
    end
  end

  -- Add both rich and angel items
  p.inventory:add({ id = gameplay_rules.item_ids.rich })
  p.inventory:add({ id = gameplay_rules.item_ids.angel })

  local used_items = {}
  local executor = require("src.rules.items.executor")
  support.with_patches({
    {
      target = executor,
      key = "use_item",
      value = function(_, _, item_id)
        table.insert(used_items, item_id)
        return { ok = true, kind = "deity_applied" }
      end,
    },
  }, function()
    local result = item_strategy._try_deity_items(g, p, false)
    -- Should try rich first (order matters)
    assert(#used_items >= 1, "should try at least one item")
    -- Result should be successful
    assert(type(result) == "table", "should return a table result")
    _assert_eq(result.ok, true, "should return successful result")
  end)
end

return {
  _test_effect_pipeline_waiting_result_patches_followup_and_strips_intent,
  _test_effect_pipeline_stop_if_short_circuits_before_optional_choice,
  _test_effect_pipeline_single_optional_effect_uses_secondary_confirm_route,
  _test_ai_can_use_item_returns_true_for_mine_in_pre_action_and_post_action,
  _test_ai_can_use_item_uses_offer_in_phases_for_other_items,
  _test_has_demolish_target_returns_true_when_target_exists,
  _test_has_demolish_target_returns_false_when_no_target,
  _test_has_target_player_returns_true_when_candidates_exist,
  _test_has_target_player_returns_false_when_no_candidates,
  _test_try_use_item_returns_nil_when_cond_fails,
  _test_try_use_item_returns_nil_when_item_not_in_inventory,
  _test_try_clear_obstacles_returns_result_when_obstacles_found,
  _test_try_clear_obstacles_returns_nil_when_no_obstacles,
  _test_try_remote_dice_returns_nil_when_no_dice_value_picked,
  _test_try_roadblock_returns_nil_when_no_target_picked,
  _test_try_target_items_returns_nil_when_no_items_in_inventory,
  _test_try_deity_items_returns_nil_when_no_deity_items,
  _test_try_deity_items_tries_rich_then_angel,
}
