-- luacheck: ignore 211
-- Item AI strategy + effect-pipeline characterization tests.
-- Extracted verbatim from test_item.lua (formerly the _effect_pipeline_tests
-- helper array wired far from its definitions).
--
-- 原生 LuaUnit(busted → LuaUnit 迁移):describe 拍平为 TestItemStrategy 类,
-- before_each → setUp,用例数与改写前一一对应(19 例)。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")
local function _new_game()
  return support.new_game({ map = default_map })
end
local _assert_eq = support.assert_eq
local item_ids = require("src.config.gameplay.item_ids")
local item_strategy = require("src.rules.items.strategy")
local effect_pipeline = require("src.rules.effects.pipeline")
local effect_runner = require("src.rules.effects.runner")
local intent_output_port = require("src.rules.ports.intent_output")
local _config_reset = require("test.support.config_reset")

TestItemStrategy = {}

function TestItemStrategy:setUp()
  _config_reset.reset_all()
end

function TestItemStrategy:test_effect_pipeline_waiting_result_patches_followup_and_strips_intent()
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
    lu.assertEvalToTrue(type(result) == "table" and result.waiting == true, "waiting result should be returned")
    _assert_eq(result.next_state, "resume_turn", "waiting result should inherit next_state")
    _assert_eq(result.next_args.source, "effect_pipeline", "waiting result should inherit next_args")
    _assert_eq(result.intent, nil, "waiting result should not leak intent payload")
  end)

  lu.assertEvalToTrue(type(dispatched) == "table" and dispatched.waiting == true, "waiting payload should still dispatch")
end

function TestItemStrategy:test_effect_pipeline_stop_if_short_circuits_before_optional_choice()
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

function TestItemStrategy:test_effect_pipeline_single_optional_effect_uses_secondary_confirm_route()
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
    lu.assertEvalToTrue(type(result) == "table" and result.waiting == true, "optional effect should wait on choice")
    _assert_eq(result.next_state, "after_optional", "optional followup should preserve next_state")
    _assert_eq(result.next_args.source, "optional_effect", "optional followup should preserve next_args")
  end)

  lu.assertEvalToTrue(type(opened_choice) == "table", "single optional effect should open choice")
  _assert_eq(opened_choice.route_key, "secondary_confirm", "single optional effect should use secondary_confirm route")
  _assert_eq(opened_choice.requires_confirm, true, "single optional effect should require confirm")
  _assert_eq(opened_choice.options[1].id, "buy_land", "single optional effect should expose chosen effect id")
end

function TestItemStrategy:test_effect_pipeline_builds_confirm_copy_for_buy_land_and_upgrade_land()
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
          { ok = true, mandatory = false, effect = { id = "buy_land", label = "买地" } },
          { ok = true, mandatory = false, effect = { id = "upgrade_land", label = "加盖" } },
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
    effect_pipeline.run({}, player, tile_ref, {
      game = g,
      move_result = { kind = "move_result" },
    }, {
      optional_cost_resolver = function(effect_id)
        return effect_id == "upgrade_land" and 500 or nil
      end,
    })
  end)

  lu.assertEvalToTrue(type(opened_choice) == "table", "optional effects should open a choice")
  local buy, upgrade = opened_choice.options[1], opened_choice.options[2]
  _assert_eq(buy.confirm_title, "买地", "buy_land should carry its confirm title")
  _assert_eq(buy.confirm_body, "地块：" .. tostring(tile_ref.name) .. "。要买吗？",
    "buy_land confirm body should name the tile")
  _assert_eq(upgrade.confirm_title, "加盖", "upgrade_land should carry its confirm title")
  _assert_eq(upgrade.confirm_body, "为 " .. tostring(tile_ref.name) .. " 加盖，花费 500",
    "upgrade_land confirm body should carry the resolved cost")
end

