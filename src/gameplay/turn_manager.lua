local Flow = require("src.core.flow")
local Choice = require("src.gameplay.choice")
local ChoiceResolver = require("src.gameplay.choice_resolver")
local UI = require("src.gameplay.ui_port")
local phase_start = require("src.gameplay.turn_start")
local phase_roll = require("src.gameplay.turn_roll")
local phase_move = require("src.gameplay.turn_move")
local phase_landing = require("src.gameplay.turn_land")
local phase_post = require("src.gameplay.turn_post")
local phase_end = require("src.gameplay.turn_end")
local DecisionEngine = require("src.gameplay.decision_engine")
local Logger = require("src.util.logger")

local TurnManager = {}
TurnManager.__index = TurnManager

local PHASES = {
  start = phase_start,
  roll = phase_roll,
  move = phase_move,
  landing = phase_landing,
  post_action = phase_post,
  end_turn = phase_end,
}

local function matches_choice_action(choice, action)
  if not action then
    return false
  end
  if action.choice_id and choice and choice.id and action.choice_id ~= choice.id then
    return false
  end
  return true
end

local function decide_choice_action(game, choice, pending_action)
  if pending_action then
    return pending_action
  end

  local auto_action = DecisionEngine.get_choice_action(game, choice)
  if auto_action then
    return auto_action
  end

  if not UI.is_available(game) then
    local first = choice.options and choice.options[1]
    if first then
      return { type = "choice_select", choice_id = choice.id, option_id = first.id or first }
    end
    if choice.allow_cancel ~= false then
      return { type = "choice_cancel", choice_id = choice.id }
    end
  end

  return nil
end



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
  local no_flow = not self.flow or not self.flow.current
  
  if choice and no_flow then
    self.pending_action = nil
    if not matches_choice_action(choice, action) then
      return nil
    end
    return ChoiceResolver.resolve(self.game, choice, action)
  end

  if self.flow and self.flow.current then
    self:run_until_wait()
  end
end

function TurnManager:_build_flow()
  local states = {}
  for name, fn in pairs(PHASES) do
    states[name] = function(args)
      if name == "start" then
        local p_idx = self.game.store:get({ "turn", "current_player_index" })
        local turn_count = self.game.store:get({ "turn", "turn_count" }) or 0
        Logger.info("回合: " .. (turn_count + 1) .. " [Player " .. tostring(p_idx) .. "]")
      end
      self.game.store:set({ "turn", "phase" }, name)
      return fn(self, args)
    end
  end

  states.wait_choice = function(args)
    self.game.store:set({ "turn", "phase" }, "wait_choice")
    local choice = Choice.get(self.game)

    if not choice then
      self.pending_action = nil
      return (args and args.resume_state) or "end_turn", (args and args.resume_args) or {}
    end

    self.pending_action = decide_choice_action(self.game, choice, self.pending_action)
    if not self.pending_action then
      return "wait_choice", args
    end

    local action = self.pending_action
    self.pending_action = nil

    -- 验证choice是否匹配
    if not matches_choice_action(choice, action) then
      return "wait_choice", args
    end

    local res = ChoiceResolver.resolve(self.game, choice, action)
    if res and res.stay then
      return "wait_choice", args
    end

    return (args and args.resume_state) or "end_turn", (args and args.resume_args) or {}
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
      local choice = Choice.get(self.game)
      if choice then
        self.pending_action = decide_choice_action(self.game, choice, nil)
      end
      if not self.pending_action then
        return "wait_choice"
      end
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
