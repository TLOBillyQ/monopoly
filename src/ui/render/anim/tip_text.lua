local number_utils = require("src.foundation.number")

local tip_text = {}

local UNKNOWN_TILE = "未知地块"
local UNKNOWN_PLAYER = "未知玩家"

local function _board_of(state)
  local game = state and state.game or nil
  return game and game.board or nil
end

local function _tile_at(state, tile_index)
  local board = _board_of(state)
  if board and board.get_tile then
    return board:get_tile(tile_index)
  end
  return nil
end

local function _resolve_tile_name(state, tile_index)
  if not state or not tile_index then
    return UNKNOWN_TILE
  end
  local tile = _tile_at(state, tile_index)
  if tile and tile.name then
    return tile.name
  end
  return UNKNOWN_TILE
end

local function _game_of(state)
  return state and state.game or nil
end

local function _player_of(state, player_id)
  local game = _game_of(state)
  if game and game.find_player_by_id then
    return game:find_player_by_id(player_id) or nil
  end
  return nil
end

local function _resolve_player_name(state, player_id)
  if not player_id then
    return UNKNOWN_PLAYER
  end
  local player = _player_of(state, player_id)
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

local function _build_player_tile_text(verb)
  return function(state, anim)
    return _resolve_player_name(state, anim.player_id) .. verb .. _resolve_tile_name(state, anim.tile_index)
  end
end

