
require "vendor.third_party.Utils"
local dirty_tracker = require("src.core.DirtyTracker")
local logger = require("src.core.Logger")
local market_cfg = require("Config.Generated.Market")
local turn_flow = require("src.game.flow.turn.TurnFlow")
local bootstrap = require("src.game.core.runtime.Bootstrap")
local game_factory = require("src.game.core.runtime.GameFactory")
local phase_registry = require("src.game.core.runtime.PhaseRegistry")

local composition_root = {}

local deep_copy = Utils.deep_copy

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

function composition_root.assemble(opts, game_or_class)
  assert(opts ~= nil, "missing assemble opts")

  local board = game_factory.build_board(opts)
  local rng = game_factory.build_rng()
  local players = game_factory.build_players(opts)

  _init_tile_state(board)

  local dirty = dirty_tracker.new()

  for _, p in ipairs(players) do
    local pid = p.id
    p.inventory._on_change = function()
      dirty_tracker.mark_inventory(dirty, pid)
    end
  end

  bootstrap.ensure_defaults()
  local phases = phase_registry.build_default_phases()
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
