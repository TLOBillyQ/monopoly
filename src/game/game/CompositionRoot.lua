
local board = require("src.game.board.Board")
local tile = require("src.game.board.Tile")
local player = require("src.game.player.Player")
local inventory = require("src.game.player.Inventory")
local constants = require("Config.Generated.Constants")
local roles_cfg = require("Config.Generated.Roles")
local tiles_cfg = require("Config.Generated.Tiles")
local map_cfg = require("Config.Map")
require "vendor.third_party.Utils"
local store = require("src.core.Store")
local turn_manager = require("src.game.turn.TurnManager")
local turn_start = require("src.game.turn.TurnStart")
local turn_roll = require("src.game.turn.TurnRoll")
local turn_move = require("src.game.turn.TurnMove")
local turn_land = require("src.game.turn.TurnLand")
local movement_manager = require("src.game.movement.MovementManager")
local market_manager = require("src.game.market.MarketManager")
local bankruptcy_manager = require("src.game.game.BankruptcyManager")
local choice_manager = require("src.game.choice.ChoiceManager")
local item_registry = require("src.game.item.ItemRegistry")
local item_phase = require("src.game.item.ItemPhase")
local chance_registry = require("src.game.chance.ChanceRegistry")
local logger = require("src.core.Logger")
local market_cfg = require("Config.Generated.Market")

local composition_root = {}

local deep_copy = Utils.deep_copy

local function _new_rng(seed)
  assert(seed ~= nil, "missing rng seed")
  local rng = {
    seed = seed,
    state = seed,
  }

  function rng:next_int(min, max)
    assert(min ~= nil and max ~= nil, "rng.NextInt requires min/max")
    local curr = self.state
    assert(curr ~= nil, "missing rng state")
    curr = (curr * 1103515245 + 12345) % 2147483648
    self.state = curr
    local span = max - min + 1
    assert(span > 0, "invalid rng span: " .. tostring(span))
    return min + (curr % span)
  end

  function rng:snapshot()
    return { seed = self.seed, state = self.state }
  end

  return rng
end


local function _create_board(opts)
  assert(opts ~= nil, "missing board opts")
  local tiles = assert(opts.tiles, "missing tiles config")
  local map_cfg = assert(opts.map, "missing map config")

  local tile_lookup = {}
  for _, cfg in ipairs(tiles) do
    tile_lookup[cfg.id] = tile:new(cfg)
  end

  local path = {}
  for _, id in ipairs(map_cfg.path) do
    table.insert(path, tile_lookup[id])
  end

  return board:new({
    path = path,
    tile_lookup = tile_lookup,
    branches = map_cfg.branches,
    map = map_cfg,
    overlays = { roadblocks = {}, mines = {} },
  })
end

local function _create_players(opts)
  local players = {}
  local names = assert(opts.players, "missing player names")
  if #names == 1 then
    names = { names[1], "玩家2", "玩家3", "玩家4" }
  end
  for i, name in ipairs(names) do
    local role = roles_cfg[((i - 1) % #roles_cfg) + 1]
    local is_ai = opts.ai[i]
    local player = player:new({
      id = i,
      name = name,
      role_id = role.id,
      is_ai = is_ai,
      auto = opts.auto_all,
      start_index = 1,
      constants = constants,
      balances = {
        ["金币"] = constants.starting_cash,
        ["金豆"] = constants.starting_jindou,
        ["乐园币"] = constants.starting_leyuanbi,
      },
      deity_duration_turns = constants.deity_duration_turns,
      inventory = inventory:new({ constants = constants }),
    })
    table.insert(players, player)
  end
  return players
end

local function _snapshot_inventory(inv)
  return { items = deep_copy(inv.items), max_slots = inv.max_slots }
end

local function _snapshot_players(players)
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
      inventory = _snapshot_inventory(p.inventory),
    }
  end
  return ps
end

local function _snapshot_tiles(path)
  local ts = {}
  for _, tile in ipairs(path) do
    if tile.type == "land" then
      ts[tile.id] = { owner_id = nil, level = 0 }
    end
  end
  return ts
end

local function _snapshot_market_limits()
  local limits = {}
  for _, entry in ipairs(market_cfg) do
    local limit = entry.limit
    if type(limit) == "number" and limit >= 1 then
      limits[entry.product_id] = limit
    end
  end
  return limits
end

local function _build_initial_state(board, players, rng)
  return {
    board = { tiles = _snapshot_tiles(board.path) },
    market = { global_limits = _snapshot_market_limits() },
    turn = {
      current_player_index = 1,
      turn_count = 0,
      countdown_seconds = 0,
      countdown_active = false,
      phase = "start",
      pending_choice = nil,
      choice_seq = 0,
      move_anim_seq = 0,
      move_anim = nil,
      action_anim_seq = 0,
      action_anim = nil,
      item_phase = {},
      item_phase_active = "",
    },
    rng = rng:snapshot(),
    players = _snapshot_players(players),
  }
end

local function _phase_post(tm, args)
  local player = args.player or tm.game:current_player()
  local phase_res = item_phase.run(tm, "post_action", {
    player = player,
    resume_state = "post_action",
    resume_args = { player = player },
  })
  if phase_res and phase_res.waiting then
    local resume_state = phase_res.resume_state or "post_action"
    local resume_args = phase_res.resume_args or { player = player }
    if phase_res.wait_action_anim then
      return "wait_action_anim", { resume_state = resume_state, resume_args = resume_args }
    end
    return "wait_choice", { resume_state = resume_state, resume_args = resume_args }
  end
  return "end_turn", { player = player }
end

local function _phase_end(tm, args)
  local player = args.player
  player:tick_deity()
  player:clear_temporal_flags()
  assert(tm.game ~= nil and tm.game.store ~= nil, "missing game/store")
  tm.game.store:set({ "turn", "market_prompt" }, nil)
  tm.game.store:set({ "turn", "post_action" }, nil)
  tm.game.store:set({ "turn", "item_phase" }, {})
  tm.game.store:set({ "turn", "item_phase_active" }, "")
  tm:next_player()
  return nil
end

function composition_root.assemble(opts, game_or_class)
  assert(opts ~= nil, "missing assemble opts")

  local board = _create_board(opts)
  local rng = _new_rng(opts.seed)
  local players = _create_players(opts)

  local initial_state = _build_initial_state(board, players, rng)
  local store = store:new(initial_state)

  rng._store = store

  for _, p in ipairs(players) do
    p._store = store
    local pid = p.id
    p.inventory._on_change = function(inv)
      store:set({ "players", pid, "inventory" }, _snapshot_inventory(inv))
    end
  end

  item_registry.register_defaults()
  chance_registry.register_defaults()
  local phases = {
    start = turn_start,
    roll = turn_roll,
    move = turn_move,
    landing = turn_land,
    post_action = _phase_post,
    end_turn = _phase_end,
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
  game.logger = logger
  game.finished = false
  game.winner = nil
  game.last_turn = nil
  game._land_rent_version = 0
  game._land_rent_cache = nil

  game:rebuild()
  game.turn_manager = turn_manager:new(game, phases)

  return game
end

composition_root.snapshot_inventory = _snapshot_inventory

return composition_root
