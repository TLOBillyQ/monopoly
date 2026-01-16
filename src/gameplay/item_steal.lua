local logger = require("src.util.logger")
local UI = require("src.gameplay.ui_port")
local Inventory = require("src.gameplay.item_inventory")

local Steal = {}

function Steal.steal_item_at_index(game, player, target, item_idx)
  local inv = target.inventory
  if inv:count() == 0 then
    Inventory.consume(player, 2007)
    logger.warn(target.name .. " 没有可偷道具")
    return {
      ok = false,
      intent = { kind = "push_popup", payload = { title = "偷窃失败", body = "很遗憾，目标没有任何道具。" } },
    }
  end
  local stolen = inv:remove_by_index(item_idx or 1)
  if not stolen then
    return nil
  end
  if player.inventory:is_full() then
    logger.warn(player.name .. " 背包已满，偷窃道具被销毁")
    return nil
  end
  player.inventory:add(stolen)
  Inventory.consume(player, 2007)
  local name = Inventory.item_name(stolen.id)
  logger.event(player.name .. " 使用偷窃卡，从 " .. target.name .. " 偷走道具 " .. name)
  return {
    ok = true,
    stolen = stolen,
    intent = { kind = "push_popup", payload = { title = "偷窃成功", body = player.name .. " 从 " .. target.name .. " 偷走了 " .. name } },
  }
end

function Steal.handle_pass_players(game, player, encountered_ids)
  if #encountered_ids == 0 then
    return
  end
  if not Inventory.find_index(player, 2007) then
    return
  end

  local targets = {}
  for _, target_id in ipairs(encountered_ids) do
    local t = game.players[target_id]
    if t and not t:has_deity("angel") and not t.eliminated then
      table.insert(targets, t)
    end
  end
  if #targets == 0 then
    return
  end

  if not UI.is_available(game) then
    Steal.steal_item_at_index(game, player, targets[1], 1)
    return nil
  end

  local target = targets[1]
  local target_ids = {}
  for _, t in ipairs(targets) do
    table.insert(target_ids, t.id)
  end
  return {
    waiting = true,
    intent = {
      kind = "need_choice",
      choice_spec = {
        kind = "steal_pass_prompt",
        title = "偷窃卡",
        body_lines = { "目标：" .. target.name .. "，你有偷窃卡，可以偷取他的一个道具，是否对他使用？" },
        options = {
          { id = "use", label = "使用" },
          { id = "skip", label = "放弃" },
        },
        allow_cancel = false,
        meta = { stealer_id = player.id, target_ids = target_ids, index = 1 },
      },
    },
  }
end

return Steal
