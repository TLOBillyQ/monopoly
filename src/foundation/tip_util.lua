local number_utils = require("src.foundation.number")
local role_id_utils = require("src.foundation.identity")

local tip_util = {}

function tip_util.normalize_duration(duration)
  if number_utils.is_numeric(duration) and duration > 0 then
    return duration
  end
  return 2.0
end

function tip_util.normalize_text(text)
  if text == nil then
    return nil
  end
  local ok, value = pcall(tostring, text)
  if not ok then
    return nil
  end
  return value
end

function tip_util.normalize_intent(intent, normalize_duration)
  if type(intent) ~= "table" then
    return nil
  end

  local text = tip_util.normalize_text(intent.text)
  if text == nil then
    return nil
  end

  return {
    text = text,
    duration = normalize_duration(intent.duration),
    dedupe_key = intent.dedupe_key,
    blocks_inter_turn = intent.blocks_inter_turn == true,
    source = intent.source,
    chain_key = intent.chain_key,
    role_id = intent.role_id,
  }
end

function tip_util.resolve_scope(tip_queue, role_id)
  if role_id == nil then
    return tip_queue
  end
  local key = role_id_utils.normalize(role_id)
  if key == nil then
    return tip_queue
  end
  local scope = tip_queue.role_scopes[key]
  if scope == nil then
    scope = { pending = {}, active_tip = nil }
    tip_queue.role_scopes[key] = scope
  end
  return scope
end

function tip_util.each_scope(tip_queue, fn)
  local stop = fn(tip_queue)
  if stop then
    return stop
  end
  for _, scope in pairs(tip_queue.role_scopes) do
    stop = fn(scope)
    if stop then
      return stop
    end
  end
  return nil
end

return tip_util

--[[ mutate4lua-manifest
version=4
projectHash=b131d72c78e1f6c3
scope.0.id=chunk:src/foundation/tip_util.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=76
scope.0.semanticHash=7c227c096c96fc41
scope.1.id=function:tip_util.normalize_duration
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=13c62d7ac7bab4eb
scope.2.id=function:tip_util.normalize_text
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=22
scope.2.semanticHash=84c6336a84845cf0
scope.3.id=function:tip_util.normalize_intent
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=43
scope.3.semanticHash=a3ef6e943aa366be
scope.4.id=function:tip_util.resolve_scope
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=59
scope.4.semanticHash=2543c2f3ccaad3f2
scope.5.id=function:tip_util.each_scope
scope.5.kind=function
scope.5.startLine=61
scope.5.endLine=73
scope.5.semanticHash=88b0ee2102879e9a
]]
