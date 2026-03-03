local tip_text = {}

local function _resolve_tile_name(state, tile_index)
  if not state or not tile_index then
    return "未知地块"
  end
  local game = state.game
  local board = game and game.board or nil
  local tile = board and board.get_tile and board:get_tile(tile_index) or nil
  if tile and tile.name then
    return tile.name
  end
  return "未知地块"
end

local function _resolve_player_name(state, player_id)
  if not player_id then
    return "未知玩家"
  end
  local game = state and state.game or nil
  local player = game and game.find_player_by_id and game:find_player_by_id(player_id) or nil
  if player and player.name then
    return player.name
  end
  return tostring(player_id)
end

function tip_text.build(state, anim)
  if anim.focus_text and anim.focus_text ~= "" then
    return anim.focus_text
  end
  local kind = anim.kind
  if kind == "roll" then
    local rolls = anim.rolls and table.concat(anim.rolls, ",") or "?"
    local total = anim.total or "?"
    return "投骰动画：" .. rolls .. " => " .. tostring(total)
  end
  if kind == "roadblock" then
    return "路障动画：放置在 " .. _resolve_tile_name(state, anim.tile_index)
  end
  if kind == "mine" then
    return "地雷动画：埋设在 " .. _resolve_tile_name(state, anim.tile_index)
  end
  if kind == "missile" then
    return "导弹动画：轰炸 " .. _resolve_tile_name(state, anim.tile_index)
  end
  if kind == "monster" then
    return "怪兽动画：破坏 " .. _resolve_tile_name(state, anim.tile_index)
  end
  if kind == "clear_obstacles" then
    local count = anim.cleared_indices and #anim.cleared_indices or 0
    return "清障动画：清除数量 " .. tostring(count)
  end
  if kind == "upgrade_land" then
    return "加盖动画：" .. _resolve_tile_name(state, anim.tile_index)
  end
  if kind == "chance" then
    return "机会卡展示：" .. tostring(anim.card_desc or anim.card_id or "?")
  end
  if kind == "item_use" then
    return "道具生效：" .. tostring(anim.item_name or anim.item_id or "?")
  end
  if kind == "item_target_player" then
    local target_name = _resolve_player_name(state, anim.target_player_id)
    return "目标道具：" .. tostring(anim.item_name or anim.item_id or "?")
      .. " -> 玩家 " .. target_name
  end
  if kind == "move_effect" then
    return "位移动画：从 "
      .. _resolve_tile_name(state, anim.from_index)
      .. " 到 "
      .. _resolve_tile_name(state, anim.to_index)
  end
  return "动作动画"
end

return tip_text
