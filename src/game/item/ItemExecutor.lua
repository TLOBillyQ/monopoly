local ItemEffects = require("src.game.item.ItemPostEffects")
local ItemRegistry = require("src.game.item.ItemRegistry")
local Agent = require("src.game.game.Agent")
local Inventory = require("src.game.item.ItemInventory")

local Executor = {}

function Executor.UseItem(game, player, item_id, context)
  context = context or {}
  if type(context.by_ai) == "nil" then
    context.by_ai = Agent.IsAutoPlayer(player)
  end
  local cfg = Inventory.Cfg(item_id)
  assert(cfg ~= nil, "missing item cfg: " .. tostring(item_id))

  local handler = ItemRegistry.handlers[item_id]
  if handler then
    return handler(game, player, item_id, context)
  end

  local consumed = Inventory.Consume(player, item_id)
  assert(consumed == true, "item consume failed: " .. tostring(item_id))

  local res = ItemEffects.ApplyPost(game, player, item_id, context)
  assert(res ~= nil, "missing item post effect result: " .. tostring(item_id))
  return res
end

return Executor



