local event_kinds = require("src.config.gameplay.event_kinds")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local action_anim_port = require("src.foundation.ports.action_anim")
local event_feed = require("src.rules.ports.event_feed")

local steal = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

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

function steal.steal_item_at_index(game, player, target, item_idx)
  if inventory.count(target) == 0 then
    return _fail_popup(game, player, target)
  end
  inventory.consume(player, item_ids.steal)
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
  return {
    ok = true,
    stolen = stolen,
    action_anim = queued,
    item_consumed = true,
  }
end

function steal.steal_random_item(game, player, target)
  local count = inventory.count(target)
  if count == 0 then
    return _fail_popup(game, player, target)
  end
  local rng = assert(game and game.rng, "missing game.rng for steal")
  assert(type(rng.next_int) == "function", "missing game.rng.next_int for steal")
  return steal.steal_item_at_index(game, player, target, rng:next_int(1, count))
end

return steal
