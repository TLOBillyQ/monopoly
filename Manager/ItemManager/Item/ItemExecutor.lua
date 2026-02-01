local logger = require("Library.Monopoly.Logger")
local ItemEffects = require("Manager.ItemManager.Item.ItemPostEffects")
local ItemRegistry = require("Manager.ItemManager.Item.ItemRegistry")
local Agent = require("Manager.GameManager.Agent")
local Inventory = require("Manager.ItemManager.Item.ItemInventory")

local Executor = {}

function Executor.use_item(game, player, item_id, context)
  context = context or {}
  if context.by_ai == nil then
    context.by_ai = Agent.is_auto_player(player)
  end
  local cfg = Inventory.cfg(item_id)
  if not cfg then
    return false
  end

  local handler = ItemRegistry.handlers[item_id]
  if handler then
    return handler(game, player, item_id, context)
  end

  local consumed = Inventory.consume(player, item_id)
  if not consumed then
    return false
  end

  local res = ItemEffects.apply_post(game, player, item_id, context)
  if res ~= nil then
    return res
  end

  logger.warn("未实现的道具:" .. tostring(item_id))
  return false
end

return Executor

