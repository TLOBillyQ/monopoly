local Flow = require("src.gameplay.app.flow")
local Choice = require("src.gameplay.app.choice")
local ChoiceResolver = require("src.gameplay.app.choice_resolver")
local phase_start_fn = require("src.gameplay.app.turn.start")
local phase_roll_fn = require("src.gameplay.app.turn.roll")
local phase_move_fn = require("src.gameplay.app.turn.move")
local phase_land_fn = require("src.gameplay.app.turn.land")
local phase_end_fn = require("src.gameplay.app.turn.end_turn")

local TurnManager = {}
TurnManager.__index = TurnManager

function TurnManager.new(game)
  local tm = {
    game = game,
    flow = nil,
    pending_action = nil,
  }
  return setmetatable(tm, TurnManager)
end

local function phase_start(tm)
  return phase_start_fn(tm)
end

local function phase_roll(tm, args)
  return phase_roll_fn(tm, args)
end

local function phase_move(tm, args)
  return phase_move_fn(tm, args)
end

local function phase_land(tm, args)
  return phase_land_fn(tm, args)
end

local function phase_end(tm, args)
  return phase_end_fn(tm, args)
end

function TurnManager:dispatch(action)
  self.pending_action = action

  -- If a choice is pending but the flow isn't running (e.g., UI-triggered choices),
  -- resolve it immediately to avoid stalling auto-play.
  local choice = Choice.get(self.game)
  if choice and (not self.flow or not self.flow.current) then
    local res = ChoiceResolver.resolve(self.game, choice, action)
    if self.game and self.game.commit_state then
      self.game:commit_state()
    end
    self.pending_action = nil
    return res
  end

  if self.flow and self.flow.current then
    self:run_until_wait()
  end
end

function TurnManager:_build_flow()
  return Flow.new({
    start = "start",
    states = {
      start = function(args)
        self.game.store:set({ "turn", "phase" }, "start")
        return phase_start(self, args)
      end,
      roll = function(args)
        self.game.store:set({ "turn", "phase" }, "roll")
        return phase_roll(self, args)
      end,
      move = function(args)
        self.game.store:set({ "turn", "phase" }, "move")
        return phase_move(self, args)
      end,
      land = function(args)
        self.game.store:set({ "turn", "phase" }, "land")
        return phase_land(self, args)
      end,
      wait_choice = function(args)
        self.game.store:set({ "turn", "phase" }, "wait_choice")
        local choice = Choice.get(self.game)
        -- If we are in wait_choice but the choice has been cleared externally,
        -- resume immediately to avoid a tight loop that can freeze auto-play.
        if not choice then
          self.pending_action = nil
          return (args and args.resume_state) or "end_turn", (args and args.resume_args) or {}
        end

        if not self.pending_action then
          return "wait_choice", args
        end
        local action = self.pending_action
        self.pending_action = nil

        -- Ignore stale actions targeting a different choice id.
        if action.choice_id and choice.id and action.choice_id ~= choice.id then
          return "wait_choice", args
        end
        local res = ChoiceResolver.resolve(self.game, choice, action)
        if self.game and self.game.commit_state then
          self.game:commit_state()
        end
        if res and res.stay then
          return "wait_choice", args
        end
        return args and args.resume_state, args and args.resume_args
      end,
      end_turn = function(args)
        self.game.store:set({ "turn", "phase" }, "end_turn")
        return phase_end(self, args)
      end,
    },
  })
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
    if self.game and self.game.commit_state then
      self.game:commit_state()
    end
  end

  self.flow = nil
  return nil
end

-- Backward-compatible name: historically ran a full turn synchronously.
-- Now runs until finished or paused at wait_choice.
function TurnManager:run_turn()
  return self:run_until_wait()
end

return TurnManager
