local overlay = require("src.ui.render.anim.unit_overlay")
local move_anim = require("src.ui.render.move_anim")
local tip_text = require("src.ui.render.anim.tip_text")
local board_feedback = require("src.ui.render.board_feedback.service")
local unit_position = require("src.ui.render.unit_position")
local number_utils = require("src.foundation.number")
local timing = require("src.config.gameplay.timing")
local compute = require("src.ui.render.anim.overlay_compute")

local units = {}

local function _timing_or(value, fallback)
  if value ~= nil then
    return value
  end
  return fallback
end

local mine_trigger_snap_delay_seconds = _timing_or(timing.mine_trigger_snap_delay_seconds, 0.6)
local demolish_effect_followup_delay_seconds = _timing_or(timing.demolish_effect_followup_delay_seconds, 0.35)
local teleport_camera_hold_seconds = _timing_or(timing.teleport_effect_camera_hold_seconds, 1.0)
local roadblock_destroy_hold_seconds = _timing_or(timing.roadblock_destroy_hold_seconds, 0)
local _play_demolish_feedback

units.clear_overlay = overlay.clear_overlay

local function _pan_to_position(state, tile_index, opts)
  if state == nil or tile_index == nil then return false end
  local pan_fn = opts and opts.pan_camera_to_position
  if type(pan_fn) ~= "function" then return false end
  local pos = compute.resolve_tile_pos(state, tile_index)
  if pos == nil then return false end
  return pan_fn(state, pos) == true
end

local function _schedule_pan_release(state, release, duration, opts)
  local schedule = opts and opts.schedule
  if type(schedule) ~= "function" then
    release(state)
    return
  end
  local release_after = duration
  if not number_utils.is_numeric(release_after) or release_after < 0 then
    release_after = 0
  end
  schedule(release_after, function()
    release(state)
  end)
end

local function _pan_camera_to_tile(state, tile_index, duration, opts)
  if not _pan_to_position(state, tile_index, opts) then return end
  local release = opts and opts.release_target_pan
  if type(release) ~= "function" then return end
  _schedule_pan_release(state, release, duration, opts)
end

function units.play_overlay(state, anim, duration, opts)
  if anim and anim.kind == "roadblock" and anim.tile_index ~= nil then
    _pan_camera_to_tile(state, anim.tile_index, duration, opts)
  end
  overlay.play_overlay(state, anim, duration, opts)
end

function units.play_missile(state, anim, duration, opts)
  local board_scene = assert(state.board_scene, "missing board_scene")
  local to_index = anim and anim.to_index or nil
  local tile_index = assert(anim.tile_index, "missing missile tile_index")
  _pan_camera_to_tile(state, tile_index, duration, opts)
  for _, player_id in ipairs(anim and anim.target_player_ids or {}) do
    move_anim.prepare_player_for_snap(board_scene, player_id, anim, "missile")
  end
  _play_demolish_feedback(state, tile_index, opts, false)
  overlay.play_missile(state, anim, duration, opts)
  if to_index ~= nil then
    for _, player_id in ipairs(anim and anim.target_player_ids or {}) do
      move_anim.snap_player_to_index(board_scene, player_id, to_index, anim, "play_sequence_missile_target")
    end
  end
end

function units.play_monster(state, anim, duration, opts)
  local tile_index = assert(anim.tile_index, "missing monster tile_index")
  _pan_camera_to_tile(state, tile_index, duration, opts)
  _play_demolish_feedback(state, tile_index, opts, true)
end

function units.play_clear_obstacles(state, anim, duration, opts)
  if anim and anim.tile_index ~= nil then
    _pan_camera_to_tile(state, anim.tile_index, duration, opts)
  end
  overlay.play_clear_obstacles(state, anim, duration, opts)
end

function units.play_move_effect(state, anim)
  return move_anim.play_sequence(state.board_scene, anim)
end

