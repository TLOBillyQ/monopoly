local anchors = require("src.ui.render.board.anchors")
local startup_render = require("src.ui.render.board.startup_render")
local player_units = require("src.ui.render.board.player_units")
local placement = require("src.ui.render.board.placement")
local events = require("src.ui.render.board.events")
local runtime_state = require("src.ui.runtime.state")
local gameplay_rules = require("src.config.gameplay.rules")
local logger = require("src.core.utils.logger")

local M = {}

local function _should_debug_log()
  return logger.is_anim_debug_enabled() or gameplay_rules.move_anim_debug_log_enabled == true
end

local function _debug_log(...)
  if not _should_debug_log() then
    return
  end
  logger.info_unlimited("[MoveAnim]", ...)
end

function M.refresh(state, ui_model, log_once, build_log_prefix)
  assert(ui_model ~= nil, "missing ui_model")
  local board = assert(ui_model.board, "missing ui_model.board")
  local players = assert(board.players, "missing ui_model.board.players")
  assert(board.tiles ~= nil, "missing ui_model.board.tiles")
  local tile_count = board.tile_count or #board.tiles
  assert(tile_count > 0, "missing tile_count")
  assert(log_once ~= nil, "missing log_once")
  assert(build_log_prefix ~= nil, "missing build_log_prefix")
  local scene = assert(state.board_scene, "missing board_scene")

  anchors.ensure_tile_anchors(state, board, scene, tile_count, log_once, build_log_prefix)
  startup_render.apply(state, board, scene)
  player_units.ensure_player_units(state, players, log_once, build_log_prefix)

  local phase = board.phase
  local anim = board.move_anim
  local suppress_sync = (phase == "wait_move_anim" and anim)
    or (phase == "wait_action_anim" and board.move_followup_pending == true)
  local vehicle_resync_seq = board.vehicle_resync_seq or 0

  local snapshot = placement.build_snapshot(players)
  local need_sync = placement.compute_need_sync(state, snapshot, vehicle_resync_seq)
  local board_runtime = runtime_state.ensure_board_runtime(state)

  if suppress_sync then
    board_runtime.board_sync_pending = true
    _debug_log(
      "board_refresh_suppress_sync",
      "phase=" .. tostring(phase),
      "has_anim=" .. tostring(anim ~= nil),
      "move_followup_pending=" .. tostring(board.move_followup_pending == true)
    )
  end

  if suppress_sync or not need_sync then
    board_runtime.board_last_positions = snapshot
    board_runtime.board_last_vehicle_resync_seq = vehicle_resync_seq
    return
  end

  _debug_log(
    "board_refresh_apply_sync",
    "phase=" .. tostring(phase),
    "board_sync_pending=" .. tostring(board_runtime.board_sync_pending == true),
    "vehicle_resync_seq=" .. tostring(vehicle_resync_seq)
  )
  local occupants = placement.build_occupants(state, players)
  local spacing = state.tile_spacing or 0
  local min_player_y = placement.resolve_min_player_y(scene)
  placement.place_players(state, players, occupants, spacing, min_player_y)

  board_runtime.board_sync_pending = false
  board_runtime.board_last_positions = snapshot
  board_runtime.board_last_vehicle_resync_seq = vehicle_resync_seq
end

M.refresh_board = M.refresh

M.on_tile_upgraded = events.on_tile_upgraded
M.on_tile_owner_changed = events.on_tile_owner_changed
M.sync_many = events.sync_many

return M
