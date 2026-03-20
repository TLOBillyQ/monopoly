local tip_text = {}

local UNKNOWN_TILE = "未知地块"
local UNKNOWN_PLAYER = "未知玩家"

local function _resolve_tile_name(state, tile_index)
  if not state or not tile_index then
    return UNKNOWN_TILE
  end
  local game = state.game
  local board = game and game.board or nil
  local tile = board and board.get_tile and board:get_tile(tile_index) or nil
  if tile and tile.name then
    return tile.name
  end
  return UNKNOWN_TILE
end

local function _resolve_player_name(state, player_id)
  if not player_id then
    return UNKNOWN_PLAYER
  end
  local game = state and state.game or nil
  local player = game and game.find_player_by_id and game:find_player_by_id(player_id) or nil
  if player and player.name then
    return player.name
  end
  return tostring(player_id)
end

local function _resolve_item_name(anim)
  return tostring(anim.item_name or anim.item_id or "?")
end

local function _build_roll_text(_, anim)
  local rolls = anim.rolls and table.concat(anim.rolls, ",") or "?"
  local total = anim.total or "?"
  return "投骰动画：" .. rolls .. " => " .. tostring(total)
end

local function _build_tile_text(prefix)
  return function(state, anim)
    return prefix .. _resolve_tile_name(state, anim.tile_index)
  end
end

local function _build_clear_obstacles_text(_, anim)
  local count = anim.cleared_indices and #anim.cleared_indices or 0
  return "清障动画：清除数量 " .. tostring(count)
end

local function _build_chance_text(_, anim)
  return "机会卡展示：" .. tostring(anim.card_desc or anim.card_id or "?")
end

local function _build_item_use_text(_, anim)
  return "道具生效：" .. _resolve_item_name(anim)
end

local function _build_item_target_player_text(state, anim)
  local target_name = _resolve_player_name(state, anim.target_player_id)
  return "目标道具：" .. _resolve_item_name(anim) .. " -> 玩家 " .. target_name
end

local function _build_move_effect_text(state, anim)
  return "位移动画：从 "
    .. _resolve_tile_name(state, anim.from_index)
    .. " 到 "
    .. _resolve_tile_name(state, anim.to_index)
end

local function _build_mine_trigger_text(state, anim)
  local player_name = _resolve_player_name(state, anim.player_id)
  return "地雷触发：" .. player_name .. " 从 "
    .. _resolve_tile_name(state, anim.from_index)
    .. " 到 "
    .. _resolve_tile_name(state, anim.to_index)
end

local function _build_change_skin_text(state, anim)
  local player_name = _resolve_player_name(state, anim.player_id)
  local skin = anim.skin_name or anim.skin_id or "?"
  return "换肤动画：" .. player_name .. " -> " .. tostring(skin)
end

local function _build_cash_receive_text(state, anim)
  local player_name = _resolve_player_name(state, anim.player_id)
  local amount = anim.amount or "?"
  return "收钱动画：" .. player_name .. " +" .. tostring(amount)
end

local TIP_BUILDERS = {
  roll = _build_roll_text,
  roadblock = _build_tile_text("路障动画：放置在 "),
  mine = _build_tile_text("地雷动画：埋设在 "),
  missile = _build_tile_text("导弹动画：轰炸 "),
  monster = _build_tile_text("怪兽动画：破坏 "),
  clear_obstacles = _build_clear_obstacles_text,
  upgrade_land = _build_tile_text("加盖动画："),
  chance = _build_chance_text,
  item_use = _build_item_use_text,
  item_target_player = _build_item_target_player_text,
  move_effect = _build_move_effect_text,
  teleport_effect = _build_move_effect_text,
  mine_trigger = _build_mine_trigger_text,
  change_skin = _build_change_skin_text,
  cash_receive = _build_cash_receive_text,
}

function tip_text.build(state, anim)
  if anim.focus_text and anim.focus_text ~= "" then
    return anim.focus_text
  end
  local builder = TIP_BUILDERS[anim.kind]
  return builder and builder(state, anim) or nil
end

return tip_text
