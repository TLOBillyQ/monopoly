local inventory = require("src.rules.items.inventory")

local context = {}

function context.copy(raw_context)
  local next_context = {}
  if type(raw_context) ~= "table" then
    return next_context
  end
  for key, value in pairs(raw_context) do
    next_context[key] = value
  end
  return next_context
end

local function _find_by_id(game, actor_id)
  if game and type(game.find_player_by_id) == "function" then
    return game:find_player_by_id(actor_id)
  end
  return nil
end

local function _find_linear(game, actor_id)
  for _, player in ipairs(game and game.players or {}) do
    if player.id == actor_id then
      return player
    end
  end
  return nil
end

function context.resolve_actor(game, actor_id)
  if type(actor_id) == "table" then
    return actor_id
  end
  return _find_by_id(game, actor_id) or _find_linear(game, actor_id)
end

function context.count_item(player, item_id)
  local count = 0
  for _, item in ipairs(inventory.items(player)) do
    if item ~= false and item.id == item_id then
      count = count + 1
    end
  end
  return count
end

return context

--[[ mutate4lua-manifest
version=4
projectHash=ddd52e54f7e2586f
scope.0.id=chunk:src/rules/items/use_flow_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=50
scope.0.semanticHash=c9f3015fb4203d1c
scope.1.id=function:context.copy
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=14
scope.1.semanticHash=cda80b580f6fded9
scope.2.id=function:_find_by_id
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=21
scope.2.semanticHash=1bd5be72b009cc8e
scope.3.id=function:_find_linear
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=30
scope.3.semanticHash=1fb73cda3c217cba
scope.4.id=function:context.resolve_actor
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=37
scope.4.semanticHash=ea495d7d15c6359a
scope.5.id=function:context.count_item
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=47
scope.5.semanticHash=b948ba617011be56
]]
