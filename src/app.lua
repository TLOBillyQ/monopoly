local Board = require("src.core.board")
local Player = require("src.core.player")
local Inventory = require("src.core.inventory")
local constants = require("src.config.constants")
local roles_cfg = require("src.config.roles")
local logger = require("src.services.logger")
local TurnManager = require("src.services.turn_manager")

local App = {}
App.__index = App

function App.new(opts)
  local board = Board.new()
  local players = {}
  local names = opts.players or { "玩家1" }
  for i, name in ipairs(names) do
    local role = roles_cfg[((i - 1) % #roles_cfg) + 1]
    local player = Player.new({
      id = i,
      name = name,
      role_id = role.id,
      is_ai = opts.ai and opts.ai[i] or (i > 1),
      auto = opts.auto_all or false,
      start_index = 1,
      inventory = Inventory.new(),
    })
    table.insert(players, player)
  end

  local game = {
    board = board,
    players = players,
    current_player_index = 1,
    phase = "roll",
    overlays = { roadblocks = {}, mines = {} },
    occupants = {},
    path_history = {},
    turn_count = 0,
    logger = logger,
    finished = false,
    winner = nil,
    last_turn = nil,
  }
  setmetatable(game, App)
  game:rebuild_occupants()
  game.turn_manager = TurnManager.new(game)
  return game
end

function App:alive_players()
  local alive = {}
  for _, p in ipairs(self.players) do
    if not p.eliminated then
      table.insert(alive, p)
    end
  end
  return alive
end

function App:current_player()
  return self.players[self.current_player_index]
end

function App:rebuild_occupants()
  self.occupants = {}
  for _, p in ipairs(self.players) do
    if not p.eliminated then
      local idx = p.position
      self.occupants[idx] = self.occupants[idx] or {}
      table.insert(self.occupants[idx], p.id)
    end
  end
end

function App:update_player_position(player, new_index)
  for tile_idx, list in pairs(self.occupants) do
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
  player.position = new_index
  self.occupants[new_index] = self.occupants[new_index] or {}
  table.insert(self.occupants[new_index], player.id)
end

function App:run(max_rounds)
  max_rounds = max_rounds or 50
  for _ = 1, max_rounds do
    if self:check_victory() then
      break
    end
    self.turn_manager:run_turn()
  end
end

function App:check_victory()
  if self.finished then
    return true
  end
  local alive = self:alive_players()
  if #alive <= 1 then
    if #alive == 1 then
      self.logger.event("游戏结束，胜者:", alive[1].name)
      self.winner = alive[1]
    else
      self.logger.event("游戏结束，无人生还")
    end
    self.finished = true
    return true
  end
  return false
end

return App
