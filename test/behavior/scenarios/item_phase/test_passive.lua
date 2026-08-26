local lu = require("luaunit")
local support = require("test.support.shared_support")
local item_phase = require("src.rules.items.phase")
local item_ids = require("src.config.gameplay.item_ids")
local choice_resolver = require("src.rules.choice.resolver")
local phase_registry = require("src.turn.phases.registry")
local control = require("src.player.control")

local function _new_game(opts)
  return support.new_game(opts)
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
    if item ~= false and item.id == item_id then
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

TestGameplayItemPhasePassive = {}

function TestGameplayItemPhasePassive:test_item_phase_passive_happy_path_use_then_continue_finishes_phase()
  local g = _new_game({ ai = {} })
  local player = g:current_player()
  player.inventory:add({ id = item_ids.remote_dice })
  player.inventory:add({ id = item_ids.mine })

  local phase_res = item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  lu.assertEvalToTrue(type(phase_res) == "table" and phase_res.waiting == true, "pre_action passive should wait on choice")

  local pending = assert(g.turn.pending_choice, "pre_action passive should open pending choice")
  lu.assertEquals(pending.kind, "item_phase_passive", "pending choice kind should be item_phase_passive")
  lu.assertEvalToTrue(_choice_has_option(pending, item_ids.mine), "passive choice should include mine")

  local mine_before = support.count_item(player, item_ids.mine)
  local use_res = _execute_passive_choice_direct(g, pending, item_ids.mine)
  lu.assertEvalToTrue(type(use_res) == "table" and use_res.stay == true,
    "using mine should reopen passive phase when options remain")
  lu.assertEquals(support.count_item(player, item_ids.mine), mine_before - 1, "mine should be consumed after passive use")

  pending = assert(g.turn.pending_choice, "passive phase should reopen after mine use when another item remains")
  lu.assertEquals(pending.kind, "item_phase_passive", "reopened choice kind should remain item_phase_passive")
  lu.assertFalse(_choice_has_option(pending, item_ids.mine), "reopened passive choice should not include consumed mine")

  local mine_slot = _first_inventory_slot(player, item_ids.mine)
  lu.assertNil(mine_slot, "consumed mine should no longer occupy any slot")

  local cancel_res = choice_resolver.resolve(g, pending, {
    type = "choice_cancel",
    choice_id = pending.id,
  })
  lu.assertEvalToTrue(cancel_res and cancel_res.status == "resolved", "continue action should resolve passive phase choice")
  lu.assertNil(g.turn.pending_choice, "continue action should close pending choice")
  lu.assertEvalToTrue(g.turn.item_phase and g.turn.item_phase.pre_action and g.turn.item_phase.pre_action.done == true,
    "continue action should finish pre_action phase")
end

function TestGameplayItemPhasePassive:test_item_phase_passive_effect_group_blocks_same_group_slots()
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
      key = "is_computer_controlled",
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
    lu.assertEvalToTrue(type(remote_use_select) == "table" and remote_use_select.stay == true,
      "AI-backed remote dice execute should reopen passive phase")
  end)
  lu.assertEvalToTrue(g.turn.used_effect_groups and g.turn.used_effect_groups.dice_control == true,
    "using remote dice should mark dice_control effect_group used")

  pending = assert(g.turn.pending_choice, "passive phase should reopen after remote dice")
  lu.assertFalse(_choice_has_option(pending, item_ids.remote_dice),
    "remaining same-group remote dice should not be selectable after effect_group mark")

  local cancel_res = choice_resolver.resolve(g, pending, {
    type = "choice_cancel",
    choice_id = pending.id,
  })
  lu.assertEvalToTrue(cancel_res and cancel_res.status == "resolved", "passive phase cancel should resolve")
end

function TestGameplayItemPhasePassive:test_item_phase_passive_auto_skips_with_empty_inventory()
  local g = _new_game({ ai = {} })
  local player = g:current_player()
  player.inventory.items = {}

  local phase_res = item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  lu.assertNil(phase_res, "empty inventory should auto-skip passive phase")
  lu.assertNil(g.turn.pending_choice, "empty inventory should not push any pending choice")
  lu.assertEvalToTrue(g.turn.item_phase and g.turn.item_phase.pre_action and g.turn.item_phase.pre_action.done == true,
    "empty inventory should mark pre_action phase done")
end

function TestGameplayItemPhasePassive:test_item_phase_passive_followup_choice_roundtrip()
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
  lu.assertEvalToTrue(select_res and select_res.stay == true, "selecting roadblock should keep flow for followup")

  local followup = assert(g.turn.pending_choice, "roadblock should open followup target choice")
  lu.assertEquals(followup.kind, "roadblock_target", "roadblock followup kind should be roadblock_target")
  local target_option = assert(followup.options and followup.options[1], "roadblock followup should expose at least one target")

  local roadblock_before = support.count_item(player, item_ids.roadblock)
  local followup_res = choice_resolver.resolve(g, followup, { option_id = target_option.id })
  lu.assertNotNil(followup_res, "roadblock followup resolve should return result")
  lu.assertEquals(support.count_item(player, item_ids.roadblock), roadblock_before - 1,
    "roadblock should be consumed after followup confirmation")

  local reopened = g.turn.pending_choice
  if reopened ~= nil then
    lu.assertEquals(reopened.kind, "item_phase_passive",
      "after followup should return to item phase passive choice when options remain")
  else
    lu.assertEvalToTrue(g.turn.item_phase and g.turn.item_phase.pre_action and g.turn.item_phase.pre_action.done == true,
      "after followup with no remaining options phase should finish")
  end
