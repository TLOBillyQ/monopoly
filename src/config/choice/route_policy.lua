local logger = require("src.foundation.log")

local policy = {}

local function _non_empty_route_key(holder)
  return type(holder) == "table" and holder.route_key ~= nil and holder.route_key ~= ""
end

local function _route_key_of(choice)
  if _non_empty_route_key(choice) then
    return choice.route_key
  end
  return nil
end

-- 显式路由:choice 本体 → choice.route → choice.meta 依次取非空 route_key。
local function _resolve_explicit_route(choice)
  if not choice then
    return nil
  end
  local direct = _route_key_of(choice)
  if direct ~= nil then
    return direct
  end
  local route_key = _route_key_of(choice.route)
  if route_key ~= nil then
    return route_key
  end
  return _route_key_of(choice.meta)
end

local function _boolean_field(holder, key)
  if type(holder) == "table" and type(holder[key]) == "boolean" then
    return holder[key]
  end
  return nil
end

-- requires_confirm:choice 本体 → route → meta 依次取布尔字段。
local function _resolve_explicit_requires_confirm(choice_or_screen)
  if type(choice_or_screen) ~= "table" then
    return nil
  end
  local direct = _boolean_field(choice_or_screen, "requires_confirm")
  if direct ~= nil then
    return direct
  end
  local route_value = _boolean_field(choice_or_screen.route, "requires_confirm")
  if route_value ~= nil then
    return route_value
  end
  return _boolean_field(choice_or_screen.meta, "requires_confirm")
end

policy.resolve_explicit_route = _resolve_explicit_route

-- 无屏 route：选项直接住在基础屏（道具槽 / 内联选项），没有自己的选择屏。
-- 这类 choice 的 ui.choice_active 恒为 false，是正常状态，不是缺屏。
local _screenless_routes = {
  base_inline = true,
  item_phase_passive = true,
}

function policy.is_screenless_route(route_key)
  return _screenless_routes[route_key] == true
end

function policy.is_secondary_confirm_choice(choice)
  return _resolve_explicit_route(choice) == "secondary_confirm"
end

function policy.resolve(choice)
  local explicit_route = _resolve_explicit_route(choice)
  if explicit_route ~= nil then
    return explicit_route
  end
  if not choice then
    return "base_inline"
  end
  logger.warn("choice route fallback to base_inline:", tostring(choice.kind))
  return "base_inline"
end

policy.resolve_explicit_requires_confirm = _resolve_explicit_requires_confirm

function policy.requires_confirm(choice_or_screen)
  local explicit_requires_confirm = _resolve_explicit_requires_confirm(choice_or_screen)
  if explicit_requires_confirm ~= nil then
    return explicit_requires_confirm
  end
  if type(choice_or_screen) == "table" then
    return policy.resolve(choice_or_screen) == "secondary_confirm"
  end
  return choice_or_screen == "secondary_confirm"
end

return policy

--[[ mutate4lua-manifest
version=4
projectHash=7272d92c9c45a717
scope.0.id=chunk:src/config/choice/route_policy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=84
scope.0.semanticHash=05fccef75e176b2a
scope.1.id=function:_resolve_explicit_route
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=21
scope.1.semanticHash=7ea25e68ab1f7ccb
scope.2.id=function:_resolve_explicit_requires_confirm
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=39
scope.2.semanticHash=27147a7f887134ae
scope.3.id=function:policy.is_screenless_route
scope.3.kind=function
scope.3.startLine=50
scope.3.endLine=52
scope.3.semanticHash=92047a25c743520b
scope.4.id=function:policy.is_secondary_confirm_choice
scope.4.kind=function
scope.4.startLine=54
scope.4.endLine=56
scope.4.semanticHash=dd62aa89e6210a00
scope.5.id=function:policy.resolve
scope.5.kind=function
scope.5.startLine=58
scope.5.endLine=68
scope.5.semanticHash=35a1982d30aa8219
scope.6.id=function:policy.requires_confirm
scope.6.kind=function
scope.6.startLine=72
scope.6.endLine=81
scope.6.semanticHash=f855df09389a3458
]]
