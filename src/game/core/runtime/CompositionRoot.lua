
local board = require("src.game.systems.board.Board")
local tile = require("src.game.systems.board.Tile")
local player = require("src.game.core.player.Player")
local inventory = require("src.game.core.player.Inventory")
local constants = require("Config.Generated.Constants")
local roles_cfg = require("Config.Generated.Roles")
local tiles_cfg = require("Config.Generated.Tiles")
local map_cfg = require("Config.Map")
require "vendor.third_party.Utils"
local dirty_tracker = require("src.core.DirtyTracker")
local turn_flow = require("src.game.flow.turn.TurnFlow")
local turn_start = require("src.game.flow.turn.TurnStart")
local turn_roll = require("src.game.flow.turn.TurnRoll")
local turn_move = require("src.game.flow.turn.TurnMove")
local turn_land = require("src.game.flow.turn.TurnLand")
local movement = require("src.game.systems.movement.Movement")
local market = require("src.game.systems.market.Market")
local bankruptcy = require("src.game.core.runtime.Bankruptcy")
local choice_registry = require("src.game.systems.choices.ChoiceRegistry")
local item_registry = require("src.game.systems.items.ItemRegistry")
local item_phase = require("src.game.systems.items.ItemPhase")
local chance_registry = require("src.game.systems.chance.ChanceRegistry")
local logger = require("src.core.Logger")
local market_cfg = require("Config.Generated.Market")

local composition_root = {}

local deep_copy = Utils.deep_copy

local function _new_rng()
  local rng = {}
  function rng:next_int(min, max)
    assert(min ~= nil and max ~= nil, "rng.NextInt requires min/max")
    assert(GameAPI and GameAPI.random_int, "missing GameAPI.random_int")
    return GameAPI.random_int(min, max)
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
  local ai_map = opts.ai or {}
  local role_roster = opts.role_roster

  if type(role_roster) == "table" and #role_roster > 0 then
    for i, entry in ipairs(role_roster) do
      local role_id = entry and (entry.role_id or entry.id) or nil
      assert(role_id ~= nil, "missing role_id in role_roster: " .. tostring(i))
      local name = entry and entry.name or nil
      if not name or name == "" then
        name = "玩家" .. tostring(i)
      end
      local is_ai = ai_map[role_id] or ai_map[i]
      local player = player:new({
        id = role_id,
        name = name,
        role_id = role_id,
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

  local names = assert(opts.players, "missing player names")
  if #names == 1 then
    names = { names[1], "玩家2", "玩家3", "玩家4" }
  end
  for i, name in ipairs(names) do
    local role = roles_cfg[((i - 1) % #roles_cfg) + 1]
    local is_ai = ai_map[i]
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

local function _build_player_by_id(players)
  local out = {}
  for _, p in ipairs(players or {}) do
    if p and p.id ~= nil then
      out[p.id] = p
    end
  end
  return out
end

local function _snapshot_inventory(inv)
  return { items = deep_copy(inv.items), max_slots = inv.max_slots }
end

local function _init_tile_state(board)
  for _, t in ipairs(board.path) do
    if t.type == "land" then
      t.owner_id = nil
      t.level = 0
    end
  end
end

local function _build_market_limits()
  local limits = {}
  for _, entry in ipairs(market_cfg) do
    local limit = entry.limit
    if type(limit) == "number" and limit >= 1 then
      limits[entry.product_id] = limit
    end
  end
  return limits
end

local function _build_initial_turn()
  return {
    current_player_index = 1,
    turn_count = 0,
    countdown_seconds = 0,
    countdown_active = false,
    phase = "start",
    pending_choice = nil,
    choice_seq = 0,
    move_anim_seq = 0,
    move_anim = nil,
    vehicle_resync_seq = 0,
    action_anim_seq = 0,
    action_anim = nil,
    action_anim_queue = {},
    detained_wait_active = false,
    detained_wait_seconds = 0,
    detained_wait_elapsed = 0,
    item_phase = {},
    item_phase_active = "",
    market_prompt = nil,
    post_action = nil,
  }
end

local function _phase_post(turn_mgr, args)
  local player = args.player or turn_mgr.game:current_player()
  local phase_res = item_phase.run(turn_mgr, "post_action", {
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

local function _phase_end(turn_mgr, args)
  local player = args.player
  turn_mgr.game:tick_player_deity(player)
  turn_mgr.game:clear_player_temporal_flags(player)
  turn_mgr.game:stop_all_players_movement()
  local game = turn_mgr.game
  game.turn.market_prompt = nil
  game.turn.post_action = nil
  game.turn.item_phase = {}
  game.turn.item_phase_active = ""
  dirty_tracker.mark(game.dirty, "turn")
  turn_mgr:next_player()
  return nil
end

function composition_root.assemble(opts, game_or_class)
  assert(opts ~= nil, "missing assemble opts")

  local board = _create_board(opts)
  local rng = _new_rng()
  local players = _create_players(opts)

  _init_tile_state(board)

  local dirty = dirty_tracker.new()

  for _, p in ipairs(players) do
    local pid = p.id
    p.inventory._on_change = function()
      dirty_tracker.mark_inventory(dirty, pid)
    end
  end

  item_registry.register_defaults()
  choice_registry.register_defaults(require("src.game.systems.choices.ChoiceResolver").helpers())
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
  game.player_by_id = _build_player_by_id(players)
  game.turn = _build_initial_turn()
  game.dirty = dirty
  game.market_limits = _build_market_limits()
  game.rng = rng
  game.logger = logger
  game.finished = false
  game.winner = nil
  game.last_turn = nil
  game._land_rent_version = 0
  game._land_rent_cache = nil
  game.tile_owner_notifier = game.tile_owner_notifier or {
    notify_owner_changed = function() end,
  }

  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end

  game:rebuild()
  game.turn_flow = turn_flow:new(game, phases)

  return game
end

composition_root.snapshot_inventory = _snapshot_inventory

return composition_root
