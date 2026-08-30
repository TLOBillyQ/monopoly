local inventory = require("src.rules.items.inventory")

local context = {}

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
projectHash=744a90181888774b
scope.0.id=chunk:src/rules/items/use_flow_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=39
scope.0.semanticHash=107157863a8cabbd
scope.1.id=function:_find_by_id
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=1bd5be72b009cc8e
scope.2.id=function:_find_linear
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=19
scope.2.semanticHash=1fb73cda3c217cba
scope.3.id=function:context.resolve_actor
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=26
scope.3.semanticHash=ea495d7d15c6359a
scope.4.id=function:context.count_item
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=36
scope.4.semanticHash=b948ba617011be56
]]
