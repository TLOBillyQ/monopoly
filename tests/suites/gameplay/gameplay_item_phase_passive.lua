local support = require("support.gameplay_support")
local compose_game = require("src.app.compose_game")
local default_ports = require("src.turn.output.default_ports")
local item_phase = require("src.rules.items.phase")
local item_ids = require("src.config.gameplay.item_ids")
local choice_resolver = support.choice_resolver
local phase_registry = require("src.turn.phases.registry")

local map_cfg = support.map_cfg
local tiles_cfg = support.tiles_cfg

local function _new_game(opts)
  opts = opts or {}
  return compose_game.new_game(default_ports.resolve_game_opts({
    players = opts.players or { "P1", "P2" },
    ai = opts.ai or {},
    auto_all = opts.auto_all == true,
    map = opts.map or map_cfg,
    tiles = opts.tiles or tiles_cfg,
  }))
end

local function _count_item(player, item_id)
  local count = 0
  for _, item in ipairs(player.inventory.items or {}) do
    if item.id == item_id then
      count = count + 1
    end
  end
  return count
end

local function _choice_has_option(choice, option_id)
  for _, option in ipairs(choice and choice.options or {}) do
    if option.id == option_id then
      return true
    end
  end
  return false
end

local function _first_inventory_slot(player, item_id)
  for slot_index, item in ipairs(player.inventory.items or {}) do
    if item.id == item_id then
      return slot_index
    end
  end
  return nil
end

local function _execute_passive_choice_direct(game, choice, option_id)
  local descriptor = assert(game.registries and game.registries.choices and game.registries.choices.handlers
      and game.registries.choices.handlers.item_phase_passive,
    "missing item_phase_passive choice descriptor")
  return descriptor.execute(game, choice, { option_id = option_id })
end

local function _test_item_phase_passive_happy_path_use_then_continue_finishes_phase()
  local g = _new_game({ ai = {} })
  local player = g:current_player()
  player.inventory:add({ id = item_ids.remote_dice })
  player.inventory:add({ id = item_ids.mine })

  local phase_res = item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  assert(type(phase_res) == "table" and phase_res.waiting == true, "pre_action passive should wait on choice")

  local pending = assert(g.turn.pending_choice, "pre_action passive should open pending choice")
  assert(pending.kind == "item_phase_passive", "pending choice kind should be item_phase_passive")
  assert(_choice_has_option(pending, item_ids.mine), "passive choice should include mine")

  local mine_before = _count_item(player, item_ids.mine)
  local use_res = _execute_passive_choice_direct(g, pending, item_ids.mine)
  assert(use_res == true, "using mine should reopen passive phase when options remain")
  assert(_count_item(player, item_ids.mine) == mine_before - 1, "mine should be consumed after passive use")

  pending = assert(g.turn.pending_choice, "passive phase should reopen after mine use when another item remains")
  assert(pending.kind == "item_phase_passive", "reopened choice kind should remain item_phase_passive")
  assert(_choice_has_option(pending, item_ids.mine) == false, "reopened passive choice should not include consumed mine")

  local mine_slot = _first_inventory_slot(player, item_ids.mine)
  assert(mine_slot == nil, "consumed mine should no longer occupy any slot")

  local cancel_res = choice_resolver.resolve(g, pending, {
    type = "choice_cancel",
    choice_id = pending.id,
  })
  assert(cancel_res and cancel_res.status == "resolved", "continue action should resolve passive phase choice")
  assert(g.turn.pending_choice == nil, "continue action should close pending choice")
  assert(g.turn.item_phase and g.turn.item_phase.pre_action and g.turn.item_phase.pre_action.done == true,
    "continue action should finish pre_action phase")
end