end

function TestGameplayItemPhasePassive:test_item_phase_passive_ai_path_remains_auto()
  local g = _new_game({ ai = { [1] = true } })
  local player = g:current_player()
  control.initialize(player)
  player.inventory:add({ id = item_ids.mine })

  local item_strategy = require("src.rules.items.strategy")
  local auto_calls = 0

  support.with_patches({
    {
      target = item_strategy,
      key = "auto_pre_action",
      value = function(_, p, phase)
        auto_calls = auto_calls + 1
        lu.assertEquals(p, player, "auto strategy should receive current AI player")
        lu.assertEquals(phase, "pre_action", "auto strategy should run in pre_action phase")
        return nil
      end,
    },
  }, function()
    local phase_res = item_phase.run({ game = g }, "pre_action", {
      player = player,
      next_state = "roll",
      next_args = { player = player },
    })
    lu.assertNil(phase_res, "AI auto path should complete without opening passive choice")
  end)

  lu.assertEvalToTrue(auto_calls >= 1, "AI path should invoke auto strategy")
  lu.assertNil(g.turn.pending_choice, "AI path should not present item_phase_passive choice")
end

function TestGameplayItemPhasePassive:test_item_phase_passive_effect_group_persists_across_phases_and_clears_on_end_turn()
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
      key = "is_computer_controlled",
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
    lu.assertEvalToTrue(type(select_res) == "table" and select_res.stay == true,
      "pre_action remote dice execute should reopen passive phase")
  end)
  lu.assertEvalToTrue(g.turn.used_effect_groups and g.turn.used_effect_groups.dice_control == true,
    "dice_control effect_group should be marked in pre_action")

  pending = assert(g.turn.pending_choice, "pre_action passive should reopen after remote dice")
  choice_resolver.resolve(g, pending, { type = "choice_cancel", choice_id = pending.id })

  local first_reopen = item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  lu.assertNil(first_reopen, "finished pre_action marker should be cleared on first re-entry attempt")

  local reopen_res = item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  lu.assertEvalToTrue(type(reopen_res) == "table" and reopen_res.waiting == true,
    "re-entered pre_action should still open item phase for remaining cards")
  local reentered_pending = assert(g.turn.pending_choice, "re-entered pre_action should expose pending choice")
  lu.assertEquals(reentered_pending.kind, "item_phase_passive", "re-entered pre_action should open passive choice")
  lu.assertFalse(_choice_has_option(reentered_pending, item_ids.remote_dice),
    "re-entered item phase should keep dice_control remote dice blocked in same turn")

  choice_resolver.resolve(g, reentered_pending, { type = "choice_cancel", choice_id = reentered_pending.id })

  local post_state, post_args = phases.post_action({ game = g }, { player = player })
  lu.assertEquals(post_state, "wait_choice", "post_action should keep turn running while passive choices remain")
  lu.assertEvalToTrue(post_args and post_args.next_state == "post_action", "post_action wait should preserve continuation")

  local post_pending = assert(g.turn.pending_choice, "post_action should expose pending item choice")
  lu.assertEquals(post_pending.kind, "item_phase_passive",
    "post_action pending should remain an item phase passive choice")

  phases.end_turn({ game = g }, { player = player })
  lu.assertEvalToTrue(type(g.turn.used_effect_groups) == "table" and next(g.turn.used_effect_groups) == nil,
    "end_turn should clear used_effect_groups for next turn")
end

function TestGameplayItemPhasePassive:test_item_phase_passive_string_option_id_normalized_by_resolver()
  local g = _new_game({ ai = {} })
  local player = g:current_player()
  player.inventory:add({ id = item_ids.mine })

  local phase_res = item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  lu.assertEvalToTrue(type(phase_res) == "table" and phase_res.waiting == true, "pre_action passive should wait on choice")
  local pending = assert(g.turn.pending_choice, "pre_action passive should open pending choice")
  lu.assertEquals(pending.kind, "item_phase_passive", "pending choice kind should be item_phase_passive")

  local mine_before = support.count_item(player, item_ids.mine)
  local resolve_res = choice_resolver.resolve(g, pending, { option_id = tostring(item_ids.mine) })
  lu.assertEvalToTrue(type(resolve_res) == "table" and resolve_res.status == "resolved",
    "string option_id should be normalized by resolver and settle the passive flow")
  lu.assertEquals(support.count_item(player, item_ids.mine), mine_before - 1,
    "string option_id should resolve to the mine option and consume it")
end

function TestGameplayItemPhasePassive:test_item_phase_passive_rejected_use_skips_mark_effect_group_used()
  local g = _new_game({ ai = {} })
  local player = g:current_player()
  -- remote_dice 带 effect_group=dice_control,rejected 结果必须不能标记该组
  player.inventory:add({ id = item_ids.remote_dice })

  item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  local pending = assert(g.turn.pending_choice, "pre_action passive should open pending choice")

  local use_flow = require("src.rules.items.use_flow")
  support.with_patches({
    {
      target = use_flow,
      key = "begin_item_use",
      value = function()
        return { ok = false, status = "rejected", reason = "no_candidates" }
      end,
    },
  }, function()
    local use_res = _execute_passive_choice_direct(g, pending, item_ids.remote_dice)
    lu.assertEvalToTrue(type(use_res) == "table", "rejected use should still settle the passive choice")
  end)

  local groups = g.turn and g.turn.used_effect_groups
  lu.assertEvalToTrue(type(groups) ~= "table" or groups.dice_control == nil,
    "rejected item use should not mark effect group used")
end


return TestGameplayItemPhasePassive
