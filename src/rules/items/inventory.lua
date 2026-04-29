local items_cfg = require("src.config.content.items")
require "vendor.third_party.Utils"
local logger = require("src.core.utils.logger")
local event_kinds = require("src.config.gameplay.event_kinds")
local intent_output_port = require("src.rules.ports.intent_output")
local event_feed = require("src.rules.ports.event_feed")
local item_config = require("src.rules.items.item_config")

local inventory = {}

local cfg_by_id = item_config.cfg_by_id

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
  local items = inventory.items(player)
  local index = idx
  assert(index >= 1 and index <= #items, "remove_by_index: index out of bounds: " .. tostring(index))
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
  if not game then return end
  local popup_port = game.popup_port
  if popup_port == nil and type(game.ensure_popup_port) == "function" then
    popup_port = game:ensure_popup_port()
  end
  if popup_port == nil then return end
  if player.is_ai or player.auto then
    return
  end
  intent_output_port.push_popup(game, {
    title = "道具",
    body = player.name .. " 背包已满，无法获得道具 " .. inventory.item_name(item_id),
  })
end

function inventory.give(player, item_id, context)
  if inventory.is_full(player) then
    -- migrated as DEV: capacity constraint diagnostic, not player-visible event feed
    logger.info(player.name .. " 的背包已满，无法获得道具 " .. item_id)
    if context and context.game then
      _notify_full(context.game, player, item_id)
    end
    return false
  end
  inventory.add(player, { id = item_id })
  event_feed.publish(context and context.game, {
    kind = event_kinds.item_acquired,
    text = player.name .. " 获得道具 " .. inventory.item_name(item_id),
  })
  return true
end

function inventory.draw_and_give(player, context)
  local cfg = inventory.draw_random()
  assert(cfg ~= nil, "missing drawn item cfg")
  inventory.give(player, cfg.id, context)
end

return inventory
