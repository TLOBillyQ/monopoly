local runtime_constants = require("src.config.gameplay.runtime_constants")
local catalog = require("src.ui.render.board_feedback.catalog")
local unit_position = require("src.ui.render.support.unit_position")
local host_runtime_resolver = require("src.ui.render.support.host_runtime_resolver")
local effect_player = require("src.ui.render.board_feedback.effect_player")
local sound_player = require("src.ui.render.board_feedback.sound_player")
local service = {}
local active_host_runtime = nil

local _resolve_host_runtime = host_runtime_resolver.from_state
local function _resolve_tile_position(state, tile_index)
  return unit_position.read_scene_tile_position(state and state.board_scene or nil, tile_index)
end
local function _building_tile_position(state, tile_index)
  return unit_position.read_scene_building_position(state and state.board_scene or nil, tile_index)
end
local function _resolve_tile_cue_position(state, tile_index, payload)
  if payload and payload.use_building_tile_position == true then
    local building_pos = _building_tile_position(state, tile_index)
    if building_pos ~= nil then
      return building_pos
    end
  end
  return _resolve_tile_position(state, tile_index)
end
local function _lookup_at(table, idx)
  if type(table) == "table" and table[idx] ~= nil then
    return table[idx]
  end
  return nil
end

local function _units_by_player_id(state)
  return state and state.board_scene and state.board_scene.units_by_player_id or nil
end

local function _player_units(state)
  return state and state.player_units or nil
end

local function _resolve_player_unit(state, player_id)
  local from_scene = _lookup_at(_units_by_player_id(state), player_id)
  if from_scene ~= nil then
    return from_scene
  end
  return _lookup_at(_player_units(state), player_id)
end
local function _game_of(state)
  return state and state.game or nil
end

local function _game_player(state, player_id)
  local game = _game_of(state)
  if game and game.find_player_by_id then
    local player = game:find_player_by_id(player_id)
    if player then
      return player
    end
  end
  return nil
end
local function _resolve_player_position(state, player_id)
  local unit = _resolve_player_unit(state, player_id)
  local unit_pos = unit_position.read_unit_position(unit)
  if unit_pos ~= nil then
    return unit_pos
  end
  local player = _game_player(state, player_id)
  return _resolve_tile_position(state, player and player.position or nil)
end
local function _catalog_cue(cue_name, payload)
  if type(cue_name) == "string" and cue_name ~= "" then
    return catalog.get(cue_name, payload) or nil
  end
  return nil
end
local function _play_cue(_state, cue_name, pos, unit, payload)
  local cue = _catalog_cue(cue_name, payload)
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
local function _cue_player_unit(state, payload)
  local player_id = payload and payload.player_id or nil
  return player_id and _resolve_player_unit(state, player_id) or nil
end
function service.play_tile_cue(state, cue_name, tile_index, payload, deps)
  active_host_runtime = _resolve_host_runtime(state, deps)
  local pos = _resolve_tile_cue_position(state, tile_index, payload)
  if pos == nil then
    return false
  end
  return _play_cue(state, cue_name, pos, _cue_player_unit(state, payload), payload)
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
local function _player_pos_or_nil(state, player_id)
  if player_id ~= nil then
    return _resolve_player_position(state, player_id)
  end
  return nil
end

local function _tile_pos_or_nil(state, tile_index)
  if tile_index ~= nil then
    return _resolve_tile_position(state, tile_index)
  end
  return nil
end

function service.play_sound_only(state, cue_name, payload, deps)
  active_host_runtime = _resolve_host_runtime(state, deps)
  return _play_cue(
    state,
    cue_name,
    payload and (payload.pos or _player_pos_or_nil(state, payload.player_id) or _tile_pos_or_nil(state, payload.tile_index)) or nil,
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
version=4
projectHash=888a47495448f9ac
scope.0.id=chunk:src/ui/render/board_feedback/service.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=143
scope.0.semanticHash=6f87a45758c79c9b
scope.1.id=function:_resolve_tile_position
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=62f68a958bb7748b
scope.2.id=function:_building_tile_position
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=16
scope.2.semanticHash=62f68a958bb7748b
scope.3.id=function:_resolve_tile_cue_position
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=25
scope.3.semanticHash=257ed85aff107acd
scope.4.id=function:_lookup_at
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=31
scope.4.semanticHash=c8a72cd40cf0620d
scope.5.id=function:_units_by_player_id
scope.5.kind=function
scope.5.startLine=33
scope.5.endLine=35
scope.5.semanticHash=c250138038aa193a
scope.6.id=function:_player_units
scope.6.kind=function
scope.6.startLine=37
scope.6.endLine=39
scope.6.semanticHash=616a2ca60599c94f
scope.7.id=function:_resolve_player_unit
scope.7.kind=function
scope.7.startLine=41
scope.7.endLine=47
scope.7.semanticHash=2f99fb1a6c9bee98
scope.8.id=function:_game_of
scope.8.kind=function
scope.8.startLine=48
scope.8.endLine=50
scope.8.semanticHash=616a2ca60599c94f
scope.9.id=function:_game_player
scope.9.kind=function
scope.9.startLine=52
scope.9.endLine=61
scope.9.semanticHash=dd6cbc036cf1d689
scope.10.id=function:_resolve_player_position
scope.10.kind=function
scope.10.startLine=62
scope.10.endLine=70
scope.10.semanticHash=88f1c47415ff4e89
scope.11.id=function:_catalog_cue
scope.11.kind=function
scope.11.startLine=71
scope.11.endLine=76
scope.11.semanticHash=720e7b458b28e71c
scope.12.id=function:_play_cue
scope.12.kind=function
scope.12.startLine=77
scope.12.endLine=89
scope.12.semanticHash=f31a25c5e6149a49
scope.13.id=function:_cue_player_unit
scope.13.kind=function
scope.13.startLine=90
scope.13.endLine=93
scope.13.semanticHash=b60bc44cb825aeaa
scope.14.id=function:service.play_tile_cue
scope.14.kind=function
scope.14.startLine=94
scope.14.endLine=101
scope.14.semanticHash=90fda77d0c639169
scope.15.id=function:service.play_player_cue
scope.15.kind=function
scope.15.startLine=102
scope.15.endLine=110
scope.15.semanticHash=92a802036459eb2d
scope.16.id=function:_player_pos_or_nil
scope.16.kind=function
scope.16.startLine=111
scope.16.endLine=116
scope.16.semanticHash=0bd7c5e35810d402
scope.17.id=function:_tile_pos_or_nil
scope.17.kind=function
scope.17.startLine=118
scope.17.endLine=123
scope.17.semanticHash=0bd7c5e35810d402
scope.18.id=function:service.play_sound_only
scope.18.kind=function
scope.18.startLine=125
scope.18.endLine=134
scope.18.semanticHash=be6fb8fe88cec312
scope.19.id=function:service.play_step_tile_sound
scope.19.kind=function
scope.19.startLine=137
scope.19.endLine=141
scope.19.semanticHash=c57a2d7ea373e456
]]
