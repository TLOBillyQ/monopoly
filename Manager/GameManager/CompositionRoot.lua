
local Board = require("Components.Board")
local Tile = require("Components.Tile")
local Player = require("Components.Player")
local Inventory = require("Components.Inventory")
local Constants = require("Config.Generated.Constants")
local RolesCfg = require("Config.Generated.Roles")
local TilesCfg = require("Config.Generated.Tiles")
local MapCfg = require("Config.Map")
require "Library.Utils"
local Store = require("Components.Store")
local TurnManager = require("Manager.TurnManager.TurnManager")
local TurnStart = require("Manager.TurnManager.TurnStart")
local TurnRoll = require("Manager.TurnManager.TurnRoll")
local TurnMove = require("Manager.TurnManager.TurnMove")
local TurnLand = require("Manager.TurnManager.TurnLand")
local TurnPost = require("Manager.TurnManager.TurnPost")
local TurnEnd = require("Manager.TurnManager.TurnEnd")
local MovementManager = require("Manager.MovementManager.MovementManager")
local MarketManager = require("Manager.MarketManager.MarketManager")
local BankruptcyManager = require("Manager.GameManager.BankruptcyManager")
local ChoiceManager = require("Manager.ChoiceManager.ChoiceManager")
local ItemRegistry = require("Manager.ItemManager.ItemRegistry")
local ChanceRegistry = require("Manager.ChanceManager.ChanceRegistry")
local Logger = require("Components.Logger")
local MarketCfg = require("Config.Generated.Market")

local CompositionRoot = {}

local deep_copy = Utils.deep_copy

local function _NewRng(seed)
  assert(seed ~= nil, "missing rng seed")
  local rng = {
    seed = seed,
    state = seed,
  }

  function rng:NextInt(min, max)
    assert(min ~= nil and max ~= nil, "rng.NextInt requires min/max")
    local curr = self.state
    assert(curr ~= nil, "missing rng state")
    curr = (curr * 1103515245 + 12345) % 2147483648
    self.state = curr
    local span = max - min + 1
    assert(span > 0, "invalid rng span: " .. tostring(span))
    return min + (curr % span)
  end

  function rng:Snapshot()
    return { seed = self.seed, state = self.state }
  end

  return rng
end


local function _CreateBoard(opts)
  assert(opts ~= nil, "missing board opts")
  local tiles = assert(opts.tiles, "missing tiles config")
  local MapCfg = assert(opts.map, "missing map config")

  local tile_lookup = {}
  for _, cfg in ipairs(tiles) do
    tile_lookup[cfg.id] = Tile:new(cfg)
  end

  local path = {}
  for _, id in ipairs(MapCfg.path) do
    table.insert(path, tile_lookup[id])
  end

  return Board:new({
    path = path,
    tile_lookup = tile_lookup,
    branches = MapCfg.branches,
    map = MapCfg,
    overlays = { roadblocks = {}, mines = {} },
  })
end

local function _CreatePlayers(opts)
  local players = {}
  local names = assert(opts.players, "missing player names")
  if #names == 1 then
    names = { names[1], "玩家2", "玩家3", "玩家4" }
  end
  for i, name in ipairs(names) do
    local role = RolesCfg[((i - 1) % #RolesCfg) + 1]
    local is_ai = opts.ai[i]
    local player = Player:new({
      id = i,
      name = name,
      role_id = role.id,
      is_ai = is_ai,
      auto = opts.auto_all,
      start_index = 1,
      constants = Constants,
      balances = {
        ["金币"] = Constants.starting_cash,
        ["金豆"] = Constants.starting_jindou,
        ["乐园币"] = Constants.starting_leyuanbi,
      },
      deity_duration_turns = Constants.deity_duration_turns,
      inventory = Inventory:new({ constants = Constants }),
    })
    table.insert(players, player)
  end
  return players
end

local function _SnapshotInventory(inv)
  return { items = deep_copy(inv.items), max_slots = inv.max_slots }
end

local function _SnapshotPlayers(players)
  local ps = {}
  for _, p in ipairs(players) do
    ps[p.id] = {
      id = p.id,
      name = p.name,
      role_id = p.role_id,
      is_ai = p.is_ai,
      auto = p.auto,
      cash = p.cash,
      balances = deep_copy(p.balances),
      position = p.position,
      seat_id = p.seat_id,
      eliminated = p.eliminated,
      properties = deep_copy(p.properties),
      status = deep_copy(p.status),
      inventory = _SnapshotInventory(p.inventory),
    }
  end
  return ps
end

local function _SnapshotTiles(path)
  local ts = {}
  for _, tile in ipairs(path) do
    if tile.type == "land" then
      ts[tile.id] = { owner_id = nil, level = 0 }
    end
  end
  return ts
end

local function _SnapshotMarketLimits()
  local limits = {}
  for _, entry in ipairs(MarketCfg) do
    local limit = entry.limit
    if type(limit) == "number" and limit >= 1 then
      limits[entry.product_id] = limit
    end
  end
  return limits
end

local function _BuildInitialState(board, players, rng)
  return {
    board = { tiles = _SnapshotTiles(board.path) },
    market = { global_limits = _SnapshotMarketLimits() },
    turn = {
      current_player_index = 1,
      turn_count = 0,
      phase = "start",
      pending_choice = nil,
      choice_seq = 0,
      move_anim_seq = 0,
      move_anim = nil,
      action_anim_seq = 0,
      action_anim = nil,
      item_phase = {},
    },
    rng = rng:Snapshot(),
    players = _SnapshotPlayers(players),
  }
end


function CompositionRoot.Assemble(opts, game_or_class)
  assert(opts ~= nil, "missing assemble opts")

  local board = _CreateBoard(opts)
  local rng = _NewRng(opts.seed)
  local players = _CreatePlayers(opts)

  local initial_state = _BuildInitialState(board, players, rng)
  local store = Store:new(initial_state)

  rng._store = store

  for _, p in ipairs(players) do
    p._store = store
    local pid = p.id
    p.inventory._on_change = function(inv)
      store:Set({ "players", pid, "inventory" }, _SnapshotInventory(inv))
    end
  end

  ItemRegistry.RegisterDefaults()
  ChanceRegistry.RegisterDefaults()
  local phases = {
    start = TurnStart,
    roll = TurnRoll,
    move = TurnMove,
    landing = TurnLand,
    post_action = TurnPost,
    end_turn = TurnEnd,
  }
  local game = game_or_class
  if type(game_or_class) == "table" and rawget(game_or_class, "__name") and rawget(game_or_class, "new") then
    game = game_or_class:new({ __skip_assemble = true })
  end
  assert(game, "CompositionRoot.Assemble requires game instance or class")
  game.board = board
  game.players = players
  game.store = store
  game.rng = rng
  game.Logger = Logger
  game.finished = false
  game.winner = nil
  game.last_turn = nil

  game:Rebuild()
  game.turn_manager = TurnManager:new(game, phases)

  return game
end

CompositionRoot.SnapshotInventory = _SnapshotInventory

return CompositionRoot