local function _test_item_phase_passive_effect_group_blocks_same_group_slots()
  local g = _new_game({ ai = {} })
  local player = g:current_player()
  player.inventory:add({ id = item_ids.remote_dice })
  player.inventory:add({ id = item_ids.remote_dice })
  player.inventory:add({ id = item_ids.mine })

  item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  local pending = assert(g.turn.pending_choice, "pre_action passive should open choice")

  local auto_play_port = require("src.rules.ports.auto_play")
  support.with_patches({
    {
      target = auto_play_port,
      key = "is_auto_player",
      value = function(_, p)
        return p == player
      end,
    },
    {
      target = auto_play_port,
      key = "pick_remote_dice_value",
      value = function()
        return 1
      end,
    },
  }, function()
    local remote_use_select = _execute_passive_choice_direct(g, pending, item_ids.remote_dice)
    assert(remote_use_select == true, "AI-backed remote dice execute should reopen passive phase")
  end)
  assert(g.turn.used_effect_groups and g.turn.used_effect_groups.dice_control == true,
    "using remote dice should mark dice_control effect_group used")

  pending = assert(g.turn.pending_choice, "passive phase should reopen after remote dice")
  assert(_choice_has_option(pending, item_ids.remote_dice) == false,
    "remaining same-group remote dice should not be selectable after effect_group mark")

  local cancel_res = choice_resolver.resolve(g, pending, {
    type = "choice_cancel",
    choice_id = pending.id,
  })
  assert(cancel_res and cancel_res.status == "resolved", "passive phase cancel should resolve")
end

local function _test_item_phase_passive_auto_skips_with_empty_inventory()
  local g = _new_game({ ai = {} })
  local player = g:current_player()
  player.inventory.items = {}

  local phase_res = item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  assert(phase_res == nil, "empty inventory should auto-skip passive phase")
  assert(g.turn.pending_choice == nil, "empty inventory should not push any pending choice")
  assert(g.turn.item_phase and g.turn.item_phase.pre_action and g.turn.item_phase.pre_action.done == true,
    "empty inventory should mark pre_action phase done")
end

local function _test_item_phase_passive_followup_choice_roundtrip()
  local g = _new_game({ ai = {} })
  local player = g:current_player()
  player.inventory:add({ id = item_ids.roadblock })
  player.inventory:add({ id = item_ids.mine })

  item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  local pending = assert(g.turn.pending_choice, "pre_action passive should open choice")

  local select_res = choice_resolver.resolve(g, pending, { option_id = item_ids.roadblock })
  assert(select_res and select_res.stay == true, "selecting roadblock should keep flow for followup")

  local followup = assert(g.turn.pending_choice, "roadblock should open followup target choice")
  assert(followup.kind == "roadblock_target", "roadblock followup kind should be roadblock_target")
  local target_option = assert(followup.options and followup.options[1], "roadblock followup should expose at least one target")

  local roadblock_before = _count_item(player, item_ids.roadblock)
  local followup_res = choice_resolver.resolve(g, followup, { option_id = target_option.id })
  assert(followup_res ~= nil, "roadblock followup resolve should return result")
  assert(_count_item(player, item_ids.roadblock) == roadblock_before - 1,
    "roadblock should be consumed after followup confirmation")

  local reopened = g.turn.pending_choice
  if reopened ~= nil then
    assert(reopened.kind == "item_phase_passive" or reopened.kind == "item_phase_choice",
      "after followup should return to item phase choice when options remain")
  else
    assert(g.turn.item_phase and g.turn.item_phase.pre_action and g.turn.item_phase.pre_action.done == true,
      "after followup with no remaining options phase should finish")
  end
end

local function _test_item_phase_passive_ai_path_remains_auto()
  local g = _new_game({ ai = { [1] = true } })
  local player = g:current_player()
  player.auto = true
  player.inventory:add({ id = item_ids.mine })

  local auto_play_port = require("src.rules.ports.auto_play")
  local item_strategy = require("src.rules.items.strategy")
  local auto_calls = 0

  support.with_patches({
    {
      target = auto_play_port,
      key = "is_auto_player",
      value = function(_, p)
        return p == player
      end,
    },
    {
      target = item_strategy,
      key = "auto_pre_action",
      value = function(_, p, phase)
        auto_calls = auto_calls + 1
        assert(p == player, "auto strategy should receive current AI player")
        assert(phase == "pre_action", "auto strategy should run in pre_action phase")
        return nil
      end,
    },
  }, function()
    local phase_res = item_phase.run({ game = g }, "pre_action", {
      player = player,
      next_state = "roll",
      next_args = { player = player },
    })
    assert(phase_res == nil, "AI auto path should complete without opening passive choice")
  end)

  assert(auto_calls >= 1, "AI path should invoke auto strategy")
  assert(g.turn.pending_choice == nil, "AI path should not present item_phase_passive choice")
