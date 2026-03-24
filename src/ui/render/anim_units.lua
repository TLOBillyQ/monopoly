local overlay = require("src.ui.render.anim_unit_overlay")
local move_anim = require("src.ui.render.move_anim")
local tip_text = require("src.ui.render.anim_tip_text")
local board_feedback = require("src.ui.render.board_feedback_service")
local unit_position = require("src.ui.render.unit_position")
local number_utils = require("src.core.utils.number_utils")
local timing = require("src.config.gameplay.timing")

local units = {}
local mine_trigger_snap_delay_seconds = timing.mine_trigger_snap_delay_seconds or 0.6

function units.clear_overlay(state, kind, tile_index)
  overlay.clear_overlay(state, kind, tile_index)
end

function units.play_overlay(state, anim, duration, opts)
  overlay.play_overlay(state, anim, duration, opts)
end

function units.play_missile(state, anim, duration, opts)
  local board_scene = assert(state.board_scene, "missing board_scene")
  local to_index = anim and anim.to_index or nil
  for _, player_id in ipairs(anim and anim.target_player_ids or {}) do
    move_anim.prepare_player_for_snap(board_scene, player_id, anim, "missile")
  end
  overlay.play_missile(state, anim, duration, opts)
  if to_index ~= nil then
    for _, player_id in ipairs(anim and anim.target_player_ids or {}) do
      move_anim.snap_player_to_index(board_scene, player_id, to_index, anim, "play_sequence_missile_target")
    end
  end
end

function units.play_monster(state, anim, duration, opts)
  overlay.play_monster(state, anim, duration, opts)
end

function units.play_clear_obstacles(state, anim, duration, opts)
  overlay.play_clear_obstacles(state, anim, duration, opts)
end

function units.play_move_effect(state, anim)
  return move_anim.play_sequence(state.board_scene, anim)
end

function units.play_teleport_effect(state, anim)
  return move_anim.play_teleport(state.board_scene, anim)
end

function units.play_forced_relocation(state, anim)
  return move_anim.play_teleport(state.board_scene, anim)
end

local function _resolve_minimum_delay(delay, minimum_delay)
  local resolved_delay = delay
  if not number_utils.is_numeric(resolved_delay) or resolved_delay < 0 then
    resolved_delay = 0
  end
  if not number_utils.is_numeric(minimum_delay) or minimum_delay < 0 then
    minimum_delay = 0
  end
  if resolved_delay < minimum_delay then
    return minimum_delay
  end
  return resolved_delay
end

local function _resolve_mine_hit_position(board_scene, player_id, tile_index)
  local unit = board_scene.units_by_player_id and board_scene.units_by_player_id[player_id] or nil
  return unit_position.read_unit_position(unit) or unit_position.read_scene_tile_position(board_scene, tile_index)
end

local function _play_mine_feedback(state, cue_name, player_id, tile_index, hit_pos)
  if hit_pos ~= nil then
    board_feedback.play_player_cue(state, cue_name, player_id, { pos = hit_pos })
    return
  end
  board_feedback.play_tile_cue(state, cue_name, tile_index, {})
end

local function _clear_mine_overlay(state, opts, tile_index)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  clear_overlay(state, "mine", tile_index)
end

local function _schedule_mine_trigger_snap(board_scene, player_id, anim, to_index, snap_delay, schedule)
  schedule(snap_delay, function()
    move_anim.prepare_player_for_snap(board_scene, player_id, anim, "mine_trigger")
    return move_anim.snap_player_to_index(board_scene, player_id, to_index, anim, "play_sequence_mine_trigger")
  end)
end

function units.play_mine_trigger(state, anim, duration, opts)
  local board_scene = assert(state.board_scene, "missing board_scene")
  local player_id = assert(anim.player_id, "missing player_id")
  local tile_index = assert(anim.tile_index, "missing tile_index")
  local to_index = assert(anim.to_index, "missing to_index")
  local cue_name = anim.cue_name or "mine_blast"
  local hit_pos = _resolve_mine_hit_position(board_scene, player_id, tile_index)

  local schedule = opts and opts.schedule or nil
  if type(schedule) == "function" and mine_trigger_snap_delay_seconds > 0 then
    _play_mine_feedback(state, cue_name, player_id, tile_index, hit_pos)
    _clear_mine_overlay(state, opts, tile_index)
    local snap_delay = mine_trigger_snap_delay_seconds
    _schedule_mine_trigger_snap(board_scene, player_id, anim, to_index, snap_delay, schedule)
    return _resolve_minimum_delay(snap_delay, duration)
  end
  -- Fallback: no scheduler — preserve original call order
  move_anim.prepare_player_for_snap(board_scene, player_id, anim, "mine_trigger")
  _play_mine_feedback(state, cue_name, player_id, tile_index, hit_pos)
  _clear_mine_overlay(state, opts, tile_index)
  local snap_delay = move_anim.snap_player_to_index(board_scene, player_id, to_index, anim, "play_sequence_mine_trigger")
  return _resolve_minimum_delay(snap_delay, duration)
end

function units.play_roadblock_trigger(state, anim, duration, opts)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  local tile_index = assert(anim.tile_index, "missing tile_index")
  clear_overlay(state, "roadblock", tile_index)
  return _resolve_minimum_delay(0, duration)
end

function units.build_tip(state, anim)
  return tip_text.build(state, anim)
end

return units