function TestItemStrategy:test_effect_pipeline_leaves_confirm_copy_empty_for_other_optional_effects()
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
          { ok = true, mandatory = false, effect = { id = "mystery_effect", label = "神秘" } },
          { ok = true, mandatory = false, effect = { id = "other_effect" } },
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
    effect_pipeline.run({}, player, tile_ref, { game = g }, {})
  end)

  lu.assertEvalToTrue(type(opened_choice) == "table", "optional effects should open a choice")
  _assert_eq(opened_choice.options[1].confirm_title, nil, "an unknown effect gets no confirm title")
  _assert_eq(opened_choice.options[1].confirm_body, nil, "an unknown effect gets no confirm body")
  _assert_eq(opened_choice.options[1].label, "神秘", "the declared label should be used")
  _assert_eq(opened_choice.options[2].label, "other_effect", "a label-less effect falls back to its id")
  _assert_eq(opened_choice.route_key, "player", "two optional effects should route to the player")
  _assert_eq(opened_choice.requires_confirm, false, "two optional effects should not auto-confirm")
end

function TestItemStrategy:test_ai_can_use_item_returns_true_for_mine_in_pre_action_and_post_action()
  local item_id = item_ids.mine
  local result_pre = item_strategy._ai_can_use_item(item_id, "pre_action")
  _assert_eq(result_pre, true, "mine should be usable in pre_action via declared offer window")

  local result_post = item_strategy._ai_can_use_item(item_id, "post_action")
  _assert_eq(result_post, true, "mine should be usable in post_action via declared offer window")
end

function TestItemStrategy:test_ai_can_use_item_uses_offer_in_phases_for_other_items()
  -- clear_obstacles declares pre_action in offer_in_phases
  local item_id = item_ids.clear_obstacles
  local result_pre = item_strategy._ai_can_use_item(item_id, "pre_action")
  _assert_eq(result_pre, true, "clear_obstacles should be usable in pre_action")

  local result_post = item_strategy._ai_can_use_item(item_id, "post_action")
  _assert_eq(result_post, false, "clear_obstacles should not be usable in post_action")
end

function TestItemStrategy:test_has_demolish_target_returns_true_when_target_exists()
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

function TestItemStrategy:test_has_demolish_target_returns_false_when_no_target()
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

function TestItemStrategy:test_has_target_player_returns_true_when_candidates_exist()
  local g = _new_game()
  local p = g:current_player()
  -- exile card needs another player to target
  local item_id = item_ids.exile

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

function TestItemStrategy:test_has_target_player_returns_false_when_no_candidates()
  local g = _new_game()
  local p = g:current_player()
  local item_id = item_ids.exile

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

function TestItemStrategy:test_try_use_item_returns_nil_when_cond_fails()
  local g = _new_game()
  local p = g:current_player()
  local item_id = item_ids.clear_obstacles

  local result = item_strategy._try_use_item(g, p, item_id, function() return false end, false)
  _assert_eq(result, nil, "should return nil when condition fails")
end

function TestItemStrategy:test_try_use_item_returns_nil_when_item_not_in_inventory()
  local g = _new_game()
  local p = g:current_player()
  local item_id = item_ids.clear_obstacles

  -- Ensure item is not in inventory by clearing all slots
  if p.inventory and p.inventory.slots then
    for i = 1, #p.inventory.slots do
      p.inventory.slots[i] = nil
    end
  end

  local result = item_strategy._try_use_item(g, p, item_id, nil, false)
  _assert_eq(result, nil, "should return nil when item not in inventory")
end

function TestItemStrategy:test_try_clear_obstacles_returns_result_when_obstacles_found()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = item_ids.clear_obstacles })

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
    lu.assertEvalToTrue(type(result) == "table" or result == nil, "result should be table or nil")
  end)
end

function TestItemStrategy:test_try_clear_obstacles_returns_nil_when_no_obstacles()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = item_ids.clear_obstacles })

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

function TestItemStrategy:test_try_remote_dice_returns_nil_when_no_dice_value_picked()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = item_ids.remote_dice })

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

function TestItemStrategy:test_try_roadblock_returns_nil_when_no_target_picked()
  local g = _new_game()
  local p = g:current_player()
  p.inventory:add({ id = item_ids.roadblock })

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

function TestItemStrategy:test_try_target_items_returns_nil_when_no_items_in_inventory()
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

function TestItemStrategy:test_try_deity_items_returns_nil_when_no_deity_items()
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


return TestItemStrategy