local function _cleared_obstacle_parts(anim)
  local rb = anim.roadblock_cleared or 0
  local mn = anim.mine_cleared or 0
  local parts = {}
  if rb > 0 then
    parts[#parts + 1] = tostring(rb) .. " 个路障"
  end
  if mn > 0 then
    parts[#parts + 1] = tostring(mn) .. " 个地雷"
  end
  return parts
end

local function _build_clear_obstacles_text(state, anim)
  local player_name = _resolve_player_name(state, anim.player_id)
  local parts = _cleared_obstacle_parts(anim)
  if #parts == 0 then
    return player_name .. " 的清障机器人出动，前方没有障碍"
  end
  return player_name .. " 的清障机器人出动，清除了 " .. table.concat(parts, "、")
end

local function _build_chance_text(_, anim)
  return "机会卡展示：" .. tostring(anim.card_desc or anim.card_id or "?")
end

local function _build_item_use_text(_, anim)
  return "道具生效：" .. _resolve_item_name(anim)
end

local function _build_item_gain_text(state, anim)
  return _resolve_player_name(state, anim.player_id) .. " 获得道具卡：" .. _resolve_item_name(anim)
end

local function _build_item_target_player_text(state, anim)
  local player_name = _resolve_player_name(state, anim.player_id)
  local target_name = _resolve_player_name(state, anim.target_player_id)
  return player_name .. " 对 " .. target_name .. " 使用了 " .. _resolve_item_name(anim)
end

local function _build_teleport_text(state, anim)
  local player_name = _resolve_player_name(state, anim.player_id)
  return player_name .. " 被传送到 "
    .. _resolve_tile_name(state, anim.to_index)
end

local function _build_debug_move_text(state, anim)
  return "位移动画：" .. _resolve_player_name(state, anim.player_id)
    .. " 从 " .. _resolve_tile_name(state, anim.from_index)
    .. " 到 " .. _resolve_tile_name(state, anim.to_index)
end

local function _build_mine_trigger_text(state, anim)
  local player_name = _resolve_player_name(state, anim.player_id)
  return "地雷触发：" .. player_name .. " 从 "
    .. _resolve_tile_name(state, anim.from_index)
    .. " 到 "
    .. _resolve_tile_name(state, anim.to_index)
end

local function _build_cash_receive_text(state, anim)
  local player_name = _resolve_player_name(state, anim.player_id)
  local amount = anim.amount or "?"
  return "收钱动画：" .. player_name .. " +" .. number_utils.format_integer_part(amount)
end

local TIP_BUILDERS = {
  roll = _build_roll_text,
  roadblock = _build_tile_text("路障动画：放置在 "),
  mine = _build_tile_text("地雷动画：埋设在 "),
  missile = _build_player_tile_text(" 发射导弹轰炸 "),
  monster = _build_player_tile_text(" 释放怪兽攻击 "),
  clear_obstacles = _build_clear_obstacles_text,
  upgrade_land = _build_tile_text("加盖动画："),
  chance = _build_chance_text,
  item_gain_popup = _build_item_gain_text,
  item_use = _build_item_use_text,
  item_target_player = _build_item_target_player_text,
  move_effect = _build_debug_move_text,
  teleport_effect = _build_teleport_text,
  forced_relocation = _build_debug_move_text,
   roadblock_trigger = _build_tile_text("路障触发："),
   mine_trigger = _build_mine_trigger_text,
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

--[[ mutate4lua-manifest
version=4
projectHash=3bedf0bc5a909d83
scope.0.id=chunk:src/ui/render/anim/tip_text.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=172
scope.0.semanticHash=9966b17d9fe98dc9
scope.1.id=function:_board_of
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=11
scope.1.semanticHash=93c839897afe61e5
scope.2.id=function:_tile_at
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=19
scope.2.semanticHash=a46f6fef7c02541b
scope.3.id=function:_resolve_tile_name
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=30
scope.3.semanticHash=bedf41a6b6262fb7
scope.4.id=function:_game_of
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=34
scope.4.semanticHash=616a2ca60599c94f
scope.5.id=function:_player_of
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=42
scope.5.semanticHash=0f03d3822581e1b3
scope.6.id=function:_resolve_player_name
scope.6.kind=function
scope.6.startLine=44
scope.6.endLine=53
scope.6.semanticHash=e46038f24f08570e
scope.7.id=function:_resolve_item_name
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=57
scope.7.semanticHash=70e2a06c7600f2a6
scope.8.id=function:_build_roll_text
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=63
scope.8.semanticHash=e24c970831406aee
scope.9.id=function:_build_tile_text
scope.9.kind=function
scope.9.startLine=65
scope.9.endLine=69
scope.9.semanticHash=320bcfa4af501611
scope.10.id=function:<anonymous>
scope.10.kind=function
scope.10.startLine=66
scope.10.endLine=68
scope.10.semanticHash=fc3dac52f58963e4
scope.11.id=function:_build_player_tile_text
scope.11.kind=function
scope.11.startLine=71
scope.11.endLine=75
scope.11.semanticHash=6a03762434fbc985
scope.12.id=function:<anonymous>#2
scope.12.kind=function
scope.12.startLine=72
scope.12.endLine=74
scope.12.semanticHash=30fcd24e713bfce0
scope.13.id=function:_cleared_obstacle_parts
scope.13.kind=function
scope.13.startLine=77
scope.13.endLine=88
scope.13.semanticHash=b62efe394f21b203
scope.14.id=function:_build_clear_obstacles_text
scope.14.kind=function
scope.14.startLine=90
scope.14.endLine=97
scope.14.semanticHash=ebacbabbadfb2ea9
scope.15.id=function:_build_chance_text
scope.15.kind=function
scope.15.startLine=99
scope.15.endLine=101
scope.15.semanticHash=ad540fa8bd72a72e
scope.16.id=function:_build_item_use_text
scope.16.kind=function
scope.16.startLine=103
scope.16.endLine=105
scope.16.semanticHash=57d6352957eb3f49
scope.17.id=function:_build_item_gain_text
scope.17.kind=function
scope.17.startLine=107
scope.17.endLine=109
scope.17.semanticHash=6d76d205f000ff13
scope.18.id=function:_build_item_target_player_text
scope.18.kind=function
scope.18.startLine=111
scope.18.endLine=115
scope.18.semanticHash=61cb76067d31120c
scope.19.id=function:_build_teleport_text
scope.19.kind=function
scope.19.startLine=117
scope.19.endLine=121
scope.19.semanticHash=5c434e7558e69cab
scope.20.id=function:_build_debug_move_text
scope.20.kind=function
scope.20.startLine=123
scope.20.endLine=127
scope.20.semanticHash=bafb57c32fdcfc0b
scope.21.id=function:_build_mine_trigger_text
scope.21.kind=function
scope.21.startLine=129
scope.21.endLine=135
scope.21.semanticHash=bbf91c0809db5a07
scope.22.id=function:_build_cash_receive_text
scope.22.kind=function
scope.22.startLine=137
scope.22.endLine=141
scope.22.semanticHash=2b5e4685208adc39
scope.23.id=function:tip_text.build
scope.23.kind=function
scope.23.startLine=163
scope.23.endLine=169
scope.23.semanticHash=8c8e69ca3e63e707
]]
