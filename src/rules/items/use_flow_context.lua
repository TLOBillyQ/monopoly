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

function context.resolve_actor(game, actor_id)
  if type(actor_id) == "table" then
    return actor_id
  end
  if game and type(game.find_player_by_id) == "function" then
    return game:find_player_by_id(actor_id)
  end
  for _, player in ipairs(game and game.players or {}) do
    if player.id == actor_id then
      return player
    end
  end
  return nil
end

function context.count_item(player, item_id)
  local count = 0
  for _, item in ipairs(inventory.items(player)) do
    if item.id == item_id then
      count = count + 1
    end
  end
  return count
end

return context
