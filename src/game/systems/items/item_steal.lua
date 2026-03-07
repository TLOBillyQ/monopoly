local logger = require("src.core.utils.logger")
local inventory = require("src.game.systems.items.item_inventory")
local land_choice_specs = require("src.game.systems.land.land_choice_specs")
local gameplay_rules = require("src.core.config.gameplay_rules")
local action_anim_port = require("src.core.ports.action_anim_port")
local item_use_broadcast = require("src.game.systems.items.item_use_broadcast")

local steal = {}
local item_ids = gameplay_rules.item_ids
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

local function _fail_popup(game, stealer, target)
  local msg = "很遗憾，" .. target.name .. " 没有任何道具。"
  logger.event(stealer.name .. " 使用偷窃卡失败：" .. msg)
  return {
    ok = false,
    intent = { kind = "push_popup", payload = { title = "偷窃失败", body = msg } },
  }
end

function steal.steal_item_at_index(game, player, target, item_idx)
  if inventory.count(target) == 0 then
    return _fail_popup(game, player, target)
  end
  local stolen = inventory.remove_by_index(target, item_idx or 1)
  assert(stolen ~= nil, "missing stolen item")
  if inventory.is_full(player) then
    logger.warn(player.name .. " 背包已满，偷窃道具被销毁")
    return nil
  end
  assert(inventory.add(player, stolen) == true, "add stolen item failed")
  inventory.consume(player, item_ids.steal)
  local name = inventory.item_name(stolen.id)
  logger.event(player.name .. " 使用偷窃卡，从 " .. target.name .. " 偷走道具 " .. name)
  local queued = action_anim_port.queue(game, {
    kind = "item_target_player",
    player_id = player.id,
    target_player_id = target.id,
    item_id = item_ids.steal,
    item_name = "偷窃卡",
    duration = action_anim_duration,
  })
  item_use_broadcast.dispatch(game, player, item_ids.steal)
  return {
    ok = true,
    stolen = stolen,
    action_anim = queued,
    intent = { kind = "push_popup", payload = { title = "偷窃成功", body = player.name .. " 从 " .. target.name .. " 偷走了 " .. name } },
  }
end

function steal.build_prompt_spec(game, player, queue, index)
  assert(queue ~= nil, "missing queue")
  local target_id = assert(queue[index], "missing target id")
  assert(player ~= nil, "missing player")
  local target = assert(game:find_player_by_id(target_id), "missing target player: " .. tostring(target_id))
  return land_choice_specs.build_use_skip(
    "steal_prompt",
    "是否使用偷窃卡",
    { "目标：" .. target.name },
    { player_id = player.id, target_id = target.id, queue = queue, index = index }
  )
end

function steal.handle_pass_players(game, player, encountered_ids)
  if #encountered_ids == 0 then
    return
  end
  if inventory.find_index(player, item_ids.steal) == nil then
    return
  end

  local queue = {}
  for _, target_id in ipairs(encountered_ids) do
    local t = assert(game:find_player_by_id(target_id), "missing target player: " .. tostring(target_id))
    if not t.eliminated and not game:player_has_deity(t, "angel") then
      table.insert(queue, t.id)
    end
  end
  if #queue == 0 then
    return
  end

  local spec = steal.build_prompt_spec(game, player, queue, 1)
  assert(spec ~= nil, "missing steal prompt spec")
  return {
    waiting = true,
    intent = {
      kind = "need_choice",
      choice_spec = spec,
    },
  }
end

return steal
