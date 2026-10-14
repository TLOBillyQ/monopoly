require("test.bootstrap").install_package_paths()
local luassert = assert
local support = require("test.support.shared_support")
local movement = require("src.rules.movement")
local move_followup = require("src.turn.phases.move_followup")
local turn_land = require("src.turn.phases.land")
local action_anim_wait = require("src.turn.waits.await_action_anim")
local event_log = require("src.state.event_log")
local action_anim = require("src.ui.render.anim")
local anim_handlers = require("src.ui.render.anim.handlers")
local wait_callbacks = require("src.turn.waits.callback_registry")

local callback_keys = wait_callbacks.callback_keys

local function _new_await_session(game, action)
  local session = {
    game = game,
    _action = action,
  }

  function session:mark_phase(name)
    self.marked_phase = name
    self.game.turn.phase = name
  end

  function session:take_pending_action()
    local next_action = self._action
    self._action = nil
    return next_action
  end

  function session:peek_pending_action()
    return self._action
  end

  function session:clear_pending_action()
    self._action = nil
  end

  return session
end

local function _run_same_tile_obstacle_chain(wait_action_anim)
  local game = support.new_game()
  local player = game:current_player()
  local target_index = 2

  game.last_turn = {}
  game.anim_gate_port.wait_action_anim = wait_action_anim == true
  game.anim_gate_port.wait_move_anim = false
  game.board:place_roadblock(target_index)
  game.board:place_mine(target_index, {
    owner_id = game.players[2].id,
    armed = true,
  })

  local move_result = movement.move(game, player, 1, {
    branch_parity = 1,
    skip_market_check = true,
  })
  local next_state, next_args = move_followup.run({ game = game }, {
    mode = "resume_turn_move",
    player = player,
    raw_total = 1,
    move_result = move_result,
  })
  local land_state, land_args = turn_land.run({ game = game }, next_args)

  return game, player, target_index, move_result, next_state, land_state, land_args
end

