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
version=4
projectHash=af7d492dfbcf54cf
scope.0.id=chunk:src/config/runtime_assets/results.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=44
scope.0.semanticHash=d011aad25e687eea
scope.1.id=function:M.key
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=4d0700d0f9defcb3
scope.2.id=function:M.result
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=17
scope.2.semanticHash=a0d309478252eee3
scope.3.id=function:M.missing
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=25
scope.3.semanticHash=3cb8b9767e81fb62
scope.4.id=function:M.image_result
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=41
scope.4.semanticHash=a0a32a2bdfb7dbc9
]]
