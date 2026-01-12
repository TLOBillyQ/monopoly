local BoardFactory = require("src.bootstrap.board_factory")
local Player = require("src.core.player")
local Inventory = require("src.core.inventory")
local constants = require("src.config.constants")
local roles_cfg = require("src.config.roles")
local logger = require("src.util.logger")
local TurnManager = require("src.gameplay.app.services.turn_manager")
local TileService = require("src.gameplay.app.services.tile_service")
local ChanceService = require("src.gameplay.app.services.chance_service")
local MovementService = require("src.gameplay.app.services.movement_service")
local ItemService = require("src.gameplay.app.services.item_service")
local MarketService = require("src.gameplay.app.services.market_service")
local StatusService = require("src.gameplay.app.services.status_service")
local BankruptcyService = require("src.gameplay.app.services.bankruptcy_service")
local RNG = require("src.gameplay.infra.rng")
local Store = require("src.gameplay.infra.store")
local App = {}
App.__index = App

local function create_players(opts)
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
      constants = constants,
      inventory = Inventory.new({ constants = constants }),
    })
    table.insert(players, player)
  end
  return players
end

local function snapshot_players(players)
  local ps = {}
  for _, p in ipairs(players) do
    ps[p.id] = {
      id = p.id,
      cash = p.cash,
      position = p.position,
      properties = p.properties,
      status = p.status,
    }
  end
  return ps
end

local function snapshot_tiles(path)
  local ts = {}
  for _, tile in ipairs(path) do
    if tile.type == "land" then
      ts[tile.id] = { owner_id = tile.owner_id, level = tile.level }
    end
  end
  return ts
end

function App.new(opts)
  opts = opts or {}
  local board = BoardFactory.create()
  local rng = RNG.new(opts.seed)
  local players = create_players(opts)

  local initial_state = {
    board = {
      overlays = { roadblocks = {}, mines = {} },
      tiles = snapshot_tiles(board.path),
    },
    turn = {
      current_player_index = 1,
      turn_count = 0,
      phase = "start",
      pending_choice = nil,
      choice_seq = 0,
    },
    rng = rng:snapshot(),
    players = snapshot_players(players),
  }
  local store = Store.new(initial_state)

  local game = {
    board = board,
    players = players,
    store = store,
    rng = rng,
    turn_count = initial_state.turn.turn_count,
    overlays = initial_state.board.overlays,
    logger = logger,
    finished = false,
    winner = nil,
    last_turn = nil,
    services = {
      tile = TileService,
      chance = ChanceService,
      movement = MovementService,
      item = ItemService,
      market = MarketService,
      status = StatusService,
      bankruptcy = BankruptcyService,
    },
  }
  setmetatable(game, App)
  game:rebuild_occupants()
  game.turn_manager = TurnManager.new(game)
  function game:commit_state()
    -- tiles
    local tiles_snapshot = snapshot_tiles(self.board.path)
    self.store:set({ "board", "tiles" }, tiles_snapshot)
    -- overlays
    self.store:set({ "board", "overlays" }, self.overlays)
    -- players
    self.store:set({ "players" }, snapshot_players(self.players))
    -- turn
    self.store:set({ "turn", "turn_count" }, self.turn_count or 0)
    local idx = self.store:get({ "turn", "current_player_index" }) or 1
    self.store:set({ "turn", "current_player_index" }, idx)
    -- rng
    self.store:set({ "rng" }, self.rng:snapshot())
  end
  local Sync = require("src.gameplay.infra.sync")
  Sync.sync_all(game)
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
  local idx = self.store:get({ "turn", "current_player_index" }) or 1
  return self.players[idx]
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
  self.store:set({ "board", "overlays" }, self.store:get({ "board", "overlays" }) or { roadblocks = {}, mines = {} })
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