describe("TestObstacles", function()

local function _test_same_tile_roadblock_then_mine_without_action_anim()
  local game, player, target_index, move_result, next_state, land_state, land_args =
    _run_same_tile_obstacle_chain(false)

  luassert.truthy(next_state == "landing", "roadblock followup should still enter landing")
  luassert.truthy(move_result.stopped_on_roadblock == true, "roadblock should stop movement before mine followup")
  luassert.truthy(land_state == "wait_landing_visual", "mine with active hold should release visual hold before continuing")
  luassert.truthy(land_args.next_state == "move_followup", "mine should continue through move_followup after visual hold")
  luassert.truthy(game.board:has_roadblock(target_index) == false, "roadblock should clear after the first trigger")
  luassert.truthy(game.board:has_mine(target_index) == false, "mine should clear after the second trigger")
  luassert.truthy(player.position ~= target_index, "mine should relocate the player after roadblock landing resolves")

  local visual_cb = wait_callbacks.take(game, callback_keys.after_landing_visual)
  luassert.is_not_nil(visual_cb, "landing should register a visual hold resume callback")
  local resumed_next_state, resumed_next_args = visual_cb()
  luassert.truthy(resumed_next_state == "move_followup", "visual hold callback should resume into move_followup")

  local resumed_state = move_followup.run({ game = game }, resumed_next_args)
  luassert.truthy(resumed_state == "end_turn", "roadblock then mine followup should end the turn")
  luassert.truthy(game:detention_remaining(player) > 0, "mine followup should hospitalize the player")
end

local function _test_same_tile_roadblock_then_mine_action_anim_keeps_trigger_order()
  local game, player, target_index, move_result, next_state, land_state, land_args =
    _run_same_tile_obstacle_chain(true)
  local queue = game.turn.action_anim_queue or {}
  local initial_event_seq = event_log.get_seq(game.state.event_log)

  luassert.truthy(next_state == "landing", "roadblock followup should still enter landing before action anim wait")
  luassert.truthy(move_result.stopped_on_roadblock == true, "roadblock should stop movement before queued mine followup")
  luassert.truthy(land_state == "wait_landing_visual", "same-tile obstacle chain should release visual hold before action animations")
  luassert.truthy(land_args.next_state == "wait_action_anim", "visual hold should chain into action anim wait")
  luassert.truthy(game.turn.action_anim and game.turn.action_anim.kind == "roadblock_trigger",
    "roadblock trigger should remain first in the action anim slot")
  luassert.truthy(game.turn.action_anim and game.turn.action_anim.chain_key == nil,
    "roadblock trigger should not be mutated with mine chain metadata")
  luassert.truthy(#queue == 1 and queue[1].kind == "mine_trigger",
    "mine trigger should be queued after the roadblock trigger")
  luassert.truthy(queue[1].chain_key ~= nil, "mine trigger should carry obstacle chain metadata itself")
  luassert.truthy(game.board:has_roadblock(target_index) == false, "roadblock should clear as soon as it triggers")
  luassert.truthy(game.board:has_mine(target_index) == false, "mine should clear after it is staged")

  local visual_cb = wait_callbacks.take(game, callback_keys.after_landing_visual)
  luassert.is_not_nil(visual_cb, "landing should register a visual hold resume callback for action anim chain")

  local anim_state, anim_args = visual_cb()
  luassert.truthy(anim_state == "wait_action_anim", "visual hold callback should resume into wait_action_anim")
  luassert.is_not_nil(wait_callbacks.peek(game, callback_keys.after_action_anim),
    "visual hold callback should register a continuation behind the queued mine animation")

  local first_session = _new_await_session(game, {
    type = "action_anim_done",
    seq = game.turn.action_anim.seq,
  })
  local first = action_anim_wait.action_anim(first_session, anim_args)
  luassert.truthy(first and first.wait == true, "first action anim should keep waiting for the queued mine animation")
  luassert.truthy(game.turn.phase == "wait_action_anim", "first action anim should keep phase in wait_action_anim")
  luassert.is_not_nil(wait_callbacks.peek(game, callback_keys.after_action_anim),
    "continuation should stay armed until the queued mine animation finishes")
  luassert.truthy(game.turn.action_anim and game.turn.action_anim.kind == "mine_trigger",
    "first action anim completion should promote mine trigger into the active slot")
  luassert.truthy(game:detention_remaining(player) == 0, "hospital effect should not apply after only the roadblock animation")
  luassert.truthy(player.status.pending_location_effect == "hospital",
    "mine followup should remain pending until the queued action animation finishes")
  luassert.truthy(event_log.get_seq(game.state.event_log) == initial_event_seq,
    "hospital logs should not flush before the queued mine animation completes")

  local second_session = _new_await_session(game, {
    type = "action_anim_done",
    seq = game.turn.action_anim.seq,
  })
  local second = action_anim_wait.action_anim(second_session, anim_args)
  luassert.truthy(second and second.next_state == "move_followup",
    "second action anim should resume the queued move_followup continuation")
  luassert.truthy(wait_callbacks.peek(game, callback_keys.after_action_anim) == nil,
    "continuation should clear once the queued mine animation finishes")

  local resumed_state = move_followup.run({ game = game }, second.next_args)
  luassert.truthy(resumed_state == "end_turn", "queued mine followup should still end the turn after both animations")
  luassert.truthy(game:detention_remaining(player) > 0, "queued mine followup should still hospitalize the player")
  luassert.truthy(player.status.pending_location_effect == nil, "hospital effect should resolve after move_followup runs")
  luassert.truthy(event_log.get_seq(game.state.event_log) > initial_event_seq,
    "mine and hospital logs should appear only after the queued mine animation finishes")
  local event_text = event_log.get_text(game.state.event_log)
  luassert.truthy(event_text:find("触发地雷", 1, true) ~= nil, "mine trigger log should appear after queued animation completion")
  luassert.truthy(event_text:find("住院，需停留", 1, true) ~= nil, "hospital log should appear after queued animation completion")
end

local function _test_same_tile_obstacle_chain_emits_single_summary_tip()
  local game, _, _, _, _, land_state, _ = _run_same_tile_obstacle_chain(true)
  local captured = {}
  local runtime_bundle = {
    host_runtime = {
      enqueue_tip = function(intent)
        captured[#captured + 1] = intent
        return true
      end,
      schedule = function(_, fn)
        if fn then
          fn()
        end
        return true
      end,
    },
    runtime = {},
    ui_events = {
      show = {},
      hide = {},
      send_to_all = function() end,
    },
  }

  luassert.truthy(land_state == "wait_landing_visual", "same-tile obstacle chain should still defer through landing visual")
  local visual_cb = wait_callbacks.take(game, callback_keys.after_landing_visual)
  luassert.is_not_nil(visual_cb, "same-tile obstacle chain should register landing visual callback")
  local anim_state, anim_args = visual_cb()
  luassert.truthy(anim_state == "wait_action_anim", "same-tile obstacle chain should resume into action anim wait")

  support.with_patches({
    { target = anim_handlers, key = "play_roadblock_trigger", value = function() return 0 end },
    { target = anim_handlers, key = "play_mine_trigger", value = function() return 0 end },
  }, function()
    action_anim.play({ game = game, board_scene = {} }, game.turn.action_anim, {
      runtime_bundle = runtime_bundle,
    })
    local first_session = _new_await_session(game, {
      type = "action_anim_done",
      seq = game.turn.action_anim.seq,
    })
    local first = action_anim_wait.action_anim(first_session, anim_args)
    luassert.truthy(first and first.wait == true, "roadblock action anim should still wait for queued mine trigger")
    action_anim.play({ game = game, board_scene = {} }, game.turn.action_anim, {
      runtime_bundle = runtime_bundle,
    })
  end)

  luassert.truthy(#captured == 1, "same-tile obstacle chain should emit exactly one summary tip")
  luassert.truthy(captured[1].text:find("地雷", 1, true) ~= nil, "summary tip should mention mine")
end


it("test_same_tile_roadblock_then_mine_without_action_anim", _test_same_tile_roadblock_then_mine_without_action_anim)
it("test_same_tile_roadblock_then_mine_action_anim_keeps_trigger_order", _test_same_tile_roadblock_then_mine_action_anim_keeps_trigger_order)
it("test_same_tile_obstacle_chain_emits_single_summary_tip", _test_same_tile_obstacle_chain_emits_single_summary_tip)
end)
