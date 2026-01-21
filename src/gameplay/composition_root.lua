
local BoardFactory = require("src.gameplay.board_factory")
local Player = require("src.core.player")
local PlayerVehicle = require("src.gameplay.player_vehicle")
local PlayerEffects = require("src.gameplay.player_effects")
local Inventory = require("src.core.inventory")
local constants = require("src.config.constants")
local roles_cfg = require("src.config.roles")
local Tables = require("src.util.tables")
local RNG = require("src.core.rng")
local Store = require("src.core.store")
local TurnManager = require("src.gameplay.turn_manager")
local turn_start = require("src.gameplay.turn_start")
local turn_roll = require("src.gameplay.turn_roll")
local turn_move = require("src.gameplay.turn_move")
local turn_land = require("src.gameplay.turn_land")
local turn_post = require("src.gameplay.turn_post")
local turn_end = require("src.gameplay.turn_end")
local MovementService = require("src.gameplay.movement_service")
local MarketService = require("src.gameplay.market_service")
local BankruptcyService = require("src.gameplay.bankruptcy_service")
local ChoiceService = require("src.gameplay.choice_service")
local logger = require("src.util.logger")

local CompositionRoot = {}

local deep_copy = Tables.deep_copy


local function create_board(opts)
  return BoardFactory.create(opts)
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
    local player = Player.new({
      id = i,
      name = name,
      role_id = role.id,
      is_ai = is_ai,
      auto = opts.auto_all or false,
      start_index = 1,
      constants = constants,
      inventory = Inventory.new({ constants = constants }),
    })
    for key, fn in pairs(PlayerVehicle) do
      player[key] = fn
    end
    for key, fn in pairs(PlayerEffects) do
      player[key] = fn
    end
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

local function build_initial_state(board, players, rng)
  return {
    board = { tiles = snapshot_tiles(board.path) },
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
end


function CompositionRoot.assemble(opts, GameClass)
  opts = opts or {}

  local board = create_board(opts)
  local rng = RNG.new(opts.seed)
  local players = create_players(opts)

  local initial_state = build_initial_state(board, players, rng)
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

  ChoiceService.setup({
    inventory = require("src.gameplay.item_inventory"),
    executor = require("src.gameplay.item_executor"),
    strategy = require("src.gameplay.item_strategy"),
    item_phase = require("src.gameplay.item_phase"),
    effect = require("src.gameplay.effect"),
    landing_effects = require("src.config.landing_effects"),
    land_choice_handler = require("src.gameplay.choice_handlers.land_choice_handler"),
    market_choice_handler = require("src.gameplay.choice_handlers.market_choice_handler"),
    item_choice_handler = require("src.gameplay.choice_handlers.item_choice_handler"),
    optional_effect_handler = require("src.gameplay.choice_handlers.optional_effect_handler"),
  })
  local phases = {
    start = turn_start,
    roll = turn_roll,
    move = turn_move,
    landing = turn_land,
    post_action = turn_post,
    end_turn = turn_end,
  }
  local services = {
    movement = MovementService,
    market = MarketService,
    bankruptcy = BankruptcyService,
    choice = ChoiceService,
  }

  local game = setmetatable({
    board = board,
    players = players,
    store = store,
    rng = rng,
    logger = logger,
    finished = false,
    winner = nil,
    last_turn = nil,
    services = services,
  }, GameClass)

  game:rebuild()
  game.turn_manager = TurnManager.new(game, phases)

  return game
end

CompositionRoot.snapshot_inventory = snapshot_inventory

return CompositionRoot
