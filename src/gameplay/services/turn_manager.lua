local constants = require("src.config.constants")
local Dice = require("src.core.dice")
local MovementService = require("src.gameplay.services.movement_service")
local TileService = require("src.gameplay.services.tile_service")
local StatusService = require("src.gameplay.services.status_service")
local ItemService = require("src.gameplay.services.item_service")
local logger = require("src.gameplay.services.logger")
local Flow = require("src.gameplay.flow")
local phase_start_fn = require("src.gameplay.turn.start")
local phase_roll_fn = require("src.gameplay.turn.roll")
local phase_move_fn = require("src.gameplay.turn.move")
local phase_land_fn = require("src.gameplay.turn.land")
local phase_end_fn = require("src.gameplay.turn.end_turn")

local TurnManager = {}
TurnManager.__index = TurnManager

function TurnManager.new(game)
  local tm = {
    game = game,
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

function TurnManager:run_turn()
  local flow = Flow.new({
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
      end_turn = function(args)
        self.game.store:set({ "turn", "phase" }, "end_turn")
        return phase_end(self, args)
      end,
    },
  })
  while flow.current do
    flow:step()
  end
end

function TurnManager:end_turn(player)
  StatusService.tick_end_of_turn(player)
  player:clear_temporal_flags()
  self:next_player()
  if self.game.commit_state then
    self.game:commit_state()
  end
end

function TurnManager:next_player()
  local count = #self.game.players
  local current = self.game.store:get({ "turn", "current_player_index" }) or 1
  local next_index = current % count + 1
  self.game.store:set({ "turn", "current_player_index" }, next_index)
end

return TurnManager
