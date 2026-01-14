local logger = require("src.util.logger")
local UI = require("src.gameplay.ports.ui_port")

local Steal = {}

local function find_item_index(player, item_id)
  return player.inventory:find_index(function(it)
    return it.id == item_id
  end)
end

function Steal.steal_item_at_index(game, player, target, item_idx, opts)
  opts = opts or {}
  local item_name = opts.item_name or tostring
  local consume_item = opts.consume_item

  local inv = target.inventory
  if inv:count() == 0 then
    logger.warn(target.name .. " 没有可偷道具")
    return nil
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
  if consume_item then
    consume_item(player, 2007)
  end
  logger.event(player.name .. " 使用偷窃卡，从 " .. target.name .. " 偷走道具 " .. item_name(stolen.id))
  return {
    ok = true,
    stolen = stolen,
    intent = { kind = "push_popup", payload = { title = "偷窃成功", body = player.name .. " 从 " .. target.name .. " 偷走了 " .. item_name(stolen.id) } },
  }
end




function Steal.handle_pass_players(game, player, encountered_ids, opts)
  opts = opts or {}
  local item_name = opts.item_name or tostring

  if #encountered_ids == 0 then
    return
  end
  local has_steal = find_item_index(player, 2007)
  if not has_steal then
    return
  end

  local candidates = {}
  for _, target_id in ipairs(encountered_ids) do
    local t = game.players[target_id]
    if t and not t:has_deity("angel") and t.inventory:count() > 0 then
      table.insert(candidates, t)
    end
  end
  if #candidates == 0 then
    return
  end

  if not UI.is_available(game) then
    Steal.steal_item_at_index(game, player, candidates[1], 1, opts)
    return nil
  end

  if #candidates == 1 then
    local target = candidates[1]
    if target.inventory:count() <= 1 then
      Steal.steal_item_at_index(game, player, target, 1, opts)
      return nil
    end
    local options = {}
    local body_lines = {}
    for idx, it in ipairs(target.inventory.items) do
      local label = item_name(it.id)
      table.insert(body_lines, idx .. ". " .. label)
      table.insert(options, { id = idx, label = label })
    end
    return {
      waiting = true,
      intent = {
        kind = "need_choice",
        choice_spec = {
          kind = "steal_item",
          title = "选择要偷的道具",
          body_lines = body_lines,
          options = options,
          allow_cancel = true,
          cancel_label = "取消",
          meta = { stealer_id = player.id, target_id = target.id },
        },
      },
    }
  end

  local options = {}
  local body_lines = {}
  for _, t in ipairs(candidates) do
    table.insert(body_lines, t.name .. " 现金:" .. t.cash)
    table.insert(options, { id = t.id, label = t.name })
  end
  return {
    waiting = true,
    intent = {
      kind = "need_choice",
      choice_spec = {
        kind = "steal_target",
        title = "偷窃卡：选择目标",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "取消",
        meta = { stealer_id = player.id },
      },
    },
  }
end

return Steal
