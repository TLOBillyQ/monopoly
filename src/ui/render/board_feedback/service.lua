local runtime_constants = require("src.config.gameplay.runtime_constants")
local catalog = require("src.ui.render.board_feedback.catalog")
local unit_position = require("src.ui.render.unit_position")
local host_runtime_resolver = require("src.ui.render.host_runtime_resolver")
local effect_player = require("src.ui.render.board_feedback.effect_player")
local sound_player = require("src.ui.render.board_feedback.sound_player")
local service = {}
local active_host_runtime = nil

local _resolve_host_runtime = host_runtime_resolver.from_state
local function _resolve_tile_position(state, tile_index)
  return unit_position.read_scene_tile_position(state and state.board_scene or nil, tile_index)
end
local function _resolve_tile_cue_position(state, tile_index, payload)
  if payload and payload.use_building_tile_position == true then
    local building_pos = unit_position.read_scene_building_position(state and state.board_scene or nil, tile_index)
    if building_pos ~= nil then
      return building_pos
    end
  end
  return _resolve_tile_position(state, tile_index)
end
local function _resolve_player_unit(state, player_id)
  local units_by_player_id = state and state.board_scene and state.board_scene.units_by_player_id or nil
  if type(units_by_player_id) == "table" and units_by_player_id[player_id] ~= nil then
    return units_by_player_id[player_id]
  end
  local player_units = state and state.player_units or nil
  if type(player_units) == "table" then
    return player_units[player_id]
  end
  return nil
end
local function _resolve_player_position(state, player_id)
  local unit = _resolve_player_unit(state, player_id)
  local unit_pos = unit_position.read_unit_position(unit)
  if unit_pos ~= nil then
    return unit_pos
  end
  local player = state and state.game and state.game.find_player_by_id and state.game:find_player_by_id(player_id) or nil
  return _resolve_tile_position(state, player and player.position or nil)
end
local function _play_cue(_state, cue_name, pos, unit, payload)
  local cue = type(cue_name) == "string" and cue_name ~= "" and catalog.get(cue_name, payload) or nil
  if cue == nil then
    return false
  end
  if pos == nil then
    pos = runtime_constants.v3_zero
  end
  local effect_played = effect_player.play(cue_name, cue, pos, unit, payload, active_host_runtime)
  local sound_played = sound_player.play(cue_name, cue, pos, payload, active_host_runtime)
  local followup_played = sound_player.play_followups(cue_name, pos, cue.followup_sounds, active_host_runtime)
  return effect_played or sound_played or followup_played
end
function service.play_tile_cue(state, cue_name, tile_index, payload, deps)
  active_host_runtime = _resolve_host_runtime(state, deps)
  local pos = _resolve_tile_cue_position(state, tile_index, payload)
  if pos == nil then
    return false
  end
  local player_id = payload and payload.player_id or nil
  local unit = player_id and _resolve_player_unit(state, player_id) or nil
  return _play_cue(state, cue_name, pos, unit, payload)
end
function service.play_player_cue(state, cue_name, player_id, payload, deps)
  active_host_runtime = _resolve_host_runtime(state, deps)
  local pos = payload and payload.pos or _resolve_player_position(state, player_id)
  if pos == nil then
    return false
  end
  local unit = _resolve_player_unit(state, player_id)
  return _play_cue(state, cue_name, pos, unit, payload)
end
function service.play_sound_only(state, cue_name, payload, deps)
  active_host_runtime = _resolve_host_runtime(state, deps)
  return _play_cue(
    state,
    cue_name,
    payload and (payload.pos or (payload.player_id ~= nil and _resolve_player_position(state, payload.player_id)) or (payload.tile_index ~= nil and _resolve_tile_position(state, payload.tile_index))) or nil,
    nil,
    payload
  )
end
local _step_tile_sound_payload = {}

function service.play_step_tile_sound(state, player_id, tile_index, deps)
  _step_tile_sound_payload.player_id = player_id
  _step_tile_sound_payload.tile_index = tile_index
  return service.play_sound_only(state, "move_step_pounce", _step_tile_sound_payload, deps)
end
return service

--[[ mutate4lua-manifest
version=2
projectHash=189a9d1de6fb489a
scope.0.id=chunk:src/ui/render/board_feedback/service.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=93
scope.0.semanticHash=d4ea97b0f05d5b2d
scope.1.id=function:_resolve_tile_position:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=b493209f0442bf71
scope.2.id=function:_resolve_tile_cue_position:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=22
scope.2.semanticHash=2d12b072e7ac5351
scope.3.id=function:_resolve_player_unit:23
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=33
scope.3.semanticHash=9e107d67ca87f905
scope.4.id=function:_resolve_player_position:34
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=42
scope.4.semanticHash=4f4032a7c0667053
scope.5.id=function:_play_cue:43
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=55
scope.5.semanticHash=13d5216cc20c6c58
scope.6.id=function:service.play_tile_cue:56
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=65
scope.6.semanticHash=00d06e81b15e7e1c
scope.7.id=function:service.play_player_cue:66
scope.7.kind=function
scope.7.startLine=66
scope.7.endLine=74
scope.7.semanticHash=2e28249ad830b699
scope.8.id=function:service.play_sound_only:75
scope.8.kind=function
scope.8.startLine=75
scope.8.endLine=84
scope.8.semanticHash=db485843e843a331
scope.9.id=function:service.play_step_tile_sound:87
scope.9.kind=function
scope.9.startLine=87
scope.9.endLine=91
scope.9.semanticHash=5112009b78689ef7
]]
