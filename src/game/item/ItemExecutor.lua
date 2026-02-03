local item_effects = require("src.game.item.ItemPostEffects")
local item_registry = require("src.game.item.ItemRegistry")
local agent = require("src.game.game.Agent")
local inventory = require("src.game.item.ItemInventory")

local executor = {}

function executor.use_item(game, player, item_id, context)
  context = context or {}
  if type(context.by_ai) == "nil" then
    context.by_ai = agent.is_auto_player(player)
  end
  local cfg = inventory.cfg(item_id)
  assert(cfg ~= nil, "missing item cfg: " .. tostring(item_id))

  local handler = item_registry.handlers[item_id]
  if handler then
    return handler(game, player, item_id, context)
  end

  local consumed = inventory.consume(player, item_id)
  assert(consumed == true, "item consume failed: " .. tostring(item_id))

  local res = item_effects.apply_post(game, player, item_id, context)
  assert(res ~= nil, "missing item post effect result: " .. tostring(item_id))
  return res
end

return executor



