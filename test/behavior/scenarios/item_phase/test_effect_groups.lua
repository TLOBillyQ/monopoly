local lu = require("luaunit")
local support = require("test.support.shared_support")
local phase = require("src.rules.items.phase")
local resolver = require("src.rules.choice.resolver")
local availability = require("src.rules.items.availability")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local control = require("src.player.control")

local use_flow = require("src.rules.items.use_flow")
local phase_registry = require("src.turn.phases.registry")
local scheduler = require("src.turn.scheduler")

TestItemEffectGroups = {}

local function new_game(mode, item_id)
  local g = support.new_game({ ai = mode == "replacement" and { [1] = true } or {} })
  local p = g:current_player()
  control.initialize(p)
  if mode == "manual" then control.toggle_manual_delegation(p) end
  if mode == "afk" then control.enable_afk_delegation(p) end
  inventory.clear(p)
  p.inventory:add({ id = item_id })
  p.inventory:add({ id = item_id })
  return g, p
end

local function run_phase(g, p, phase_name)
  return phase.run({ game = g }, phase_name or "pre_action", {
    player = p, next_state = "roll", next_args = { player = p },
  })
end

local function select_item(g, item_id)
  return resolver.resolve(g, assert(g.turn.pending_choice), { option_id = item_id })
end

function TestItemEffectGroups:test_remote_dice_locks_only_after_success_and_keeps_the_pending_points()
  for _, mode in ipairs({ "direct", "replacement", "manual", "afk" }) do
    local g, p = new_game(mode, item_ids.remote_dice)
    run_phase(g, p)
    if mode == "direct" then
      select_item(g, item_ids.remote_dice)
      lu.assertNil(g.turn.used_effect_groups.dice_control)
      lu.assertEquals(inventory.count(p), 2)
      select_item(g, 3)
      lu.assertEquals(g:peek_pending_remote_dice(p), { 3 })
    end
    local points = {}
    for index, value in ipairs(g:peek_pending_remote_dice(p)) do points[index] = value end
    lu.assertEquals(inventory.count(p), 1, mode)
    lu.assertEquals(p.inventory.items[2].id, item_ids.remote_dice, mode)
    lu.assertEquals(g.turn.used_effect_groups.dice_control, true, mode)
    local rejected = use_flow.begin_item_use(g, p, item_ids.remote_dice, { phase = "pre_action" })
    lu.assertFalse(rejected.ok, mode)
    lu.assertEquals(rejected.reason, "effect_group_used", mode)
    lu.assertEquals(g:peek_pending_remote_dice(p), points, mode)
    lu.assertEquals(p.inventory.items[2].id, item_ids.remote_dice, mode)
  end
end

function TestItemEffectGroups:test_cancel_and_illegal_phase_do_not_lock_a_later_success()
  local g, p = new_game("direct", item_ids.remote_dice)
  local rejected = use_flow.begin_item_use(g, p, item_ids.remote_dice, { phase = "post_action" })
  lu.assertFalse(rejected.ok)
  lu.assertNil(g.turn.used_effect_groups.dice_control)
  run_phase(g, p)
  select_item(g, item_ids.remote_dice)
  local followup = assert(g.turn.pending_choice)
  local invalid_choice = use_flow.resolve_item_use_choice(g, followup, { option_id = 7 })
  lu.assertFalse(invalid_choice.ok)
  lu.assertEquals(inventory.count(p), 2)
  lu.assertNil(g.turn.used_effect_groups.dice_control)
  resolver.resolve(g, followup, { type = "choice_cancel", choice_id = followup.id })
  lu.assertEquals(inventory.count(p), 2)
  lu.assertNil(g.turn.used_effect_groups.dice_control)
  select_item(g, item_ids.remote_dice)
  select_item(g, 4)
  lu.assertEquals(g:peek_pending_remote_dice(p), { 4 })
  lu.assertEquals(g.turn.used_effect_groups.dice_control, true)
end

