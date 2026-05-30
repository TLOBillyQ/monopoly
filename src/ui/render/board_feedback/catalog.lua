local runtime_refs = require("src.config.content.runtime_refs")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local logger = require("src.foundation.log")
local number_utils = require("src.foundation.number")
local tables = require("src.foundation.tables")

local catalog = {}

local function _warn_invalid(cue_name, field, value, reason)
  logger.warn("board_feedback", "invalid cue config", "cue_name=" .. tostring(cue_name), "field=" .. tostring(field), "value=" .. tostring(value), "reason=" .. tostring(reason))
end

local function _resolve_numeric_field(cue_name, field, value)
  if value == nil then
    return nil
  end
  if number_utils.is_numeric(value) then
    return value + 0
  end
  if type(value) == "table" then
    _warn_invalid(cue_name, field, value, "vector_like_not_allowed")
    return nil
  end
  _warn_invalid(cue_name, field, value, "non_numeric")
  return nil
end

local function _resolve_bind_offset(value)
  if value == nil then
    return nil
  end
  if type(value) == "string" then
    return runtime_constants[value]
  end
  return value
end

local function _resolve_followup_sounds(cue_name, entries)
  if type(entries) ~= "table" then
    return nil
  end
  local out = {}
  for _, entry in ipairs(entries) do
    if type(entry) == "table" then
      out[#out + 1] = {
        sound_id_ref = entry.sound_id_ref,
        delay = _resolve_numeric_field(cue_name, "followup_sounds.delay", entry.delay),
        duration = _resolve_numeric_field(cue_name, "followup_sounds.duration", entry.duration),
        volume = _resolve_numeric_field(cue_name, "followup_sounds.volume", entry.volume),
      }
    end
  end
  return out
end

local function _resolve_cue(cue_name, cue)
   local resolved = tables.copy(cue)
  if type(resolved) ~= "table" then
    return nil
  end
  resolved.scale = _resolve_numeric_field(cue_name, "scale", resolved.scale)
  resolved.rate = _resolve_numeric_field(cue_name, "rate", resolved.rate)
  resolved.duration = _resolve_numeric_field(cue_name, "duration", resolved.duration)
  resolved.volume = _resolve_numeric_field(cue_name, "volume", resolved.volume)
  resolved.delay = _resolve_numeric_field(cue_name, "delay", resolved.delay)
  resolved.sound_duration = _resolve_numeric_field(cue_name, "sound_duration", resolved.sound_duration)
  resolved.bind_offset = _resolve_bind_offset(resolved.bind_offset)
  resolved.followup_sounds = _resolve_followup_sounds(cue_name, resolved.followup_sounds)
  return resolved
end

function catalog.get(cue_name)
  if cue_name == nil then
    return nil
  end
  local cues = runtime_refs.board_feedback or {}
  return _resolve_cue(cue_name, cues[cue_name])
end

return catalog

--[[ mutate4lua-manifest
version=2
projectHash=a674d029ec488eda
scope.0.id=chunk:src/ui/render/board_feedback/catalog.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=81
scope.0.semanticHash=ab248dfc89b2b70d
scope.1.id=function:_warn_invalid:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=fb8c7b6b50666b03
scope.2.id=function:_resolve_numeric_field:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=26
scope.2.semanticHash=ea5ed9f2b92486e5
scope.3.id=function:_resolve_bind_offset:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=36
scope.3.semanticHash=76718253a9d06229
scope.4.id=function:_resolve_cue:56
scope.4.kind=function
scope.4.startLine=56
scope.4.endLine=70
scope.4.semanticHash=84513270a5eca622
scope.5.id=function:catalog.get:72
scope.5.kind=function
scope.5.startLine=72
scope.5.endLine=78
scope.5.semanticHash=d7cf0939a119984d
]]
