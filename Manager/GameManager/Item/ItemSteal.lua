local logger = require("Library.Monopoly.Logger")
local Inventory = require("Manager.GameManager.Item.ItemInventory")
local LandChoiceSpecs = require("Manager.GameManager.Land.LandChoiceSpecs")
local gameplay_constants = require("Manager.GameManager.System.Constants")

local Steal = {}
local ITEM_IDS = gameplay_constants.item_ids

local function fail_popup(game, stealer, target)
  local msg = "很遗憾，" .. target.name .. " 没有任何道具。"
  logger.event(stealer.name .. " 使用偷窃卡失败：" .. msg)
  return {
    ok = false,
    intent = { kind = "push_popup", payload = { title = "偷窃失败", body = msg } },
  }
end

function Steal.steal_item_at_index(game, player, target, item_idx)
  if Inventory.count(target) == 0 then
    return fail_popup(game, player, target)
  end
  local stolen = Inventory.remove_by_index(target, item_idx or 1)
  if not stolen then
    return nil
  end
  if Inventory.is_full(player) then
    logger.warn(player.name .. " 背包已满，偷窃道具被销毁")
    return nil
  end
  if not Inventory.add(player, stolen) then
    return nil
  end
  Inventory.consume(player, ITEM_IDS.steal)
  local name = Inventory.item_name(stolen.id)
  logger.event(player.name .. " 使用偷窃卡，从 " .. target.name .. " 偷走道具 " .. name)
  return {
    ok = true,
    stolen = stolen,
    intent = { kind = "push_popup", payload = { title = "偷窃成功", body = player.name .. " 从 " .. target.name .. " 偷走了 " .. name } },
  }
end

function Steal.build_prompt_spec(game, player, queue, index)
  local target_id = queue and queue[index]
  local target = target_id and game.players[target_id]
  if not player or not target then
    return nil
  end
  return LandChoiceSpecs.build_use_skip(
    "steal_prompt",
    "是否使用偷窃卡",
    { "目标：" .. target.name },
    { player_id = player.id, target_id = target.id, queue = queue, index = index }
  )
end

function Steal.handle_pass_players(game, player, encountered_ids)
  if #encountered_ids == 0 then
    return
  end
  if not Inventory.find_index(player, ITEM_IDS.steal) then
    return
  end

  local queue = {}
  for _, target_id in ipairs(encountered_ids) do
    local t = game.players[target_id]
    if t and not t.eliminated and not t:has_deity("angel") then
      table.insert(queue, t.id)
    end
  end
  if #queue == 0 then
    return
  end

  local spec = Steal.build_prompt_spec(game, player, queue, 1)
  if not spec then
    return nil
  end
  return {
    waiting = true,
    intent = {
      kind = "need_choice",
      choice_spec = spec,
    },
  }
end

return Steal
