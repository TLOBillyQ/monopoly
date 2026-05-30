local logger = require("src.foundation.log")

local policy = {}

local function _resolve_explicit_route(choice)
  if not choice then
    return nil
  end
  if choice.route_key ~= nil and choice.route_key ~= "" then
    return choice.route_key
  end
  local route = choice.route
  if type(route) == "table" and route.route_key ~= nil and route.route_key ~= "" then
    return route.route_key
  end
  local meta = choice.meta
  if type(meta) == "table" and meta.route_key ~= nil and meta.route_key ~= "" then
    return meta.route_key
  end
  return nil
end

local function _resolve_explicit_requires_confirm(choice_or_screen)
  if type(choice_or_screen) ~= "table" then
    return nil
  end
  if type(choice_or_screen.requires_confirm) == "boolean" then
    return choice_or_screen.requires_confirm
  end
  local route = choice_or_screen.route
  if type(route) == "table" and type(route.requires_confirm) == "boolean" then
    return route.requires_confirm
  end
  local meta = choice_or_screen.meta
  if type(meta) == "table" and type(meta.requires_confirm) == "boolean" then
    return meta.requires_confirm
  end
  return nil
end

policy.resolve_explicit_route = _resolve_explicit_route

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
version=2
projectHash=308a49b7197c754d
scope.0.id=chunk:src/config/choice/route_policy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=73
scope.0.semanticHash=dc4492db0f7bdd46
scope.1.id=function:_resolve_explicit_route:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=21
scope.1.semanticHash=a6cc27eee4cc4098
scope.2.id=function:_resolve_explicit_requires_confirm:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=39
scope.2.semanticHash=841363983e01daf0
scope.3.id=function:policy.is_secondary_confirm_choice:43
scope.3.kind=function
scope.3.startLine=43
scope.3.endLine=45
scope.3.semanticHash=4b8d5ff90de7dad7
scope.4.id=function:policy.resolve:47
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=57
scope.4.semanticHash=cbfe9b19e59092f5
scope.5.id=function:policy.requires_confirm:61
scope.5.kind=function
scope.5.startLine=61
scope.5.endLine=70
scope.5.semanticHash=46e5505a542889e9
]]
