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

local function _missing_ref_labels(kind)
  if kind == "effect" then
    return "skip play_sfx_by_key:", "effect_id_ref="
  end
  return "skip play_3d_sound:", "sound_id_ref="
end

function M.warn_missing_ref_once(kind, cue_name, ref_value, reason)
  local warned = warned_missing_refs[kind]
  local key = tostring(cue_name) .. "|" .. tostring(ref_value) .. "|" .. tostring(reason)
  if warned[key] then
    return
  end
  warned[key] = true
  local action_label, field_label = _missing_ref_labels(kind)
  M.warn(
    action_label,
    "cue_name=" .. tostring(cue_name),
    field_label .. tostring(ref_value),
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

-- payload 显式 id → cue 默认 id 的两级直接解析;皆缺返回 nil。
local function _direct_ref_id(cue, payload, kind)
  local resolved_id = _payload_ref_id(payload, kind)
  if resolved_id ~= nil then
    return resolved_id
  end
  return _cue_ref_id(cue, kind)
end

function M.resolve_cue_ref_id(cue_name, cue, payload, kind)
  local resolved_id = _direct_ref_id(cue, payload, kind)
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
version=4
projectHash=df60e140126ab1c6
scope.0.id=chunk:src/ui/render/board_feedback/cue_refs.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=102
scope.0.semanticHash=d716ba35170717ae
scope.1.id=function:M.resolve_numeric
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=16
scope.1.semanticHash=aba9250a8c6b104f
scope.2.id=function:M.warn
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=f0a9ce72807e7baa
scope.3.id=function:_missing_ref_labels
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=27
scope.3.semanticHash=e6d8ce995ba43d30
scope.4.id=function:M.warn_missing_ref_once
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=43
scope.4.semanticHash=145e15c4e22deec3
scope.5.id=function:_warn_invalid_cue_field
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=53
scope.5.semanticHash=2a9491edb4fd762c
scope.6.id=function:M.resolve_sfx_scale
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=62
scope.6.semanticHash=535cfd299c696abd
scope.7.id=function:_payload_ref_id
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=66
scope.7.semanticHash=4193c73e65e77bbc
scope.8.id=function:_cue_ref_id
scope.8.kind=function
scope.8.startLine=68
scope.8.endLine=70
scope.8.semanticHash=ae41f18db6ec3811
scope.9.id=function:_cue_lookup_key
scope.9.kind=function
scope.9.startLine=72
scope.9.endLine=74
scope.9.semanticHash=9affa79eb1c97291
scope.10.id=function:_direct_ref_id
scope.10.kind=function
scope.10.startLine=77
scope.10.endLine=83
scope.10.semanticHash=b33aa7b4b0f25ec7
scope.11.id=function:M.resolve_cue_ref_id
scope.11.kind=function
scope.11.startLine=85
scope.11.endLine=99
scope.11.semanticHash=18e794c9c1e36f6c
]]
