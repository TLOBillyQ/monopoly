local flow = require("src.core.Flow")
local turn_decision = require("src.game.flow.turn.TurnDecision")
local turn_waits = require("src.game.flow.turn.TurnWaits")
require "vendor.third_party.ClassUtils"

local turn_flow = Class("TurnFlow")

local wait_states = {
  wait_choice = true,
  wait_move_anim = true,
  wait_action_anim = true,
  detained_wait = true,
}

local function _get_choice(game)
  return game.turn.pending_choice
end

function turn_flow:init(game, phases)
  self.game = game
  self.phases = phases
  self.flow = nil
  self.pending_action = nil
end

function turn_flow:dispatch(action)
  self.pending_action = action

  if not self.flow or not self.flow.current then
    self.flow = self:_build_flow()
  end

  if self.flow and self.flow.current then
    self:run_until_wait()
  end
end

local function _resolve_choice(game, choice, action)
  return turn_decision.resolve_choice(game, choice, action)
end

function turn_flow:_build_flow()
  assert(self.phases, "TurnFlow requires phases")
  local states = {}
  for name, fn in pairs(self.phases) do
    states[name] = function(args)
      if name == "start" then
        turn_decision.log_turn_start(self.game)
      end
      self.game.turn.phase = name
      self.game.dirty.turn = true
      self.game.dirty.any = true
      return fn(self, args)
    end
  end

  states.wait_choice = function(args)
    self.game.turn.phase = "wait_choice"
    self.game.dirty.turn = true
    self.game.dirty.any = true
    local choice = _get_choice(self.game)
    if not choice then
      self.pending_action = nil
      return args.resume_state, args.resume_args
    end

    self.pending_action = turn_decision.decide_choice_action(self.game, choice, self.pending_action)

    if not self.pending_action then
      return "wait_choice", args
    end
    local action = self.pending_action
    self.pending_action = nil

    if action.type == "choice_select" or action.type == "choice_cancel" then
      if not action.choice_id or not choice.id or action.choice_id ~= choice.id then
        local logger = require("src.core.Logger")
        logger.warn(
          "choice action mismatch:",
          tostring(action.type),
          "action_choice_id=" .. tostring(action.choice_id),
          "pending_choice_id=" .. tostring(choice.id)
        )
        return "wait_choice", args
      end
    end
    local res = _resolve_choice(self.game, choice, action)
    if res.stay then
      return "wait_choice", args
    end
    local aa = self.game.turn.action_anim
    if aa then
      return "wait_action_anim", args
    end
    return args.resume_state, args.resume_args
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

  return flow:new({ start = "start", states = states })
end

function turn_flow:next_player()
  local count = #self.game.players
  local current = self.game.turn.current_player_index
  local next_index = current % count + 1
  self.game.turn.current_player_index = next_index
  self.game.dirty.turn = true
  self.game.dirty.any = true
  local logger = require("src.core.Logger")
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
  if not self.flow or not self.flow.current then
    self.flow = self:_build_flow()
  end

  while self.flow.current do
    local current = self.flow.current
    self.flow:step()
    if wait_states[self.flow.current] and self.flow.current == current and not self.pending_action then
      self.game.turn.phase = self.flow.current
      self.game.dirty.turn = true
      self.game.dirty.any = true
      return self.flow.current
    end
  end

  self.flow = nil
  return nil
end

function turn_flow:run_turn()
  return self:run_until_wait()
end

return turn_flow
