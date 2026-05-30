require "vendor.third_party.Utils"
local dirty_tracker = require("src.state.dirty_tracker")
local logger = require("src.foundation.log")
local market_cfg = require("src.config.content.market")
local game_state = require("src.state.game_state")
local turn_runtime = require("src.turn.loop.scheduler_runtime")
local bootstrap = require("src.rules.bootstrap")
local game_factory = require("src.app.game_factory")
local phase_registry = require("src.turn.phases.registry")
local number_utils = require("src.foundation.number")
local role_id_utils = require("src.foundation.identity")
local intent_dispatcher = require("src.turn.output.intent_dispatcher")
local status_ops = require("src.player.actions.status")
local balance_ops = require("src.player.actions.balance")
local deity_ops = require("src.player.actions.deity")
local location_ops = require("src.player.actions.location")
local game_victory = require("src.rules.endgame")

local function _install_class_mixin(target_class, source_table, source_name)
  for key, fn in pairs(source_table) do
    assert(target_class[key] == nil, "compose_game mixin collision: " .. tostring(source_name) .. "." .. tostring(key))
    target_class[key] = fn
  end
end

local _player_state_groups = {
  { name = "status_ops", source = status_ops },
  { name = "balance_ops", source = balance_ops },
  { name = "deity_ops", source = deity_ops },
  { name = "location_ops", source = location_ops },
}

for _, group in ipairs(_player_state_groups) do
  _install_class_mixin(game_state, group.source, group.name)
end

game_state.check_victory = game_victory.check_victory

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
    used_effect_groups = {},
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

local function _apply_game_defaults(game, opts, board, players, dirty)
  game.board = board
  game.players = players
  game.player_by_id = _build_player_by_id(players)
  game.turn = _build_initial_turn()
  game.turn.turn_start_prompt_seq = 0
  game.turn.turn_start_prompt_player_id = nil
  game.dirty = dirty
  game.market_limits = _build_market_limits()
  game.rng = opts.rng or game_factory.build_rng()
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
  game.intent_output_port = game.intent_output_port or intent_dispatcher.build_port()
  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end
end

local function _assemble(opts, game_or_class)
  assert(opts ~= nil, "missing assemble opts")

  local board = game_factory.build_board(opts)
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

  _apply_game_defaults(game, opts, board, players, dirty)

  game.registries = registries
  game.effect_registry = registries.effects

  game:rebuild()
  game.turn_runtime = turn_runtime:new(game, phases)
  game.turn_engine = game.turn_runtime

  return game
end

composition_root._install_class_mixin = _install_class_mixin
composition_root._is_class_like = _is_class_like
composition_root._build_player_by_id = _build_player_by_id
composition_root._build_market_limits = _build_market_limits
composition_root._build_initial_turn = _build_initial_turn

function composition_root.new_game(opts, game_class)
  local target_game_class = game_class or game_state
  local game = target_game_class:new(opts)
  if type(game) ~= "table" or type(game.rebuild) ~= "function" then
    return game
  end
  return _assemble(opts, game)
end

return composition_root

--[[ mutate4lua-manifest
version=2
projectHash=9451fd860032e575
scope.0.id=chunk:src/app/compose_game.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=197
scope.0.semanticHash=8d1fb5900ed4a5e5
scope.1.id=function:_build_initial_turn:74
scope.1.kind=function
scope.1.startLine=74
scope.1.endLine=106
scope.1.semanticHash=958c5c5409985498
scope.2.id=function:_is_class_like:108
scope.2.kind=function
scope.2.startLine=108
scope.2.endLine=118
scope.2.semanticHash=e01edce0f09f4dcf
scope.3.id=function:anonymous@137:137
scope.3.kind=function
scope.3.startLine=137
scope.3.endLine=137
scope.3.semanticHash=b53995942fd14a6f
scope.4.id=function:anonymous@140:140
scope.4.kind=function
scope.4.startLine=140
scope.4.endLine=142
scope.4.semanticHash=c168b2cdb12a737a
scope.5.id=function:game:consume_dirty:145
scope.5.kind=function
scope.5.startLine=145
scope.5.endLine=147
scope.5.semanticHash=3e3a2e42df31fd3c
scope.6.id=function:_apply_game_defaults:120
scope.6.kind=function
scope.6.startLine=120
scope.6.endLine=148
scope.6.semanticHash=4998404a4d7c378a
scope.7.id=function:anonymous@162:162
scope.7.kind=function
scope.7.startLine=162
scope.7.endLine=164
scope.7.semanticHash=688fa52491eb80fc
scope.8.id=function:composition_root.new_game:187
scope.8.kind=function
scope.8.startLine=187
scope.8.endLine=194
scope.8.semanticHash=618dd07df434fc6a
]]