function TestItemEffectGroups:test_rejected_effect_keeps_its_consumption_policy_and_allows_a_later_grouped_card()
  local g, p = new_game("direct", item_ids.remote_dice)
  p.inventory:add({ id = item_ids.monster })
  local rejected = use_flow.begin_item_use(g, p, item_ids.monster)
  lu.assertFalse(rejected.ok)
  lu.assertEquals(rejected.status, "rejected")
  lu.assertEquals(p.inventory.items[3].id, item_ids.monster)
  lu.assertEquals(g.turn.used_effect_groups, {})
  run_phase(g, p)
  select_item(g, item_ids.remote_dice)
  select_item(g, 5)
  lu.assertEquals(g:peek_pending_remote_dice(p), { 5 })
  lu.assertEquals(g.turn.used_effect_groups.dice_control, true)
  lu.assertEquals(p.inventory.items[2].id, item_ids.remote_dice)
end

function TestItemEffectGroups:test_different_groups_can_succeed_in_the_same_turn()
  for _, mode in ipairs({ "direct", "replacement", "manual", "afk" }) do
    local g, p = new_game(mode, item_ids.remote_dice)
    p.inventory:add({ id = item_ids.dice_multiplier })
    run_phase(g, p)
    if mode == "direct" then
      select_item(g, item_ids.remote_dice)
      select_item(g, 2)
    end
    run_phase(g, p, "pre_move")
    if mode == "direct" then select_item(g, item_ids.dice_multiplier) end
    lu.assertEquals(inventory.count(p), 1, mode)
    lu.assertEquals(p.inventory.items[2].id, item_ids.remote_dice, mode)
    lu.assertEquals(g.turn.used_effect_groups, { dice_control = true, dice_multiply = true }, mode)
    lu.assertEquals(g:player_pending_dice_multiplier(p), 2, mode)
  end
end

function TestItemEffectGroups:test_real_turn_cleanup_restores_the_group_on_the_next_own_turn()
  local g, p = new_game("direct", item_ids.dice_multiplier)
  run_phase(g, p, "pre_move")
  select_item(g, item_ids.dice_multiplier)
  local phases = phase_registry.build_default_phases()
  local runtime = scheduler:new(g, {
    start = function(turn_mgr)
      if g.turn.current_player_index == 1 and not g.turn.used_effect_groups.dice_multiply then
        return nil
      end
      return phases.end_turn(turn_mgr, { player = g:current_player() })
    end,
  })
  local timer = require("src.turn.policies.timer")
  runtime:run_turn()
  for _ = 1, 2 do
    timer.update_inter_turn_wait_timer(g, g.turn, 10, function() runtime:run_turn() end)
  end
  lu.assertEquals(g:current_player(), p)
  local allowed = availability.can_offer_in_phase(g, p, item_ids.dice_multiplier, "pre_move")
  lu.assertTrue(allowed)
  run_phase(g, p, "pre_move")
  select_item(g, item_ids.dice_multiplier)
  lu.assertEquals(inventory.count(p), 0)
  lu.assertEquals(g.turn.used_effect_groups.dice_multiply, true)
end

function TestItemEffectGroups:test_all_control_modes_keep_the_second_multiplier_in_its_slot()
  for _, mode in ipairs({ "direct", "replacement", "manual", "afk" }) do
    local g, p = new_game(mode, item_ids.dice_multiplier)
    run_phase(g, p, "pre_move")
    if mode == "direct" then select_item(g, item_ids.dice_multiplier) end
    lu.assertEquals(inventory.count(p), 1, mode)
    lu.assertEquals(p.inventory.items[1], false, mode)
    lu.assertEquals(p.inventory.items[2].id, item_ids.dice_multiplier, mode)
    lu.assertEquals(g.turn.used_effect_groups.dice_multiply, true, mode)
    lu.assertEquals(g:player_pending_dice_multiplier(p), 2, mode)
    local allowed, reason = availability.can_offer_in_phase(g, p, item_ids.dice_multiplier, "pre_move")
    lu.assertFalse(allowed, mode)
    lu.assertEquals(reason, "effect_group_used", mode)
  end
end
