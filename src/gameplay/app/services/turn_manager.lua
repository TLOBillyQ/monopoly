local Flow = require("src.gameplay.app.flow")
local Choice = require("src.gameplay.app.choice")
local ChoiceResolver = require("src.gameplay.app.choice_resolver")
local phase_start_fn = require("src.gameplay.app.turn.start")
local phase_roll_fn = require("src.gameplay.app.turn.roll")
local phase_move_fn = require("src.gameplay.app.turn.move")
local phase_landing_fn = require("src.gameplay.app.turn.land")
local phase_post_fn = require("src.gameplay.app.turn.post")
local phase_end_fn = require("src.gameplay.app.turn.end_turn")
local Agent = require("src.gameplay.ai.agent")

local TurnManager = {}
TurnManager.__index = TurnManager

local PHASES = {
  start = { phase = "start", fn = phase_start_fn },
  roll = { phase = "roll", fn = phase_roll_fn },
  move = { phase = "move", fn = phase_move_fn },
  landing = { phase = "landing", fn = phase_landing_fn },
  post_action = { phase = "post_action", fn = phase_post_fn },
  
  land = { phase = "landing", fn = phase_landing_fn },
  end_turn = { phase = "end_turn", fn = phase_end_fn },
}



function TurnManager.new(game)
  local tm = {
    game = game,
    flow = nil,
    pending_action = nil,
  }
  return setmetatable(tm, TurnManager)
end

function TurnManager:dispatch(action)
  self.pending_action = action

  
  
  local choice = Choice.get(self.game)
  if choice and (not self.flow or not self.flow.current) then
    local res = ChoiceResolver.resolve(self.game, choice, action)
    self.pending_action = nil
    return res
  end

  if self.flow and self.flow.current then
    self:run_until_wait()
  end
end

function TurnManager:_build_flow()
  local states = {}
  for name, spec in pairs(PHASES) do
    states[name] = function(args)
      self.game.store:set({ "turn", "phase" }, spec.phase)
      return spec.fn(self, args)
    end
  end

  states.wait_choice = function(args)
    self.game.store:set({ "turn", "phase" }, "wait_choice")
    local choice = Choice.get(self.game)
    
    
    if not choice then
      self.pending_action = nil
      return (args and args.resume_state) or "end_turn", (args and args.resume_args) or {}
    end

    if not self.pending_action then
      local auto_action = Agent.auto_action_for_choice(self.game, choice)
      if auto_action then
        self.pending_action = auto_action
      end
    end

    if not self.pending_action then
      return "wait_choice", args
    end
    local action = self.pending_action
    self.pending_action = nil

    
    if action.choice_id and choice.id and action.choice_id ~= choice.id then
      return "wait_choice", args
    end
    local res = ChoiceResolver.resolve(self.game, choice, action)
    if res and res.stay then
      return "wait_choice", args
    end
    return args and args.resume_state, args and args.resume_args
  end

  return Flow.new({ start = "start", states = states })
end

function TurnManager:next_player()
  local count = #self.game.players
  local current = self.game.store:get({ "turn", "current_player_index" }) or 1
  local next_index = current % count + 1
  self.game.store:set({ "turn", "current_player_index" }, next_index)
end

function TurnManager:run_until_wait()
  if not self.flow or not self.flow.current then
    self.flow = self:_build_flow()
  end

  while self.flow.current do
    if self.flow.current == "wait_choice" and not self.pending_action then
      self.game.store:set({ "turn", "phase" }, "wait_choice")
      return "wait_choice"
    end
    self.flow:step()
  end

  self.flow = nil
  return nil
end



function TurnManager:run_turn()
  return self:run_until_wait()
end

return TurnManager
