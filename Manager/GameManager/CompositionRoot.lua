
local BoardFactory = require("Manager.GameManager.BoardFactory")
local Player = require("Components.Player")
local PlayerVehicle = require("Manager.GameManager.PlayerVehicle")
local PlayerEffects = require("Manager.GameManager.PlayerEffects")
local Inventory = require("Components.Inventory")
local constants = require("Config.Constants")
local roles_cfg = require("Config.Roles")
local Tables = require("Library.Monopoly.Tables")
local RNG = require("Components.RNG")
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
local logger = require("Library.Monopoly.Logger")
local GameEvents = require("Library.Monopoly.GameEvents")
local market_cfg = require("Config.Market")

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
    inventory = require("Manager.ItemManager.Item.ItemInventory"),
    executor = require("Manager.ItemManager.Item.ItemExecutor"),
    strategy = require("Manager.ItemManager.Item.ItemStrategy"),
    item_phase = require("Manager.ItemManager.Item.ItemPhase"),
    effect = require("Manager.EffectManager.Effect.Effect"),
    landing_effects = require("Config.LandingEffects"),
    land_choice_handler = require("Manager.ChoiceManager.Choice.ChoiceHandlers.LandChoiceHandler"),
    market_choice_handler = require("Manager.ChoiceManager.Choice.ChoiceHandlers.MarketChoiceHandler"),
    item_choice_handler = require("Manager.ChoiceManager.Choice.ChoiceHandlers.ItemChoiceHandler"),
    optional_effect_handler = require("Manager.ChoiceManager.Choice.ChoiceHandlers.OptionalEffectHandler"),
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
    events = GameEvents.new(),
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

