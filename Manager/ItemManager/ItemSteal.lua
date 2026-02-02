local Logger = require("Components.Logger")
local Inventory = require("Manager.ItemManager.ItemInventory")
local LandChoiceSpecs = require("Manager.LandManager.LandChoiceSpecs")
local GameplayRules = require("Config.GameplayRules")

local Steal = {}
local ITEM_IDS = GameplayRules.item_ids

local function _FailPopup(game, stealer, target)
  local msg = "很遗憾，" .. target.name .. " 没有任何道具。"
  Logger.Event(stealer.name .. " 使用偷窃卡失败：" .. msg)
  return {
    ok = false,
    intent = { kind = "push_popup", payload = { title = "偷窃失败", body = msg } },
  }
end

function Steal.StealItemAtIndex(game, player, target, item_idx)
  if Inventory.Count(target) == 0 then
    return _FailPopup(game, player, target)
  end
  local stolen = Inventory.RemoveByIndex(target, item_idx or 1)
  assert(stolen ~= nil, "missing stolen item")
  if Inventory.IsFull(player) then
    Logger.Warn(player.name .. " 背包已满，偷窃道具被销毁")
    return nil
  end
  assert(Inventory.Add(player, stolen) == true, "add stolen item failed")
  Inventory.Consume(player, ITEM_IDS.steal)
  local name = Inventory.ItemName(stolen.id)
  Logger.Event(player.name .. " 使用偷窃卡，从 " .. target.name .. " 偷走道具 " .. name)
  return {
    ok = true,
    stolen = stolen,
    intent = { kind = "push_popup", payload = { title = "偷窃成功", body = player.name .. " 从 " .. target.name .. " 偷走了 " .. name } },
  }
end

function Steal.BuildPromptSpec(game, player, queue, index)
  assert(queue ~= nil, "missing queue")
  local target_id = assert(queue[index], "missing target id")
  assert(player ~= nil, "missing player")
  local target = assert(game.players[target_id], "missing target player: " .. tostring(target_id))
  return LandChoiceSpecs.BuildUseSkip(
    "steal_prompt",
    "是否使用偷窃卡",
    { "目标：" .. target.name },
    { player_id = player.id, target_id = target.id, queue = queue, index = index }
  )
end

function Steal.HandlePassPlayers(game, player, encountered_ids)
  if #encountered_ids == 0 then
    return
  end
  assert(Inventory.FindIndex(player, ITEM_IDS.steal) ~= nil, "missing steal item")

  local queue = {}
  for _, target_id in ipairs(encountered_ids) do
    local t = assert(game.players[target_id], "missing target player: " .. tostring(target_id))
    if not t.eliminated and not t:HasDeity("angel") then
      table.insert(queue, t.id)
    end
  end
  if #queue == 0 then
    return
  end

  assert(game.ui_port ~= nil, "missing ui_port")

  local spec = Steal.BuildPromptSpec(game, player, queue, 1)
  assert(spec ~= nil, "missing steal prompt spec")
  return {
    waiting = true,
    intent = {
      kind = "need_choice",
      choice_spec = spec,
    },
  }
end

return Steal



