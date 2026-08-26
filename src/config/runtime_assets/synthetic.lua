local number_utils = require("src.foundation.number")
local state = require("src.config.runtime_assets.state")
local results = require("src.config.runtime_assets.results")
local images = require("src.config.runtime_assets.images")

local M = {}

local function _synthetic_name(slot_index, cfg)
  local names = cfg.names or {}
  return names[slot_index] or ("AI" .. tostring(slot_index))
end

local function _synthetic_unit_key(slot, cfg, opts)
  local unit_key = type(opts) == "table" and opts.unit_key or nil
  if unit_key == nil then
    unit_key = (cfg.unit_keys or {})[slot]
  end
  return unit_key
end

local function _synthetic_avatar(slot, opts)
  local avatar = images.image_for_chance_card("AI" .. tostring(slot), opts)
  if avatar.ok == true then
    return avatar, false, nil
  end
  return images.empty_image(opts), true, "missing_synthetic_ai_avatar"
end

function M.synthetic_ai_profile(slot_index, opts)
  local slot = number_utils.to_integer(slot_index) or 1
  local refs = state.refs(opts)
  local cfg = refs.synthetic_ai or {}
  local avatar, fallback_used, reason = _synthetic_avatar(slot, opts)
  return results.result("synthetic_ai.profile", {
    slot_index = slot,
    name = _synthetic_name(slot, cfg),
    unit_key = _synthetic_unit_key(slot, cfg, opts),
    avatar_image_key = avatar.image_key,
    avatar_result = avatar,
    fallback_used = fallback_used,
    reason = reason,
  })
end

function M.synthetic_ai_unit_key_pool(opts)
  local refs = state.refs(opts)
  local unit_keys = ((refs.synthetic_ai or {}).unit_keys) or {}
  local out = {}
  for index, unit_key in ipairs(unit_keys) do
    out[index] = unit_key
  end
  return out
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=539cf282408a1d8c
scope.0.id=chunk:src/config/runtime_assets/synthetic.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=56
scope.0.semanticHash=199d14b352cc869f
scope.1.id=function:_synthetic_name
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=11
scope.1.semanticHash=d5bf3e089af075c1
scope.2.id=function:_synthetic_unit_key
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=19
scope.2.semanticHash=69819807b1c344f7
scope.3.id=function:_synthetic_avatar
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=27
scope.3.semanticHash=240ecee218669e75
scope.4.id=function:M.synthetic_ai_profile
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=43
scope.4.semanticHash=dd34e37743fcec8b
scope.5.id=function:M.synthetic_ai_unit_key_pool
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=53
scope.5.semanticHash=29eb6c1624875ab7
]]
