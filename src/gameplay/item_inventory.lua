local items_cfg = require("src.config.items")
local random = require("src.util.random")
local logger = require("src.util.logger")

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

function Inventory.find_index(player, item_id)
  return player.inventory:find_index(function(it)
    return it.id == item_id
  end)
end

function Inventory.consume(player, item_id)
  local idx = Inventory.find_index(player, item_id)
  if idx then
    player.inventory:remove_by_index(idx)
    return true
  end
  return false
end

function Inventory.draw_random(rng)
  return random.weighted_choice(items_cfg, "weight", rng)
end

function Inventory.give(player, item_id)
  if player.inventory:is_full() then
    logger.warn(player.name .. " 的背包已满，无法获得道具 " .. item_id)
    return false
  end
  player.inventory:add({ id = item_id })
  logger.event(player.name .. " 获得道具 " .. Inventory.item_name(item_id))
  return true
end

function Inventory.draw_and_give(player, rng)
  local cfg = Inventory.draw_random(rng)
  if not cfg then
    return
  end
  Inventory.give(player, cfg.id)
end

return Inventory
