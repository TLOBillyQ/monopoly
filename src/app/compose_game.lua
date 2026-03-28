
require "vendor.third_party.Utils"
local dirty_tracker = require("src.core.utils.dirty_tracker")
local logger = require("src.core.utils.logger")
local market_cfg = require("src.config.content.market")
local game_state = require("src.state.game_state")
local turn_runtime = require("src.turn.loop.scheduler_runtime")
local bootstrap = require("src.rules.bootstrap.registries")
local game_factory = require("src.app.game_factory")
local phase_registry = require("src.turn.phases.registry")
local number_utils = require("src.core.utils.number_utils")
local role_id_utils = require("src.core.utils.role_id")
local intent_output_adapter = require("src.turn.output.intent_output_adapter")

local composition_root = {}

local function _build_player_by_id(players)
  local out = {}
  for _, p in ipairs(players or {}) do
    if p and p.id ~= nil then
      local player_id = role_id_utils.normalize(p.id)
      if player_id ~= nil then
        out[player_id] = p
      end
    end
  end
  return out
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
    local limit = number_utils.to_integer(entry.limit)
    if limit and limit >= 1 then
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
    landing_visual_hold_active = false,
    landing_visual_release_pending = false,
    move_followup_pending = false,
    detained_wait_active = false,
    detained_wait_seconds = 0,
    detained_wait_elapsed = 0,
    inter_turn_wait_active = false,
    inter_turn_wait_seconds = 0,
    inter_turn_wait_elapsed = 0,
    no_action_notice_active = false,
    no_action_notice_player_id = nil,
    no_action_notice_text = nil,
    item_phase = {},
    item_phase_active = "",
    market_prompt = nil,
    post_action = nil,
  }
end

local function _is_class_like(value)
  if type(value) ~= "table" then
    return false
  end
  local meta = getmetatable(value)
  local is_instance = type(meta) == "table" and type(meta.__newindex) == "function"
  if is_instance then
    return false
  end
  return value.__name ~= nil and type(value.new) == "function"
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

  local registries = bootstrap.create_registries()
  local phases = phase_registry.build_default_phases()
  local game = game_or_class
  if _is_class_like(game_or_class) then
    game = game_or_class:new(opts)
  end
  assert(game, "CompositionRoot.Assemble requires game instance or class")
  game.board = board
  game.players = players
  game.player_by_id = _build_player_by_id(players)
  game.turn = _build_initial_turn()
  local first_player = players and players[game.turn.current_player_index] or nil
  game.turn.turn_start_prompt_seq = 1
  game.turn.turn_start_prompt_player_id = first_player and first_player.id or nil
  game.dirty = dirty
  game.market_limits = _build_market_limits()
  game.registries = registries
  game.effect_registry = registries.effects
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
  game.board_visual_feedback_port = game.board_visual_feedback_port or {
    sync_many = function()
      return false
    end,
  }
  game.intent_output_port = game.intent_output_port or intent_output_adapter.build()

  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end

  game:rebuild()
  game.turn_runtime = turn_runtime:new(game, phases)
  game.turn_engine = game.turn_runtime

  return game
end

function composition_root.new_game(opts, game_class)
  local target_game_class = game_class or game_state
  local game = target_game_class:new(opts)
  if type(game) ~= "table" or type(game.rebuild) ~= "function" then
    return game
  end
  return composition_root.assemble(opts, game)
end

return composition_root
