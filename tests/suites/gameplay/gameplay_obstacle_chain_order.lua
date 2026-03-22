local support = require("support.gameplay_support")
local movement = support.movement
local move_followup = require("src.turn.phases.move_followup")
local turn_land = require("src.turn.phases.land")
local await = require("src.turn.waits.await")
local logger = require("src.core.utils.logger")
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

local function _test_same_tile_roadblock_then_mine_without_action_anim()
  local game, player, target_index, move_result, next_state, land_state, land_args =
    _run_same_tile_obstacle_chain(false)

  assert(next_state == "landing", "roadblock followup should still enter landing")
  assert(move_result.stopped_on_roadblock == true, "roadblock should stop movement before mine followup")
  assert(land_state == "move_followup", "mine should continue through move_followup after roadblock landing")
  assert(game.board:has_roadblock(target_index) == false, "roadblock should clear after the first trigger")
  assert(game.board:has_mine(target_index) == false, "mine should clear after the second trigger")
  assert(player.position ~= target_index, "mine should relocate the player after roadblock landing resolves")

  local resumed_state = move_followup.run({ game = game }, land_args)
  assert(resumed_state == "end_turn", "roadblock then mine followup should end the turn")
  assert((player.status.stay_turns or 0) > 0, "mine followup should hospitalize the player")
end

local function _test_same_tile_roadblock_then_mine_action_anim_keeps_trigger_order()
  logger.clear()
  local game, player, target_index, move_result, next_state, land_state, land_args =
    _run_same_tile_obstacle_chain(true)
  local queue = game.turn.action_anim_queue or {}
  local initial_event_seq = logger.get_event_seq()

  assert(next_state == "landing", "roadblock followup should still enter landing before action anim wait")
  assert(move_result.stopped_on_roadblock == true, "roadblock should stop movement before queued mine followup")
  assert(land_state == "wait_action_anim", "same-tile obstacle chain should wait for ordered action animations")
  assert(game.turn.action_anim and game.turn.action_anim.kind == "roadblock_trigger",
    "roadblock trigger should remain first in the action anim slot")
  assert(#queue == 1 and queue[1].kind == "mine_trigger",
    "mine trigger should be queued after the roadblock trigger")
  assert(game.board:has_roadblock(target_index) == false, "roadblock should clear as soon as it triggers")
  assert(game.board:has_mine(target_index) == false, "mine should clear after it is staged")
  assert(wait_callbacks.peek(game, callback_keys.after_action_anim) ~= nil,
    "landing should register a continuation behind the queued mine animation")

  local first_session = _new_await_session(game, {
    type = "action_anim_done",
    seq = game.turn.action_anim.seq,
  })
  local first = await.action_anim(first_session, land_args)
  assert(first and first.wait == true, "first action anim should keep waiting for the queued mine animation")
  assert(game.turn.phase == "wait_action_anim", "first action anim should keep phase in wait_action_anim")
  assert(wait_callbacks.peek(game, callback_keys.after_action_anim) ~= nil,
    "continuation should stay armed until the queued mine animation finishes")
  assert(game.turn.action_anim and game.turn.action_anim.kind == "mine_trigger",
    "first action anim completion should promote mine trigger into the active slot")
  assert((player.status.stay_turns or 0) == 0, "hospital effect should not apply after only the roadblock animation")
  assert(player.status.pending_location_effect == "hospital",
    "mine followup should remain pending until the queued action animation finishes")
  assert(logger.get_event_seq() == initial_event_seq,
    "hospital logs should not flush before the queued mine animation completes")

  local second_session = _new_await_session(game, {
    type = "action_anim_done",
    seq = game.turn.action_anim.seq,
  })
  local second = await.action_anim(second_session, land_args)
  assert(second and second.next_state == "move_followup",
    "second action anim should resume the queued move_followup continuation")
  assert(wait_callbacks.peek(game, callback_keys.after_action_anim) == nil,
    "continuation should clear once the queued mine animation finishes")

  local resumed_state = move_followup.run({ game = game }, second.next_args)
  assert(resumed_state == "end_turn", "queued mine followup should still end the turn after both animations")
  assert((player.status.stay_turns or 0) > 0, "queued mine followup should still hospitalize the player")
  assert(player.status.pending_location_effect == nil, "hospital effect should resolve after move_followup runs")
  assert(logger.get_event_seq() > initial_event_seq,
    "mine and hospital logs should appear only after the queued mine animation finishes")
  local event_text = logger.get_text_by_level("event")
  assert(event_text:find("触发地雷", 1, true) ~= nil, "mine trigger log should appear after queued animation completion")
  assert(event_text:find("住院，需停留", 1, true) ~= nil, "hospital log should appear after queued animation completion")
end

return {
  name = "gameplay_obstacle_chain_order",
  tests = {
    {
      name = "same_tile_roadblock_then_mine_without_action_anim",
      run = _test_same_tile_roadblock_then_mine_without_action_anim,
    },
    {
      name = "same_tile_roadblock_then_mine_action_anim_keeps_trigger_order",
      run = _test_same_tile_roadblock_then_mine_action_anim_keeps_trigger_order,
    },
  },
}
