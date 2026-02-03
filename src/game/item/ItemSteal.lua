local logger = require("src.core.Logger")
local inventory = require("src.game.item.ItemInventory")
local land_choice_specs = require("src.game.land.LandChoiceSpecs")
local gameplay_rules = require("Config.GameplayRules")

local steal = {}
local item_ids = gameplay_rules.item_ids

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
  return {
    ok = true,
    stolen = stolen,
    intent = { kind = "push_popup", payload = { title = "偷窃成功", body = player.name .. " 从 " .. target.name .. " 偷走了 " .. name } },
  }
end

function steal.build_prompt_spec(game, player, queue, index)
  assert(queue ~= nil, "missing queue")
  local target_id = assert(queue[index], "missing target id")
  assert(player ~= nil, "missing player")
  local target = assert(game.players[target_id], "missing target player: " .. tostring(target_id))
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
  assert(inventory.find_index(player, item_ids.steal) ~= nil, "missing steal item")

  local queue = {}
  for _, target_id in ipairs(encountered_ids) do
    local t = assert(game.players[target_id], "missing target player: " .. tostring(target_id))
    if not t.eliminated and not t:has_deity("angel") then
      table.insert(queue, t.id)
    end
  end
  if #queue == 0 then
    return
  end

  assert(game.ui_port ~= nil, "missing ui_port")

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



