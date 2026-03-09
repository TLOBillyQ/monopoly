local anchors = require("src.presentation.view.render.board.anchors")
local player_units = require("src.presentation.view.render.board.player_units")
local placement = require("src.presentation.view.render.board.placement")
local events = require("src.presentation.view.render.board.events")
local runtime_state = require("src.core.state_access.runtime_state")

local M = {}

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
  end

  if suppress_sync or not need_sync then
    board_runtime.board_last_positions = snapshot
    board_runtime.board_last_vehicle_resync_seq = vehicle_resync_seq
    return
  end

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

return M
