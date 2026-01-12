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
      name = p.name,
      role_id = p.role_id,
      is_ai = p.is_ai,
      auto = p.auto,
      cash = p.cash,
      position = p.position,
      seat_id = p.seat_id,
      eliminated = p.eliminated,
      properties = deep_copy(p.properties),
      status = deep_copy(p.status),
      inventory = { items = deep_copy(p.inventory.items), max_slots = p.inventory.max_slots },
    }
  end
  return ps
end

local function snapshot_inventory(inv)
  return { items = deep_copy(inv.items), max_slots = inv.max_slots }
end

local function snapshot_tiles(path)
  local ts = {}
  for _, tile in ipairs(path) do
    if tile.type == "land" then
      ts[tile.id] = { owner_id = nil, level = 0 }
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

  rng._store = store

  for _, p in ipairs(players) do
    p._store = store
    if p.inventory then
      local pid = p.id
      p.inventory._on_change = function(inv)
        store:set({ "players", pid, "inventory" }, snapshot_inventory(inv))
      end
    end
  end

  -- Store is the source of truth; keep mutable overlay refs pointing at store state.
  local overlays_ref = store:get({ "board", "overlays" })

  local game = {
    board = board,
    players = players,
    store = store,
    rng = rng,
    overlays = overlays_ref,
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
    self:_store_set({ "players", player.id, "inventory" }, snapshot_inventory(player.inventory))
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
