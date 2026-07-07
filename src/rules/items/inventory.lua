local items_cfg = require("src.config.content.items")
require "vendor.third_party.Utils"
local logger = require("src.foundation.log")
local event_kinds = require("src.config.gameplay.event_kinds")
local intent_output_port = require("src.rules.ports.intent_output")
local event_feed = require("src.rules.ports.event_feed")
local item_config = require("src.rules.items.config")

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

local function _inv(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory
end

function inventory.items(player)
  return assert(_inv(player).items, "missing inventory items")
end

function inventory.count(player)
  return _inv(player):count()
end

function inventory.is_full(player)
  return _inv(player):is_full()
end

function inventory.add(player, item)
  assert(item ~= nil, "missing item")
  return _inv(player):add(item)
end

function inventory.find_index(player, item_id)
  return _inv(player):find_index(function(it)
    return it.id == item_id
  end)
end

function inventory.consume(player, item_id)
  local inv = _inv(player)
  local idx = assert(inventory.find_index(player, item_id), "missing item: " .. tostring(item_id))
  inv:remove_by_index(idx)
  return true
end

function inventory.remove_by_index(player, idx)
  assert(idx ~= nil, "missing index")
  local inv = _inv(player)
  local items = inventory.items(player)
  assert(idx >= 1 and idx <= #items, "remove_by_index: index out of bounds: " .. tostring(idx))
  return inv:remove_by_index(idx)
end

function inventory.clear(player)
  local inv = _inv(player)
  inv._suspend_on_change = true
  inv.items = {}
  inv._suspend_on_change = false
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

return inventory

--[[ mutate4lua-manifest
version=2
projectHash=cc1ad9a629d3a099
scope.0.id=chunk:src/rules/items/inventory.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=115
scope.0.semanticHash=b7862fff63e30b4e
scope.0.lastMutatedAt=2026-07-07T04:23:19Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=7
scope.0.lastMutationKilled=7
scope.1.id=function:inventory.cfg:13
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=15
scope.1.semanticHash=ccdbae248439b223
scope.2.id=function:inventory.item_name:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=21
scope.2.semanticHash=e432d1bbcd08cc55
scope.2.lastMutatedAt=2026-07-07T04:23:19Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:_inv:23
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=27
scope.3.semanticHash=9539b049e744d587
scope.3.lastMutatedAt=2026-07-07T04:23:19Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
scope.4.id=function:inventory.items:29
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=31
scope.4.semanticHash=aa267b8a944ab0e1
scope.4.lastMutatedAt=2026-07-07T04:23:19Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:inventory.count:33
scope.5.kind=function
scope.5.startLine=33
scope.5.endLine=35
scope.5.semanticHash=aa7338a4727b3ad5
scope.5.lastMutatedAt=2026-07-07T04:23:19Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:inventory.is_full:37
scope.6.kind=function
scope.6.startLine=37
scope.6.endLine=39
scope.6.semanticHash=df57b24b96a8fa55
scope.6.lastMutatedAt=2026-07-07T04:23:19Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=2
scope.6.lastMutationKilled=2
scope.7.id=function:inventory.add:41
scope.7.kind=function
scope.7.startLine=41
scope.7.endLine=44
scope.7.semanticHash=73c146438dea7fe0
scope.7.lastMutatedAt=2026-07-07T04:23:19Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=3
scope.8.id=function:anonymous@47:47
scope.8.kind=function
scope.8.startLine=47
scope.8.endLine=49
scope.8.semanticHash=302fa526ee51cb2d
scope.9.id=function:inventory.find_index:46
scope.9.kind=function
scope.9.startLine=46
scope.9.endLine=50
scope.9.semanticHash=c6db1ae56fe984be
scope.9.lastMutatedAt=2026-07-07T04:23:19Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=2
scope.9.lastMutationKilled=2
scope.10.id=function:inventory.consume:52
scope.10.kind=function
scope.10.startLine=52
scope.10.endLine=57
scope.10.semanticHash=e4100833291c4714
scope.10.lastMutatedAt=2026-07-07T04:23:19Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=4
scope.10.lastMutationKilled=4
scope.11.id=function:inventory.remove_by_index:59
scope.11.kind=function
scope.11.startLine=59
scope.11.endLine=65
scope.11.semanticHash=e53ef94c29798432
scope.11.lastMutatedAt=2026-07-07T04:23:19Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=5
scope.11.lastMutationKilled=5
scope.12.id=function:inventory.clear:67
scope.12.kind=function
scope.12.startLine=67
scope.12.endLine=72
scope.12.semanticHash=5a595a5c622842ed
scope.12.lastMutatedAt=2026-07-07T04:23:19Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=3
scope.12.lastMutationKilled=3
scope.13.id=function:anonymous@75:75
scope.13.kind=function
scope.13.startLine=75
scope.13.endLine=77
scope.13.semanticHash=da02dceadc483768
scope.14.id=function:inventory.draw_random:74
scope.14.kind=function
scope.14.startLine=74
scope.14.endLine=79
scope.14.semanticHash=b58636be687fd943
scope.14.lastMutatedAt=2026-07-07T04:23:19Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=4
scope.14.lastMutationKilled=4
scope.15.id=function:_notify_full:81
scope.15.kind=function
scope.15.startLine=81
scope.15.endLine=95
scope.15.semanticHash=3e623d883d643c4a
scope.15.lastMutatedAt=2026-07-07T04:23:19Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=10
scope.15.lastMutationKilled=10
scope.16.id=function:inventory.give:97
scope.16.kind=function
scope.16.startLine=97
scope.16.endLine=112
scope.16.semanticHash=6d36780608a8244f
scope.16.lastMutatedAt=2026-07-07T04:23:19Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=8
scope.16.lastMutationKilled=8
]]
