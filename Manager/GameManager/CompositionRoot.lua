
local Board = require("Components.Board")
local Tile = require("Components.Tile")
local Player = require("Components.Player")
local Inventory = require("Components.Inventory")
local constants = require("Config.Generated.Constants")
local roles_cfg = require("Config.Generated.Roles")
local tiles_config = require("Config.Generated.Tiles")
local map_config = require("Config.Map")
require "Library.Utils"
local Store = require("Components.Store")
local TurnManager = require("Manager.TurnManager.Turn.TurnManager")
local turn_start = require("Manager.TurnManager.Turn.TurnStart")
local turn_roll = require("Manager.TurnManager.Turn.TurnRoll")
local turn_move = require("Manager.TurnManager.Turn.TurnMove")
local turn_land = require("Manager.TurnManager.Turn.TurnLand")
local turn_post = require("Manager.TurnManager.Turn.TurnPost")
local turn_end = require("Manager.TurnManager.Turn.TurnEnd")
local MovementService = require("Manager.MovementManager.Movement.MovementService")
local MarketService = require("Manager.MarketManager.Market.MarketService")
local BankruptcyService = require("Manager.GameManager.BankruptcyService")
local ChoiceService = require("Manager.ChoiceManager.Choice.ChoiceService")
local ItemRegistry = require("Manager.ItemManager.Item.ItemRegistry")
local ChanceRegistry = require("Manager.ChanceManager.ChanceRegistry")
local logger = require("Library.Monopoly.Logger")
local market_cfg = require("Config.Generated.Market")
local SERVICE_KEY = require("Globals.ServiceKeys")

local CompositionRoot = {}

local deep_copy = Utils.deep_copy

local function new_rng(seed, state)
  local rng = {
    seed = seed or 1,
    state = state or (seed or 1),
  }

  function rng:next_int(min, max)
    min = min or 0
    max = max or 1
    if GameAPI and GameAPI.random_int then
      return GameAPI.random_int(min, max)
    end
    local curr = self.state or self.seed or 1
    curr = (curr * 1103515245 + 12345) % 2147483648
    self.state = curr
    local span = max - min + 1
    if span <= 0 then
      return min
    end
    return min + (curr % span)
  end

  function rng:snapshot()
    return { seed = self.seed, state = self.state }
  end

  return rng
end


local function create_board(opts)
  opts = opts or {}
  local tiles = opts.tiles or tiles_config
  local map_cfg = opts.map or map_config

  local tile_lookup = {}
  for _, cfg in ipairs(tiles) do
    tile_lookup[cfg.id] = Tile:new(cfg)
  end

  local path = {}
  for _, id in ipairs(map_cfg.path) do
    table.insert(path, tile_lookup[id])
  end

  return Board:new({
    path = path,
    tile_lookup = tile_lookup,
    branches = map_cfg.branches or {},
    map = map_cfg,
    overlays = { roadblocks = {}, mines = {} },
  })
end

local function create_players(opts)
  local players = {}
  local names = opts.players or { "玩家1" }
  if #names == 1 then
    names = { names[1], "玩家2", "玩家3", "玩家4" }
  end
  for i, name in ipairs(names) do
    local role = roles_cfg[((i - 1) % #roles_cfg) + 1]
    local is_ai = i > 1
    if opts.ai ~= nil then
      is_ai = opts.ai[i]
    end
    local player = Player:new({
      id = i,
      name = name,
      role_id = role.id,
      is_ai = is_ai,
      auto = opts.auto_all or false,
      start_index = 1,
      constants = constants,
      inventory = Inventory:new({ constants = constants }),
    })
    table.insert(players, player)
  end
  return players
end

local function snapshot_inventory(inv)
  return { items = deep_copy(inv.items), max_slots = inv.max_slots }
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
      balances = deep_copy(p.balances),
      position = p.position,
      seat_id = p.seat_id,
      eliminated = p.eliminated,
      properties = deep_copy(p.properties),
      status = deep_copy(p.status),
      inventory = snapshot_inventory(p.inventory),
    }
  end
  return ps
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

local function snapshot_market_limits()
  local limits = {}
  for _, entry in ipairs(market_cfg) do
    local limit = entry.limit
    if type(limit) == "number" and limit >= 1 then
      limits[entry.product_id] = limit
    end
  end
  return limits
end

local function build_initial_state(board, players, rng)
  return {
    board = { tiles = snapshot_tiles(board.path) },
    market = { global_limits = snapshot_market_limits() },
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
    },
    rng = rng:snapshot(),
    players = snapshot_players(players),
  }
end


function CompositionRoot.assemble(opts, game_or_class)
  opts = opts or {}

  local board = create_board(opts)
  local rng = new_rng(opts.seed)
  local players = create_players(opts)

  local initial_state = build_initial_state(board, players, rng)
  local store = Store:new(initial_state)

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

  ItemRegistry.register_defaults()
  ChanceRegistry.register_defaults()
  local phases = {
    start = turn_start,
    roll = turn_roll,
    move = turn_move,
    landing = turn_land,
    post_action = turn_post,
    end_turn = turn_end,
  }
  local services = {
    [SERVICE_KEY.movement] = MovementService,
    [SERVICE_KEY.market] = MarketService,
    [SERVICE_KEY.bankruptcy] = BankruptcyService,
    [SERVICE_KEY.choice] = ChoiceService,
  }

  local game = game_or_class
  if type(game_or_class) == "table" and rawget(game_or_class, "__name") and rawget(game_or_class, "new") then
    game = game_or_class:new({ __skip_assemble = true })
  end
  assert(game, "CompositionRoot.assemble requires game instance or class")
  game.board = board
  game.players = players
  game.store = store
  game.rng = rng
  game.logger = logger
  game.finished = false
  game.winner = nil
  game.last_turn = nil
  game.services = services

  game:rebuild()
  game.turn_manager = TurnManager:new(game, phases)

  return game
end

CompositionRoot.snapshot_inventory = snapshot_inventory

return CompositionRoot