end

local function _test_item_phase_passive_effect_group_persists_across_phases_and_clears_on_end_turn()
  local g = _new_game({ ai = {} })
  local player = g:current_player()
  local phases = phase_registry.build_default_phases()
  player.inventory:add({ id = item_ids.remote_dice })
  player.inventory:add({ id = item_ids.remote_dice })
  player.inventory:add({ id = item_ids.mine })

  item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  local pending = assert(g.turn.pending_choice, "pre_action passive should open choice")

  local auto_play_port = require("src.rules.ports.auto_play")
  support.with_patches({
    {
      target = auto_play_port,
      key = "is_auto_player",
      value = function(_, p)
        return p == player
      end,
    },
    {
      target = auto_play_port,
      key = "pick_remote_dice_value",
      value = function()
        return 1
      end,
    },
  }, function()
    local select_res = _execute_passive_choice_direct(g, pending, item_ids.remote_dice)
    assert(select_res == true, "pre_action remote dice execute should reopen passive phase")
  end)
  assert(g.turn.used_effect_groups and g.turn.used_effect_groups.dice_control == true,
    "dice_control effect_group should be marked in pre_action")

  pending = assert(g.turn.pending_choice, "pre_action passive should reopen after remote dice")
  choice_resolver.resolve(g, pending, { type = "choice_cancel", choice_id = pending.id })

  local first_reopen = item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  assert(first_reopen == nil, "finished pre_action marker should be cleared on first re-entry attempt")

  local reopen_res = item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  assert(type(reopen_res) == "table" and reopen_res.waiting == true,
    "re-entered pre_action should still open item phase for remaining cards")
  local reentered_pending = assert(g.turn.pending_choice, "re-entered pre_action should expose pending choice")
  assert(reentered_pending.kind == "item_phase_passive", "re-entered pre_action should open passive choice")
  assert(_choice_has_option(reentered_pending, item_ids.remote_dice) == false,
    "re-entered item phase should keep dice_control remote dice blocked in same turn")

  choice_resolver.resolve(g, reentered_pending, { type = "choice_cancel", choice_id = reentered_pending.id })

  local post_state, post_args = phases.post_action({ game = g }, { player = player })
  assert(post_state == "wait_choice", "post_action should keep turn running while passive choices remain")
  assert(post_args and post_args.next_state == "post_action", "post_action wait should preserve continuation")

  local post_pending = assert(g.turn.pending_choice, "post_action should expose pending item choice")
  assert(post_pending.kind == "item_phase_passive" or post_pending.kind == "item_phase_choice",
    "post_action pending should remain an item phase choice")

  phases.end_turn({ game = g }, { player = player })
  assert(type(g.turn.used_effect_groups) == "table" and next(g.turn.used_effect_groups) == nil,
    "end_turn should clear used_effect_groups for next turn")
end

return {
  name = "gameplay_item_phase_passive",
  tests = {
    {
      name = "item_phase_passive_happy_path_use_then_continue_finishes_phase",
      run = _test_item_phase_passive_happy_path_use_then_continue_finishes_phase,
    },
    {
      name = "item_phase_passive_effect_group_blocks_same_group_slots",
      run = _test_item_phase_passive_effect_group_blocks_same_group_slots,
    },
    {
      name = "item_phase_passive_auto_skips_with_empty_inventory",
      run = _test_item_phase_passive_auto_skips_with_empty_inventory,
    },
    {
      name = "item_phase_passive_followup_choice_roundtrip",
      run = _test_item_phase_passive_followup_choice_roundtrip,
    },
    {
      name = "item_phase_passive_ai_path_remains_auto",
      run = _test_item_phase_passive_ai_path_remains_auto,
    },
    {
      name = "item_phase_passive_effect_group_persists_across_phases_and_clears_on_end_turn",
      run = _test_item_phase_passive_effect_group_persists_across_phases_and_clears_on_end_turn,
    },
  },
}
