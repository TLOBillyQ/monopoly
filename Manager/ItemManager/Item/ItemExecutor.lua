local ItemEffects = require("Manager.ItemManager.Item.ItemPostEffects")
local ItemRegistry = require("Manager.ItemManager.Item.ItemRegistry")
local Agent = require("Manager.GameManager.Agent")
local Inventory = require("Manager.ItemManager.Item.ItemInventory")

local Executor = {}

function Executor.use_item(game, player, item_id, context)
  context = context or {}
  if type(context.by_ai) == "nil" then
    context.by_ai = Agent.is_auto_player(player)
  end
  local cfg = Inventory.cfg(item_id)
  assert(cfg ~= nil, "missing item cfg: " .. tostring(item_id))

  local handler = ItemRegistry.handlers[item_id]
  if handler then
    return handler(game, player, item_id, context)
  end

  local consumed = Inventory.consume(player, item_id)
  assert(consumed == true, "item consume failed: " .. tostring(item_id))

  local res = ItemEffects.apply_post(game, player, item_id, context)
  assert(res ~= nil, "missing item post effect result: " .. tostring(item_id))
  return res
end

return Executor



