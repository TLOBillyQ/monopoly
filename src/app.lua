local Bootstrap = require("src.gameplay.app.bootstrap")
local logger = require("src.util.logger")
local TurnManager = require("src.gameplay.app.services.turn_manager")
local TurnUsecase = require("src.gameplay.app.usecases.turn_usecase")
local ActionUsecase = require("src.gameplay.app.usecases.action_usecase")
local TileService = require("src.gameplay.app.services.tile_service")
local ChanceService = require("src.gameplay.app.services.chance_service")
local MovementService = require("src.gameplay.app.services.movement_service")
local ItemService = require("src.gameplay.app.services.item_service")
local MarketService = require("src.gameplay.app.services.market_service")
local StatusService = require("src.gameplay.app.services.status_service")
local BankruptcyService = require("src.gameplay.app.services.bankruptcy_service")
local OverlayService = require("src.gameplay.app.services.overlay_service")
local RNG = require("src.gameplay.infra.rng")
local Store = require("src.gameplay.infra.store")
local Tables = require("src.util.tables")
local App = {}
App.__index = App



local deep_copy = Tables.deep_copy

local function store_value(v)
  if type(v) == "table" then
    return deep_copy(v)
  end
  return v
end

local REQUIRED_SERVICES = {
  "movement",
  "tile",
  "chance",
  "item",
  "market",
  "status",
  "bankruptcy",
  "overlay",
}

local function validate_services(services)
  for _, key in ipairs(REQUIRED_SERVICES) do
    assert(services[key] ~= nil, "缺少必要服务：" .. key)
  end
end

function App.new(opts)
  opts = opts or {}
  local board = Bootstrap.create_board(opts)
  local rng = RNG.new(opts.seed)
  local players = Bootstrap.create_players(opts)

  local initial_state = Bootstrap.build_initial_state(board, players, rng)
  local store = Store.new(initial_state)

  rng._store = store

  for _, p in ipairs(players) do
    p._store = store
    if p.inventory then
      local pid = p.id
      p.inventory._on_change = function(inv)
        store:set({ "players", pid, "inventory" }, Bootstrap.snapshot_inventory(inv))
      end
    end
  end

  local game = {
    board = board,
    players = players,
    store = store,
    rng = rng,
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
      overlay = OverlayService,
    },
  }
  setmetatable(game, App)
  validate_services(game.services)
  game:rebuild_occupants()
  local turn_usecase = TurnUsecase.new(game)
  game.turn_manager = turn_usecase.turn_manager
  game.turn_usecase = turn_usecase
  game.action_usecase = ActionUsecase.new({ game = game, turn_usecase = turn_usecase })
  return game
end


function App:_store_set(path, value)
  if self.store then
    self.store:set(path, store_value(value))
  end
end


function App:set_player_status(player, key, value)
  player.status[key] = value
  self:_store_set({ "players", player.id, "status", key }, value)
end


function App:set_player_seat(player, seat_id)
  player.seat_id = seat_id
  self:_store_set({ "players", player.id, "seat_id" }, seat_id)
end


function App:set_player_eliminated(player, eliminated)
  player.eliminated = eliminated and true or false
  self:_store_set({ "players", player.id, "eliminated" }, player.eliminated)
end


function App:set_player_property(player, tile_id, owned)
  if owned then
    player.properties[tile_id] = true
  else
    player.properties[tile_id] = nil
  end
  self:_store_set({ "players", player.id, "properties", tile_id }, owned and true or nil)
end


function App:sync_player_inventory(player)
  if player.inventory then
    self:_store_set({ "players", player.id, "inventory" }, Bootstrap.snapshot_inventory(player.inventory))
  end
end


function App:set_tile_owner(tile, owner_id)
  if tile and tile.type == "land" then
    self:_store_set({ "board", "tiles", tile.id, "owner_id" }, owner_id)
  end
end


function App:set_tile_level(tile, level)
  if tile and tile.type == "land" then
    self:_store_set({ "board", "tiles", tile.id, "level" }, level)
  end
end


function App:reset_tile(tile)
  if tile and tile.type == "land" then
    self:_store_set({ "board", "tiles", tile.id, "owner_id" }, nil)
    self:_store_set({ "board", "tiles", tile.id, "level" }, 0)
  end
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
  self:_store_set({ "players", player.id, "position" }, new_index)
  self.occupants[new_index] = self.occupants[new_index] or {}
  table.insert(self.occupants[new_index], player.id)
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
