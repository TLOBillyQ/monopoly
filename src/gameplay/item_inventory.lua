local items_cfg = require("src.config.items")
local random = require("src.util.random")
local logger = require("src.util.logger")
local IntentDispatcher = require("src.util.intent_dispatcher")

local Inventory = {}

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

function Inventory.cfg(item_id)
  return cfg_by_id[item_id]
end

function Inventory.item_name(item_id)
  local cfg = cfg_by_id[item_id]
  return (cfg and cfg.name) or tostring(item_id)
end

function Inventory.items(player)
  if not player or not player.inventory then
    return {}
  end
  return player.inventory.items or {}
end

function Inventory.count(player)
  if not player or not player.inventory then
    return 0
  end
  return player.inventory:count()
end

function Inventory.is_full(player)
  if not player or not player.inventory then
    return false
  end
  return player.inventory:is_full()
end

function Inventory.add(player, item)
  if not player or not player.inventory or not item then
    return false
  end
  return player.inventory:add(item)
end

function Inventory.find_index(player, item_id)
  if not player or not player.inventory then
    return nil
  end
  return player.inventory:find_index(function(it)
    return it.id == item_id
  end)
end

function Inventory.consume(player, item_id)
  if not player or not player.inventory then
    return false
  end
  local idx = Inventory.find_index(player, item_id)
  if idx then
    player.inventory:remove_by_index(idx)
    return true
  end
  return false
end

function Inventory.remove_by_index(player, idx)
  if not player or not player.inventory or not idx then
    return nil
  end
  return player.inventory:remove_by_index(idx)
end

function Inventory.clear(player)
  if not player or not player.inventory then
    return
  end
  player.inventory._suspend_on_change = true
  player.inventory.items = {}
  player.inventory._suspend_on_change = false
end

function Inventory.draw_random(rng)
  return random.weighted_choice(items_cfg, "weight", rng)
end

local function notify_full(game, player, item_id)
  if not game or not game.ui_port or not player or player.is_ai or player.auto then
    return
  end
  IntentDispatcher.dispatch(game, {
    kind = "push_popup",
    payload = {
      title = "道具",
      body = player.name .. " 背包已满，无法获得道具 " .. Inventory.item_name(item_id),
    },
  })
end

function Inventory.give(player, item_id, context)
  if Inventory.is_full(player) then
    logger.warn(player.name .. " 的背包已满，无法获得道具 " .. item_id)
    notify_full(context and context.game, player, item_id)
    return false
  end
  if not Inventory.add(player, { id = item_id }) then
    return false
  end
  logger.event(player.name .. " 获得道具 " .. Inventory.item_name(item_id))
  return true
end

function Inventory.draw_and_give(player, rng, context)
  local cfg = Inventory.draw_random(rng)
  if not cfg then
    return
  end
  Inventory.give(player, cfg.id, context)
end

return Inventory