local function _pan_camera_to_teleport_destination(state, anim, duration, opts)
  if anim == nil or anim.to_index == nil then
    return
  end
  local hold = duration
  if not number_utils.is_numeric(hold) or hold < teleport_camera_hold_seconds then
    hold = teleport_camera_hold_seconds
  end
  _pan_camera_to_tile(state, anim.to_index, hold, opts)
end

function units.play_teleport_effect(state, anim, duration, opts)
  _pan_camera_to_teleport_destination(state, anim, duration, opts)
  return move_anim.play_teleport(state.board_scene, anim)
end

units.play_forced_relocation = units.play_teleport_effect

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

local function _play_mine_feedback(state, anim, player_id, tile_index, hit_pos)
  local cue_name = anim and anim.cue_name or "mine_blast"
  if hit_pos ~= nil then
    board_feedback.play_player_cue(state, cue_name, player_id, { pos = hit_pos })
    return
  end
  board_feedback.play_tile_cue(state, cue_name, tile_index, {})
end

function _play_demolish_feedback(state, tile_index, opts, use_building_tile_position)
  board_feedback.play_tile_cue(state, "mine_blast", tile_index, {
    use_building_tile_position = use_building_tile_position == true,
  })
  local schedule = opts and opts.schedule or nil
  if type(schedule) == "function" and demolish_effect_followup_delay_seconds > 0 then
    schedule(demolish_effect_followup_delay_seconds, function()
      board_feedback.play_tile_cue(state, "upgrade_land_smoke", tile_index, {
        use_building_tile_position = use_building_tile_position == true,
      })
    end)
    return
  end
  board_feedback.play_tile_cue(state, "upgrade_land_smoke", tile_index, {
    use_building_tile_position = use_building_tile_position == true,
  })
end

local function _clear_mine_overlay(opts, state, tile_index)
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
  local hit_pos = _resolve_mine_hit_position(board_scene, player_id, tile_index)

  local schedule = opts and opts.schedule or nil
  if type(schedule) == "function" and mine_trigger_snap_delay_seconds > 0 then
    _play_mine_feedback(state, anim, player_id, tile_index, hit_pos)
    _clear_mine_overlay(opts, state, tile_index)
    local snap_delay = mine_trigger_snap_delay_seconds
    _schedule_mine_trigger_snap(board_scene, player_id, anim, to_index, snap_delay, schedule)
    return _resolve_minimum_delay(snap_delay, duration)
  end
  -- Fallback: no scheduler - preserve original call order
  move_anim.prepare_player_for_snap(board_scene, player_id, anim, "mine_trigger")
  _play_mine_feedback(state, anim, player_id, tile_index, hit_pos)
  _clear_mine_overlay(opts, state, tile_index)
  local snap_delay = move_anim.snap_player_to_index(board_scene, player_id, to_index, anim, "play_sequence_mine_trigger")
  return _resolve_minimum_delay(snap_delay, duration)
end

function units.play_roadblock_trigger(state, anim, duration, opts)
  local clear_overlay = assert(opts and opts.clear_overlay, "missing clear_overlay")
  local tile_index = assert(anim.tile_index, "missing tile_index")
  local schedule = opts and opts.schedule or nil
  if type(schedule) == "function" and roadblock_destroy_hold_seconds > 0 then
    schedule(roadblock_destroy_hold_seconds, function()
      clear_overlay(state, "roadblock", tile_index)
    end)
    return _resolve_minimum_delay(roadblock_destroy_hold_seconds, duration)
  end
  clear_overlay(state, "roadblock", tile_index)
  return _resolve_minimum_delay(0, duration)
end

units.build_tip = tip_text.build

return units

