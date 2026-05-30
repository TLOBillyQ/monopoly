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

local function _build_player_tile_text(verb)
  return function(state, anim)
    return _resolve_player_name(state, anim.player_id) .. verb .. _resolve_tile_name(state, anim.tile_index)
  end
end

local function _build_clear_obstacles_text(state, anim)
  local player_name = _resolve_player_name(state, anim.player_id)
  local rb = anim.roadblock_cleared or 0
  local mn = anim.mine_cleared or 0
  local parts = {}
  if rb > 0 then
    parts[#parts + 1] = tostring(rb) .. " 个路障"
  end
  if mn > 0 then
    parts[#parts + 1] = tostring(mn) .. " 个地雷"
  end
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
  return "收钱动画：" .. player_name .. " +" .. tostring(amount)
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
version=2
projectHash=57e4b4c6de794d40
scope.0.id=chunk:src/ui/render/anim/tip_text.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=138
scope.0.semanticHash=be72e5196648478b
scope.1.id=function:_resolve_tile_name:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=17
scope.1.semanticHash=0d3a3e414d6eedb1
scope.2.id=function:_resolve_player_name:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=29
scope.2.semanticHash=cc2d9a3e3bef4de8
scope.3.id=function:_resolve_item_name:31
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=33
scope.3.semanticHash=f3f17deb30b64137
scope.4.id=function:_build_roll_text:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=39
scope.4.semanticHash=2e02d8690fd781c7
scope.5.id=function:anonymous@42:42
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=44
scope.5.semanticHash=7c69ef67a826276f
scope.6.id=function:_build_tile_text:41
scope.6.kind=function
scope.6.startLine=41
scope.6.endLine=45
scope.6.semanticHash=97a2b10de001cde3
scope.7.id=function:anonymous@48:48
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=50
scope.7.semanticHash=f4b2c2e3158e61a1
scope.8.id=function:_build_player_tile_text:47
scope.8.kind=function
scope.8.startLine=47
scope.8.endLine=51
scope.8.semanticHash=bf2664bb63c743c6
scope.9.id=function:_build_clear_obstacles_text:53
scope.9.kind=function
scope.9.startLine=53
scope.9.endLine=68
scope.9.semanticHash=6a2a8783e5278382
scope.10.id=function:_build_chance_text:70
scope.10.kind=function
scope.10.startLine=70
scope.10.endLine=72
scope.10.semanticHash=9b54d533ed862467
scope.11.id=function:_build_item_use_text:74
scope.11.kind=function
scope.11.startLine=74
scope.11.endLine=76
scope.11.semanticHash=c8741f36f807efa5
scope.12.id=function:_build_item_target_player_text:78
scope.12.kind=function
scope.12.startLine=78
scope.12.endLine=82
scope.12.semanticHash=e06856053fa689cb
scope.13.id=function:_build_teleport_text:84
scope.13.kind=function
scope.13.startLine=84
scope.13.endLine=88
scope.13.semanticHash=7d21ada696f63aee
scope.14.id=function:_build_debug_move_text:90
scope.14.kind=function
scope.14.startLine=90
scope.14.endLine=94
scope.14.semanticHash=bdcf28d9cbecac27
scope.15.id=function:_build_mine_trigger_text:96
scope.15.kind=function
scope.15.startLine=96
scope.15.endLine=102
scope.15.semanticHash=9ff910198ea67720
scope.16.id=function:_build_cash_receive_text:104
scope.16.kind=function
scope.16.startLine=104
scope.16.endLine=108
scope.16.semanticHash=714e4e2f6f977c34
scope.17.id=function:tip_text.build:129
scope.17.kind=function
scope.17.startLine=129
scope.17.endLine=135
scope.17.semanticHash=3c35759709a9372e
]]
