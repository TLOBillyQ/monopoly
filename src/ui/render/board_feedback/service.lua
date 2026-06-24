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
projectHash=9895729aba46a596
scope.0.id=chunk:src/ui/render/board_feedback/service.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=293
scope.0.semanticHash=c415c9ae13a45313
scope.1.id=function:_warn:24
scope.1.kind=function
scope.1.startLine=24
scope.1.endLine=26
scope.1.semanticHash=e1854d9756369a17
scope.2.id=function:_warn_missing_ref_once:27
scope.2.kind=function
scope.2.startLine=27
scope.2.endLine=40
scope.2.semanticHash=bb550331a9973ac8
scope.3.id=function:_warn_invalid_cue_field:42
scope.3.kind=function
scope.3.startLine=42
scope.3.endLine=50
scope.3.semanticHash=4eb3ca24b4114839
scope.4.id=function:_resolve_sfx_scale:51
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=58
scope.4.semanticHash=c82085db4b6e18e4
scope.5.id=function:_resolve_cue_ref_id:59
scope.5.kind=function
scope.5.startLine=59
scope.5.endLine=77
scope.5.semanticHash=4191fba215124c9a
scope.6.id=function:_resolve_tile_position:78
scope.6.kind=function
scope.6.startLine=78
scope.6.endLine=80
scope.6.semanticHash=b493209f0442bf71
scope.7.id=function:_resolve_tile_cue_position:81
scope.7.kind=function
scope.7.startLine=81
scope.7.endLine=89
scope.7.semanticHash=2d12b072e7ac5351
scope.8.id=function:_resolve_player_unit:90
scope.8.kind=function
scope.8.startLine=90
scope.8.endLine=100
scope.8.semanticHash=9e107d67ca87f905
scope.9.id=function:_resolve_player_position:101
scope.9.kind=function
scope.9.startLine=101
scope.9.endLine=109
scope.9.semanticHash=4f4032a7c0667053
scope.10.id=function:anonymous@119:119
scope.10.kind=function
scope.10.startLine=119
scope.10.endLine=128
scope.10.semanticHash=2b00946ca33d9f24
scope.11.id=function:_schedule_followup_sound:110
scope.11.kind=function
scope.11.startLine=110
scope.11.endLine=132
scope.11.semanticHash=c07eaa03b1405775
scope.12.id=function:_resolve_with_sound:133
scope.12.kind=function
scope.12.startLine=133
scope.12.endLine=142
scope.12.semanticHash=43e4ee858609f176
scope.13.id=function:_resolve_effect_params:144
scope.13.kind=function
scope.13.startLine=144
scope.13.endLine=158
scope.13.semanticHash=b29f39e1bc879ae7
scope.14.id=function:_resolve_effect_host_runtime:160
scope.14.kind=function
scope.14.startLine=160
scope.14.endLine=166
scope.14.semanticHash=0fbee0e161bf27ce
scope.15.id=function:_play_sfx:168
scope.15.kind=function
scope.15.startLine=168
scope.15.endLine=172
scope.15.semanticHash=97a24b9e0bd4ff2b
scope.16.id=function:_bind_sfx_to_player:174
scope.16.kind=function
scope.16.startLine=174
scope.16.endLine=188
scope.16.semanticHash=fa9cc1d5e286735d
scope.17.id=function:_play_effect:190
scope.17.kind=function
scope.17.startLine=190
scope.17.endLine=206
scope.17.semanticHash=50b97b2257248dff
scope.18.id=function:_play_sound:207
scope.18.kind=function
scope.18.startLine=207
scope.18.endLine=220
scope.18.semanticHash=e2a323c8f98f9203
scope.19.id=function:_play_cue:235
scope.19.kind=function
scope.19.startLine=235
scope.19.endLine=255
scope.19.semanticHash=54c33c37de5d2689
scope.20.id=function:service.play_tile_cue:256
scope.20.kind=function
scope.20.startLine=256
scope.20.endLine=265
scope.20.semanticHash=00d06e81b15e7e1c
scope.21.id=function:service.play_player_cue:266
scope.21.kind=function
scope.21.startLine=266
scope.21.endLine=274
scope.21.semanticHash=2e28249ad830b699
scope.22.id=function:service.play_sound_only:275
scope.22.kind=function
scope.22.startLine=275
scope.22.endLine=284
scope.22.semanticHash=db485843e843a331
scope.23.id=function:service.play_step_tile_sound:287
scope.23.kind=function
scope.23.startLine=287
scope.23.endLine=291
scope.23.semanticHash=5112009b78689ef7
]]
