local flow = require("core.flow")
local turn_waits = require("turn.step.wait")
local turn_choice_handler = require("turn.step.choice")
local turn_logger = require("turn.step.log")
require "lib.third_party.ClassUtils"

local turn_flow = Class("TurnFlow")

local wait_states = {
  wait_choice = true,
  wait_move_anim = true,
  wait_action_anim = true,
  detained_wait = true,
}

local function _emit_turn_prompt(turn, player_id)
  if not (turn and player_id) then
    return
  end
  turn.turn_start_prompt_seq = (turn.turn_start_prompt_seq or 0) + 1
  turn.turn_start_prompt_player_id = player_id
end

function turn_flow:init(game, phases)
  self.game = game
  self.phases = phases
  self.flow_loaded = false
  self.pending_action = nil
end

function turn_flow:dispatch(action)
  self.pending_action = action

  if not self.flow_loaded then
    self:_build_flow()
  end

  if flow.is_running() then
    self:run_until_wait()
  end
end

function turn_flow:_build_flow()
  assert(self.phases, "TurnFlow requires phases")
  local states = {}
  for name, fn in pairs(self.phases) do
    states[name] = function(args)
      if name == "start" then
        turn_logger.log_turn_start(self.game)
      end
      self.game.turn.phase = name
      self.game.dirty.turn = true
      self.game.dirty.any = true
      return fn(self, args)
    end
  end

  states.wait_choice = function(args)
    local next_state, next_args = turn_choice_handler.handle_wait_choice(self.game, args, self.pending_action)
    self.pending_action = nil
    return next_state, next_args
  end

  states.wait_move_anim = turn_waits.make_anim_wait(self, "wait_move_anim", "move_anim", "move_anim_done")
  states.wait_action_anim = function(args)
    return turn_waits.wait_action_anim(self, args)
  end
  states.detained_wait = function(args)
    self.game.turn.phase = "detained_wait"
    self.game.dirty.turn = true
    self.game.dirty.any = true
    if self.game.turn.detained_wait_active then
      return "detained_wait", args
    end
    return "end_turn", args
  end

  flow.load(states)
  if flow.is_running() then
    flow.reset()
  end
  flow.enter("start", {})
  self.flow_loaded = true
end

function turn_flow:next_player()
  local count = #self.game.players
  local current = self.game.turn.current_player_index
  local next_index = current % count + 1
  self.game.turn.current_player_index = next_index
  local next_player = self.game.players[next_index]
  _emit_turn_prompt(self.game.turn, next_player and next_player.id)
  self.game.dirty.turn = true
  self.game.dirty.any = true
  local logger = require("core.logger")
  logger.info(
    "[Eggy]",
    "切换玩家:",
    "current_index",
    tostring(current),
    "next_index",
    tostring(next_index)
  )
end

function turn_flow:run_until_wait()
  if not self.flow_loaded then
    self:_build_flow()
  end

  while flow.is_running() do
    local current = flow.current()
    flow.update()
    if wait_states[flow.current()] and flow.current() == current and not self.pending_action then
      self.game.turn.phase = flow.current()
      self.game.dirty.turn = true
      self.game.dirty.any = true
      return flow.current()
    end
  end

  self.flow_loaded = false
  return nil
end

function turn_flow:run_turn()
  return self:run_until_wait()
end

return turn_flow
