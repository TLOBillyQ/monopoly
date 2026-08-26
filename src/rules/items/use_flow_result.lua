local result = {}

local function _build_result(base, extra)
  for key, value in pairs(extra or {}) do
    base[key] = value
  end
  return base
end

function result.rejected(reason, extra)
  return _build_result({
    ok = false,
    status = "rejected",
    reason = reason,
  }, extra)
end

local function _choice_spec_from_result(raw_result)
  local intent = type(raw_result) == "table" and raw_result.intent or nil
  return type(intent) == "table" and intent.choice_spec or nil
end

local function _waiting_choice(raw_result, player, item_id)
  local choice_spec = _choice_spec_from_result(raw_result)
  return {
    ok = true,
    status = "waiting_choice",
    waiting = true,
    actor = player,
    actor_id = player and player.id or nil,
    item_id = item_id,
    item_consumed = false,
    choice_spec = choice_spec,
    choice = choice_spec,
    intent = type(raw_result) == "table" and raw_result.intent or nil,
    result = raw_result,
  }
end

-- 效果路径的结果已全部经 settlement 结算(_settled_item_use 冻结封套);
-- 这里只放行结算结果、把 waiting 包装为 begin/resolve seam 的 waiting_choice 封套。
function result.normalize_effect(raw_result, player, item_id)
  if type(raw_result) == "table" and raw_result._settled_item_use == true then
    return raw_result
  end
  if type(raw_result) == "table" and raw_result.waiting == true then
    return _waiting_choice(raw_result, player, item_id)
  end
  error("unsettled item effect result: " .. tostring(raw_result))
end

return result

--[[ mutate4lua-manifest
version=4
projectHash=27fdcec36b835fb6
scope.0.id=chunk:src/rules/items/use_flow_result.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=53
scope.0.semanticHash=e5904a0f6added9e
scope.1.id=function:_build_result
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=8
scope.1.semanticHash=59da1e18edb63b17
scope.2.id=function:result.rejected
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=16
scope.2.semanticHash=09406f3b4f544288
scope.3.id=function:_choice_spec_from_result
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=21
scope.3.semanticHash=5fa87d247c07b91d
scope.4.id=function:_waiting_choice
scope.4.kind=function
scope.4.startLine=23
scope.4.endLine=38
scope.4.semanticHash=d07e140d3d8ca565
scope.5.id=function:result.normalize_effect
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=50
scope.5.semanticHash=5d2f391f18f59cf5
]]
