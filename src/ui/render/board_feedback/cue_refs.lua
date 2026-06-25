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

--[[ mutate4lua-manifest
version=2
projectHash=9ee2860589f05dd4
scope.0.id=chunk:src/ui/render/board_feedback/cue_refs.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=89
scope.0.semanticHash=8524ecaf1cda49e7
scope.0.lastMutatedAt=2026-06-24T20:11:59Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:M.resolve_numeric:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=16
scope.1.semanticHash=03903e2a8d446f12
scope.1.lastMutatedAt=2026-06-24T20:11:59Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:M.warn:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=0abd013c6059f133
scope.2.lastMutatedAt=2026-06-24T20:11:59Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:M.warn_missing_ref_once:22
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=35
scope.3.semanticHash=1e566baa6f529096
scope.3.lastMutatedAt=2026-06-24T20:11:59Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=7
scope.4.id=function:_warn_invalid_cue_field:37
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=45
scope.4.semanticHash=417524e7c7c605e7
scope.4.lastMutatedAt=2026-06-24T20:11:59Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:M.resolve_sfx_scale:47
scope.5.kind=function
scope.5.startLine=47
scope.5.endLine=54
scope.5.semanticHash=fa914ed7579bf2f8
scope.5.lastMutatedAt=2026-06-24T20:11:59Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:_payload_ref_id:56
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=58
scope.6.semanticHash=36434c147798857f
scope.6.lastMutatedAt=2026-06-24T20:11:59Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:_cue_ref_id:60
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=62
scope.7.semanticHash=f056363a4b0eecff
scope.7.lastMutatedAt=2026-06-24T20:11:59Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:_cue_lookup_key:64
scope.8.kind=function
scope.8.startLine=64
scope.8.endLine=66
scope.8.semanticHash=87dfa044cb97afb9
scope.8.lastMutatedAt=2026-06-24T20:11:59Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=4
scope.8.lastMutationKilled=4
scope.9.id=function:M.resolve_cue_ref_id:68
scope.9.kind=function
scope.9.startLine=68
scope.9.endLine=86
scope.9.semanticHash=c9344d60436ec198
scope.9.lastMutatedAt=2026-06-24T20:11:59Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=survived
scope.9.lastMutationSites=15
scope.9.lastMutationKilled=13
]]
