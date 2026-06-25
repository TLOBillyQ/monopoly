local number_utils = require("src.foundation.number")
local effect_timeline = require("src.ui.render.support.effect_timeline")
local cue_refs = require("src.ui.render.board_feedback.cue_refs")
local host_runtime_guard = require("src.ui.render.board_feedback.host_runtime")

local M = {}

local default_sound_duration = 1.0
local default_sound_volume = 1.0

local function _schedule_followup_sound(cue_name, pos, entry, host_runtime)
  if type(entry) ~= "table" then
    return false
  end
  host_runtime = host_runtime_guard.with_method(host_runtime, "play_3d_sound")
  if host_runtime == nil or type(host_runtime.schedule) ~= "function" then
    return false
  end
  local delay = cue_refs.resolve_numeric(entry.delay, 0) or 0
  effect_timeline.run_step(delay, function()
    local sound_id = number_utils.to_integer(entry.sound_id)
    if sound_id == nil or sound_id <= 0 then
      cue_refs.warn_missing_ref_once("sound", cue_name, entry.sound_id_ref, "missing_or_unconfigured")
      return
    end
    host_runtime.play_3d_sound(
      pos,
      sound_id,
      cue_refs.resolve_numeric(entry.duration, default_sound_duration),
      cue_refs.resolve_numeric(entry.volume, default_sound_volume)
    )
  end, {
    schedule = host_runtime.schedule,
  })
  return true
end

local function _resolve_sound_params(cue_name, cue, payload)
  local sound_id = cue_refs.resolve_cue_ref_id(cue_name, cue, payload, "sound")
  if sound_id == nil then
    return nil
  end
  return {
    sound_id = sound_id,
    duration = cue_refs.resolve_numeric(payload and payload.sound_duration or cue.sound_duration or cue.duration, default_sound_duration),
    volume = cue_refs.resolve_numeric(payload and payload.volume or cue.volume, default_sound_volume),
  }
end

function M.play(cue_name, cue, pos, payload, host_runtime)
  local params = _resolve_sound_params(cue_name, cue, payload)
  host_runtime = host_runtime_guard.with_method(host_runtime, "play_3d_sound")
  if params == nil or host_runtime == nil then
    return false
  end
  local sound_handle = host_runtime.play_3d_sound(pos, params.sound_id, params.duration, params.volume)
  return sound_handle ~= nil
end

function M.play_followups(cue_name, pos, followup_sounds, host_runtime)
  local played = false
  if type(followup_sounds) ~= "table" then
    return played
  end
  for _, entry in ipairs(followup_sounds) do
    if _schedule_followup_sound(cue_name, pos, entry, host_runtime) then
      played = true
    end
  end
  return played
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=8b02d91d9a33a942
scope.0.id=chunk:src/ui/render/board_feedback/sound_player.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=74
scope.0.semanticHash=83cdb201cbb87cac
scope.1.id=function:anonymous@20:20
scope.1.kind=function
scope.1.startLine=20
scope.1.endLine=32
scope.1.semanticHash=e3a5587be5e0166b
scope.2.id=function:_schedule_followup_sound:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=36
scope.2.semanticHash=895629ad3c978cd9
scope.3.id=function:_resolve_sound_params:38
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=48
scope.3.semanticHash=66702786d92693bd
scope.4.id=function:M.play:50
scope.4.kind=function
scope.4.startLine=50
scope.4.endLine=58
scope.4.semanticHash=31cfee3e20894200
]]
