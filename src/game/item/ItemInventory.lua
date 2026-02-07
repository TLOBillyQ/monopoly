local items_cfg = require("Config.Generated.Items")
require "vendor.third_party.Utils"
local logger = require("src.core.Logger")
local intent_dispatcher = require("src.game.intent.IntentDispatcher")

local inventory = {}

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

function inventory.cfg(item_id)
  return cfg_by_id[item_id]
end

function inventory.item_name(item_id)
  local cfg = cfg_by_id[item_id]
  assert(cfg ~= nil, "missing item cfg: " .. tostring(item_id))
  return cfg.name
end

function inventory.items(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return assert(player.inventory.items, "missing inventory items")
end

function inventory.count(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:count()
end

function inventory.is_full(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:is_full()
end

function inventory.add(player, item)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  assert(item ~= nil, "missing item")
  return player.inventory:add(item)
end

function inventory.find_index(player, item_id)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:find_index(function(it)
    return it.id == item_id
  end)
end

function inventory.consume(player, item_id)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  local idx = assert(inventory.find_index(player, item_id), "missing item: " .. tostring(item_id))
  player.inventory:remove_by_index(idx)
  return true
end

function inventory.remove_by_index(player, idx)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  assert(idx ~= nil, "missing index")
  return player.inventory:remove_by_index(idx)
end

function inventory.clear(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  player.inventory._suspend_on_change = true
  player.inventory.items = {}
  player.inventory._suspend_on_change = false
end

function inventory.draw_random()
  local picked = Utils.choice_weight_list(items_cfg, 1, function(item)
    return item.weight or 0
  end, true)
  return picked[1] or items_cfg[1]
end

local function _notify_full(game, player, item_id)
  assert(game ~= nil, "missing game")
  assert(game.ui_port ~= nil, "missing ui_port")
  assert(player ~= nil, "missing player")
  if player.is_ai or player.auto then
    return
  end
  intent_dispatcher.dispatch(game, {
    kind = "push_popup",
    payload = {
      title = "道具",
      body = player.name .. " 背包已满，无法获得道具 " .. inventory.item_name(item_id),
    },
  })
end

function inventory.give(player, item_id, context)
  if inventory.is_full(player) then
    logger.warn(player.name .. " 的背包已满，无法获得道具 " .. item_id)
    assert(context ~= nil and context.game ~= nil, "missing context.game")
    _notify_full(context.game, player, item_id)
    return false
  end
  assert(inventory.add(player, { id = item_id }) == true, "inventory add failed: " .. tostring(item_id))
  logger.event(player.name .. " 获得道具 " .. inventory.item_name(item_id))
  return true
end

function inventory.draw_and_give(player, context)
  local cfg = inventory.draw_random()
  assert(cfg ~= nil, "missing drawn item cfg")
  inventory.give(player, cfg.id, context)
end

return inventory
