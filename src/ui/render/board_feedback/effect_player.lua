local runtime_constants = require("src.config.gameplay.runtime_constants")
local effect_track = require("src.ui.render.support.effect_track")
local cue_refs = require("src.ui.render.board_feedback.cue_refs")
local host_runtime_guard = require("src.ui.render.board_feedback.host_runtime")

local M = {}

local default_sfx_scale = 1.0
local default_sfx_rate = 1.0
local default_sfx_duration = 1.0
local default_with_sound = false

local function _resolve_with_sound(cue, payload)
  local with_sound = payload and payload.with_sound
  if with_sound == nil then
    with_sound = cue.with_sound
  end
  if with_sound == nil then
    with_sound = default_with_sound
  end
  return with_sound
end

local function _effect_duration(cue, payload)
  local raw_duration = cue_refs.resolve_numeric(payload and payload.duration or cue.duration, default_sfx_duration)
  return effect_track.scaled_duration(raw_duration)
end

local function _effect_scale(cue_name, cue, payload)
  return cue_refs.resolve_sfx_scale(cue_name, payload and payload.scale or cue.scale, default_sfx_scale)
end

local function _effect_rot(cue, payload)
  return payload and payload.rot or cue.rot or runtime_constants.q_zero
end

local function _effect_rate(cue, payload)
  return cue_refs.resolve_numeric(payload and payload.rate or cue.rate, default_sfx_rate)
end

local function _resolve_effect_params(cue_name, cue, payload)
  local effect_id = cue_refs.resolve_cue_ref_id(cue_name, cue, payload, "effect")
  if effect_id == nil then
    return nil
  end
  return {
    effect_id = effect_id,
    duration = _effect_duration(cue, payload),
    scale = _effect_scale(cue_name, cue, payload),
    rot = _effect_rot(cue, payload),
    rate = _effect_rate(cue, payload),
    with_sound = _resolve_with_sound(cue, payload),
  }
end

local function _play_sfx(host_runtime, cue_name, pos, params)
  return host_runtime.play_sfx_by_key(params.effect_id, pos, params.rot, params.scale, params.duration, params.rate, params.with_sound, {
    cue_name = cue_name,
  })
end

local function _bind_sfx_to_player(host_runtime, cue, sfx_id, unit)
  if cue.bind_to_player ~= true or unit == nil then
    return
  end
  if type(host_runtime.bind_sfx_to_unit) ~= "function" then
    return
  end
  host_runtime.bind_sfx_to_unit(
    sfx_id,
    unit,
    cue.socket_name,
    cue.bind_offset or runtime_constants.v3_one,
    cue.bind_type
  )
end

function M.play(cue_name, cue, pos, unit, payload, host_runtime)
  local params = _resolve_effect_params(cue_name, cue, payload)
  if params == nil then
    return false
  end
  host_runtime = host_runtime_guard.with_method(host_runtime, "play_sfx_by_key")
  if host_runtime == nil then
    return false
  end
  local sfx_id = _play_sfx(host_runtime, cue_name, pos, params)
  if sfx_id == nil then
    return false
  end
  effect_track.spawn(cue_name, "effect", params.duration)
  _bind_sfx_to_player(host_runtime, cue, sfx_id, unit)
  return true
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=f97e1c916d47ee4b
scope.0.id=chunk:src/ui/render/board_feedback/effect_player.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=97
scope.0.semanticHash=7662f94e7d166a06
scope.1.id=function:_resolve_with_sound
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=22
scope.1.semanticHash=19b062bec137c41f
scope.2.id=function:_effect_duration
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=27
scope.2.semanticHash=af8e16bdce139b7b
scope.3.id=function:_effect_scale
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=31
scope.3.semanticHash=8b852bacb637b1f7
scope.4.id=function:_effect_rot
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=35
scope.4.semanticHash=9f7e278be65bda92
scope.5.id=function:_effect_rate
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=39
scope.5.semanticHash=2df43109c9113cc1
scope.6.id=function:_resolve_effect_params
scope.6.kind=function
scope.6.startLine=41
scope.6.endLine=54
scope.6.semanticHash=4902fada75b94131
scope.7.id=function:_play_sfx
scope.7.kind=function
scope.7.startLine=56
scope.7.endLine=60
scope.7.semanticHash=2300f404fdc001e3
scope.8.id=function:_bind_sfx_to_player
scope.8.kind=function
scope.8.startLine=62
scope.8.endLine=76
scope.8.semanticHash=655c2fe6ccabddd5
scope.9.id=function:M.play
scope.9.kind=function
scope.9.startLine=78
scope.9.endLine=94
scope.9.semanticHash=ecb04ae342ab86c2
]]