--[[ mutate4lua-manifest
version=2
projectHash=3187e99aba9ac1c4
scope.0.id=chunk:src/ui/render/anim/units.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=215
scope.0.semanticHash=498778b2d7a66593
scope.1.id=function:_timing_or:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=17
scope.1.semanticHash=005c2a059dee8dc2
scope.2.id=function:_pan_to_position:27
scope.2.kind=function
scope.2.startLine=27
scope.2.endLine=34
scope.2.semanticHash=2a44933fa50d3915
scope.3.id=function:anonymous@46:46
scope.3.kind=function
scope.3.startLine=46
scope.3.endLine=48
scope.3.semanticHash=fad4a9686f4b030c
scope.4.id=function:_schedule_pan_release:36
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=49
scope.4.semanticHash=4c7b4820b8e41ace
scope.5.id=function:_pan_camera_to_tile:51
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=56
scope.5.semanticHash=a42d4aa6bfe0e31b
scope.6.id=function:units.play_overlay:58
scope.6.kind=function
scope.6.startLine=58
scope.6.endLine=63
scope.6.semanticHash=0c31bb9267c46ac4
scope.7.id=function:units.play_monster:82
scope.7.kind=function
scope.7.startLine=82
scope.7.endLine=86
scope.7.semanticHash=fedf7bbba3969ae2
scope.8.id=function:units.play_clear_obstacles:88
scope.8.kind=function
scope.8.startLine=88
scope.8.endLine=93
scope.8.semanticHash=ccca31d8629ad991
scope.9.id=function:units.play_move_effect:95
scope.9.kind=function
scope.9.startLine=95
scope.9.endLine=97
scope.9.semanticHash=3d9ffb8292dc1eff
scope.10.id=function:_pan_camera_to_teleport_destination:99
scope.10.kind=function
scope.10.startLine=99
scope.10.endLine=108
scope.10.semanticHash=4270817a5c86df85
scope.11.id=function:units.play_teleport_effect:110
scope.11.kind=function
scope.11.startLine=110
scope.11.endLine=113
scope.11.semanticHash=b8f34656c700b429
scope.12.id=function:_resolve_minimum_delay:117
scope.12.kind=function
scope.12.startLine=117
scope.12.endLine=129
scope.12.semanticHash=074b4ba94009e080
scope.13.id=function:_resolve_mine_hit_position:131
scope.13.kind=function
scope.13.startLine=131
scope.13.endLine=134
scope.13.semanticHash=4b89d541b34ad417
scope.14.id=function:_play_mine_feedback:136
scope.14.kind=function
scope.14.startLine=136
scope.14.endLine=143
scope.14.semanticHash=14faba7ac8a52961
scope.15.id=function:anonymous@151:151
scope.15.kind=function
scope.15.startLine=151
scope.15.endLine=155
scope.15.semanticHash=3a48264709ec34e4
scope.16.id=function:_play_demolish_feedback:145
scope.16.kind=function
scope.16.startLine=145
scope.16.endLine=161
scope.16.semanticHash=670c37eb5d0c2de3
scope.17.id=function:_clear_mine_overlay:163
scope.17.kind=function
scope.17.startLine=163
scope.17.endLine=166
scope.17.semanticHash=03ceefce1aa1fbea
scope.18.id=function:anonymous@169:169
scope.18.kind=function
scope.18.startLine=169
scope.18.endLine=172
scope.18.semanticHash=2b31a306348bd0cb
scope.19.id=function:_schedule_mine_trigger_snap:168
scope.19.kind=function
scope.19.startLine=168
scope.19.endLine=173
scope.19.semanticHash=7d782cf926edcaa5
scope.20.id=function:units.play_mine_trigger:175
scope.20.kind=function
scope.20.startLine=175
scope.20.endLine=196
scope.20.semanticHash=57a7596493670ba5
scope.21.id=function:anonymous@203:203
scope.21.kind=function
scope.21.startLine=203
scope.21.endLine=205
scope.21.semanticHash=fc56b35ce4cb885d
scope.22.id=function:units.play_roadblock_trigger:198
scope.22.kind=function
scope.22.startLine=198
scope.22.endLine=210
scope.22.semanticHash=4d138be22f340237
]]
