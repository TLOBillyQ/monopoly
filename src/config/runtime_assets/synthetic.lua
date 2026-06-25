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
version=2
projectHash=15a2f40c08c3c878
scope.0.id=chunk:src/config/runtime_assets/synthetic.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=56
scope.0.semanticHash=14564bb615d7524b
scope.0.lastMutatedAt=2026-06-24T20:09:20Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=8
scope.0.lastMutationKilled=8
scope.1.id=function:_synthetic_name:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=11
scope.1.semanticHash=a671d8c92a9aee88
scope.1.lastMutatedAt=2026-06-24T20:09:20Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:_synthetic_unit_key:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=19
scope.2.semanticHash=4e7fe0528665e22a
scope.2.lastMutatedAt=2026-06-24T20:09:20Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
scope.3.id=function:_synthetic_avatar:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=27
scope.3.semanticHash=b0582efd3521ffcd
scope.3.lastMutatedAt=2026-06-24T20:09:20Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=7
scope.4.id=function:M.synthetic_ai_profile:29
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=43
scope.4.semanticHash=a4633c3e22b7d6a7
scope.4.lastMutatedAt=2026-06-24T20:09:20Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=survived
scope.4.lastMutationSites=7
scope.4.lastMutationKilled=6
]]
