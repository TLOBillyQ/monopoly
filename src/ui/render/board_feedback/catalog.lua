local runtime_refs = require("src.config.content.runtime_refs")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local logger = require("src.core.utils.logger")
local number_utils = require("src.core.utils.number")
local tables = require("src.core.utils.tables")

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
