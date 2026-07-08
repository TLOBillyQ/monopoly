local event_kinds = require("src.config.gameplay.event_kinds")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local action_anim_port = require("src.foundation.ports.action_anim")
local event_feed = require("src.rules.ports.event_feed")
local gain_reveal = require("src.rules.items.gain_reveal")

local steal = {}
local action_anim_duration = timing.action_anim_default_seconds

local function _fail_popup(game, stealer, target)
  local msg = target.name .. " 没有任何道具"
  local log_text = stealer.name .. " 使用偷窃卡，" .. msg
  event_feed.publish(game, {
    kind = event_kinds.steal,
    text = log_text,
    tip = true,
    tip_duration = action_anim_duration,
    tip_dedupe_key = "steal_fail:" .. tostring(stealer.id) .. ":" .. tostring(target.id),
    blocks_inter_turn = false,
    source = "rules.items.steal",
  })
  return {
    ok = false,
  }
end

local function _bag_full_popup(game, stealer)
  local log_text = stealer.name .. " 使用偷窃卡，背包已满"
  event_feed.publish(game, {
    kind = event_kinds.steal,
    text = log_text,
    tip = true,
    tip_duration = action_anim_duration,
    tip_dedupe_key = "steal_bag_full:" .. tostring(stealer.id),
    blocks_inter_turn = false,
    source = "rules.items.steal",
  })
  return {
    ok = false,
    bag_full = true,
  }
end

-- commit:结算台账注入的单次消耗能力(道具使用流程必经);
-- 缺省回退为直接自耗,仅服务不经流程的独立单测调用。
local function _consume_steal_card(player, commit)
  if commit ~= nil then
    return commit()
  end
  return inventory.consume(player, item_ids.steal)
end

function steal.steal_item_at_index(game, player, target, item_idx, commit)
  if inventory.count(target) == 0 then
    return _fail_popup(game, player, target)
  end
  if inventory.is_full(player) then
    return _bag_full_popup(game, player)
  end
  _consume_steal_card(player, commit)
  local stolen = inventory.remove_by_index(target, item_idx or 1)
  assert(stolen ~= nil, "missing stolen item")
  assert(inventory.add(player, stolen) == true, "add stolen item failed")
  local name = inventory.item_name(stolen.id)
  local log_text = player.name .. " 使用偷窃卡，从 " .. target.name .. " 偷走道具 " .. name
  event_feed.publish(game, {
    kind = event_kinds.steal,
    text = log_text,
    tip = true,
    tip_duration = action_anim_duration,
    tip_dedupe_key = "steal_success:" .. tostring(player.id) .. ":" .. tostring(target.id) .. ":" .. tostring(stolen.id),
    blocks_inter_turn = false,
    source = "rules.items.steal",
  })
  local queued = action_anim_port.queue(game, {
    kind = "item_target_player",
    player_id = player.id,
    target_player_id = target.id,
    item_id = item_ids.steal,
    item_name = "偷窃卡",
    duration = action_anim_duration,
  })
  gain_reveal.queue(game, player, stolen.id, { source = "steal" })
  return {
    ok = true,
    stolen = stolen,
    action_anim = queued,
    item_consumed = true,
  }
end

function steal.steal_random_item(game, player, target, commit)
  local count = inventory.count(target)
  if count == 0 then
    return _fail_popup(game, player, target)
  end
  local rng = assert(game and game.rng, "missing game.rng for steal")
  assert(type(rng.next_int) == "function", "missing game.rng.next_int for steal")
  return steal.steal_item_at_index(game, player, target, rng:next_int(1, count), commit)
end

return steal

--[[ mutate4lua-manifest
version=2
projectHash=2a370d7caacb3835
scope.0.id=chunk:src/rules/items/steal.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=94
scope.0.semanticHash=b5669e8f5daae1cb
scope.0.lastMutatedAt=2026-05-25T07:43:29Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=6
scope.0.lastMutationKilled=6
scope.1.id=function:_fail_popup:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=26
scope.1.semanticHash=c772474c4738cf1a
scope.1.lastMutatedAt=2026-05-25T07:43:29Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:_bag_full_popup:28
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=43
scope.2.semanticHash=27eefa8c60561a1e
scope.2.lastMutatedAt=2026-05-25T07:43:29Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:steal.steal_item_at_index:45
scope.3.kind=function
scope.3.startLine=45
scope.3.endLine=81
scope.3.semanticHash=3a79bab2b5a8649c
scope.3.lastMutatedAt=2026-05-25T07:43:29Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=17
scope.3.lastMutationKilled=17
scope.4.id=function:steal.steal_random_item:83
scope.4.kind=function
scope.4.startLine=83
scope.4.endLine=91
scope.4.semanticHash=4c3fbae6ffb3c436
scope.4.lastMutatedAt=2026-05-25T07:43:29Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=7
scope.4.lastMutationKilled=7
]]
