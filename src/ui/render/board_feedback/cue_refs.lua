local number_utils = require("src.foundation.number")
local logger = require("src.foundation.log")

local M = {}

local warned_missing_refs = {
  effect = {},
  sound = {},
}

local default_sfx_scale = 1.0
local _resolve_numeric = number_utils.resolve_numeric

function M.resolve_numeric(value, fallback)
  return _resolve_numeric(value, fallback)
end

function M.warn(...)
  logger.warn("board_feedback", ...)
end

function M.warn_missing_ref_once(kind, cue_name, ref_value, reason)
  local warned = warned_missing_refs[kind]
  local key = tostring(cue_name) .. "|" .. tostring(ref_value) .. "|" .. tostring(reason)
  if warned[key] then
    return
  end
  warned[key] = true
  M.warn(
    kind == "effect" and "skip play_sfx_by_key:" or "skip play_3d_sound:",
    "cue_name=" .. tostring(cue_name),
    (kind == "effect" and "effect_id_ref=" or "sound_id_ref=") .. tostring(ref_value),
    "reason=" .. tostring(reason)
  )
end

local function _warn_invalid_cue_field(cue_name, field, value, fallback)
  M.warn(
    "invalid cue field:",
    "cue_name=" .. tostring(cue_name),
    "field=" .. tostring(field),
    "value=" .. tostring(value),
    "fallback=" .. tostring(fallback)
  )
end

function M.resolve_sfx_scale(cue_name, value, fallback)
  local resolved = _resolve_numeric(value, fallback)
  if resolved ~= nil then
    return resolved
  end
  _warn_invalid_cue_field(cue_name, "scale", value, default_sfx_scale)
  return default_sfx_scale
end

local function _payload_ref_id(payload, kind)
  return number_utils.to_integer(payload and payload[kind .. "_id"] or nil)
end

local function _cue_ref_id(cue, kind)
  return number_utils.to_integer(cue[kind .. "_id"])
end

local function _cue_lookup_key(cue, payload, kind)
  return payload and payload[kind .. "_id_ref"] or cue[kind .. "_lookup_key"]
end

function M.resolve_cue_ref_id(cue_name, cue, payload, kind)
  local resolved_id = _payload_ref_id(payload, kind)
  if resolved_id ~= nil then
    return resolved_id
  end
  resolved_id = _cue_ref_id(cue, kind)
  if resolved_id ~= nil then
    return resolved_id
  end
  local lookup_key = _cue_lookup_key(cue, payload, kind)
  if type(lookup_key) ~= "string" or lookup_key == "" then
    if cue.allow_missing ~= true then
      M.warn("skip cue " .. kind .. " with missing " .. kind .. "_id_ref:", tostring(cue_name))
    end
    return nil
  end
  M.warn_missing_ref_once(kind, cue_name, lookup_key, "missing_or_unconfigured")
  return nil
end

return M
