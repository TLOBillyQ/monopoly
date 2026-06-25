local state = require("src.config.runtime_assets.state")

local M = {}

function M.key(value)
  if value == nil then
    return nil
  end
  return tostring(value)
end

function M.result(meaning, fields)
  local out = fields or {}
  out.meaning = meaning
  out.ok = out.ok ~= false
  return out
end

function M.missing(meaning, reason, fields)
  local out = fields or {}
  out.meaning = meaning
  out.ok = false
  out.reason = reason
  return out
end

function M.image_result(meaning, raw_key, reason, opts)
  local lookup_key = M.key(raw_key)
  local image_key = raw_key ~= nil and state.images(opts)[lookup_key] or nil
  if image_key == nil then
    return M.missing(meaning, reason, {
      lookup_key = lookup_key,
    })
  end
  return M.result(meaning, {
    image_key = image_key,
    asset_id = image_key,
    lookup_key = lookup_key,
    fallback_used = false,
  })
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=dc8a8b5a837e8388
scope.0.id=chunk:src/config/runtime_assets/results.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=44
scope.0.semanticHash=504a507cefa5bb80
scope.1.id=function:M.key:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=3eea3b9f9d41fe66
scope.2.id=function:M.result:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=17
scope.2.semanticHash=6399f335bbcc645d
scope.3.id=function:M.missing:19
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=25
scope.3.semanticHash=c5947c52ef662f5e
scope.4.id=function:M.image_result:27
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=41
scope.4.semanticHash=3acbbe88c7beaf56
]]
