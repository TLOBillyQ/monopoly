local common = require("src.player.actions.state_common")

local status_ops = {}

function status_ops.set_player_status(self, player, key, value)
  local status = common.player_status_table(player)
  status[key] = value
  common.mark_players(self)
end

function status_ops.player_dice_count(_self, _player)
  return common.constants.default_dice_count
end

-- 骰子加倍：读归一化倍数（未设置或 <=1 一律视为 1，即无加倍）。
function status_ops.player_pending_dice_multiplier(_self, player)
  local status = player and player.status or nil
  local pending = status and status.pending_dice_multiplier or nil
  if not pending or pending <= 1 then
    return 1
  end
  return pending
end

-- 骰子加倍：消费——返回归一化倍数并复位为 1。
function status_ops.consume_pending_dice_multiplier(self, player)
  local pending = status_ops.player_pending_dice_multiplier(self, player)
  local status = common.player_status_table(player)
  status.pending_dice_multiplier = 1
  common.mark_players(self)
  return pending
end

-- 遥控骰子：设定待生效点数（values 为逐颗点数列表）。
function status_ops.set_pending_remote_dice(self, player, values)
  assert(type(values) == "table" and values[1] ~= nil, "invalid remote dice values")
  local status = common.player_status_table(player)
  status.pending_remote_dice = { values = values }
  common.mark_players(self)
end

-- 遥控骰子：只读点数列表；未设置返回 nil（投骰阶段读，回合清理时清除）。
function status_ops.peek_pending_remote_dice(_self, player)
  local status = player and player.status or nil
  local pending = status and status.pending_remote_dice or nil
  return pending and pending.values or nil
end

-- 扣留剩余回合（ADR 0024 含当前回合口径）：被扣留期间恒 >= 1，计到 0 即解除。
function status_ops.detention_remaining(_self, player)
  local status = player and player.status or nil
  local remaining = status and status.stay_turns or 0
  if remaining <= 0 then
    return 0
  end
  return remaining
end

-- 回合开始消耗一回合扣留：返回本回合玩家可见的含当前回合剩余（>= 1）；
-- 未被扣留时不改状态并返回 0。消费后 detention_remaining 即为减后剩余。
function status_ops.consume_detention_turn(self, player)
  local remaining_inclusive = status_ops.detention_remaining(self, player)
  if remaining_inclusive <= 0 then
    return 0
  end
  local status = common.player_status_table(player)
  status.stay_turns = remaining_inclusive - 1
  common.mark_players(self)
  return remaining_inclusive
end

function status_ops.player_own_turn_started_count(_self, player)
  local status = player and player.status or nil
  return status and status.own_turn_started_count or 0
end

function status_ops.increment_own_turn_started_count(self, player)
  local next_count = status_ops.player_own_turn_started_count(self, player) + 1
  local status = common.player_status_table(player)
  status.own_turn_started_count = next_count
  common.mark_players(self)
  return next_count
end

local function _peek_status_flag(player, key)
  local status = player and player.status or nil
  return (status and status[key]) == true
end

local function _consume_status_flag(self, player, key)
  if not _peek_status_flag(player, key) then
    return false
  end
  local status = common.player_status_table(player)
  status[key] = false
  common.mark_players(self)
  return true
end

function status_ops.has_pending_free_rent(_self, player)
  return _peek_status_flag(player, "pending_free_rent")
end

-- 一次性免租：命中则清除并返回 true。
function status_ops.consume_pending_free_rent(self, player)
  return _consume_status_flag(self, player, "pending_free_rent")
end

function status_ops.has_pending_tax_free(_self, player)
  return _peek_status_flag(player, "pending_tax_free")
end

-- 一次性免税：命中则清除并返回 true。
function status_ops.consume_pending_tax_free(self, player)
  return _consume_status_flag(self, player, "pending_tax_free")
end

function status_ops.set_player_eliminated(self, player, eliminated)
  player.eliminated = eliminated == true
  common.mark_players(self)
end

function status_ops.set_player_property(self, player, tile_id, owned)
  player.properties = player.properties or {}
  if owned then
    player.properties[tile_id] = true
  else
    player.properties[tile_id] = nil
  end
  common.mark_players(self)
end

function status_ops.clear_player_temporal_flags(self, player)
  local status = common.player_status_table(player)
  status.pending_dice_multiplier = 1
  status.pending_free_rent = false
  status.pending_tax_free = false
  status.pending_remote_dice = nil
  common.mark_players(self)
end

local function _clear_player_move_dir(player)
  local status = common.player_status_table(player)
  if status.move_dir == nil then
    return false
  end
  status.move_dir = nil
  return true
end

local function _is_outer_tile(game, player)
  if not (game and game.board and game.board.map and game.board.map.outer_next and player and player.position) then
    return true
  end
  local tile = game.board:get_tile(player.position)
  if tile == nil then
    return true
  end
  return game.board.map.outer_next[tile.id] ~= nil
end

local function _stop_player_movement(game, player)
  if not _is_outer_tile(game, player) then
    return false
  end
  return _clear_player_move_dir(player)
end

local function _stop_all_players(game, players)
  local players_dirty = false
  for _, player in ipairs(players or {}) do
    if _stop_player_movement(game, player) then
      players_dirty = true
    end
  end
  return players_dirty
end

function status_ops.stop_all_players_movement(self)
  local players_dirty = _stop_all_players(self, self.players)
  if players_dirty then
    common.mark_players(self)
  end
end

return status_ops

--[[ mutate4lua-manifest
version=2
projectHash=a63f088e3346e0a7
scope.0.id=chunk:src/player/actions/status.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=84
scope.0.semanticHash=fe4264a7a57fdf8f
scope.1.id=function:status_ops.set_player_status:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=9
scope.1.semanticHash=13ef2b09db719bdd
scope.2.id=function:status_ops.player_dice_count:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=13
scope.2.semanticHash=e2a48334e4486cb9
scope.3.id=function:status_ops.set_player_eliminated:15
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=18
scope.3.semanticHash=55080555ae63f0f2
scope.4.id=function:status_ops.set_player_property:20
scope.4.kind=function
scope.4.startLine=20
scope.4.endLine=28
scope.4.semanticHash=db5ce1a41e471bc6
scope.5.id=function:status_ops.clear_player_temporal_flags:30
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=37
scope.5.semanticHash=21f41f27afa6cc2a
scope.6.id=function:_clear_player_move_dir:39
scope.6.kind=function
scope.6.startLine=39
scope.6.endLine=46
scope.6.semanticHash=c4e4321e1b26a799
scope.7.id=function:_is_outer_tile:48
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=57
scope.7.semanticHash=6c43d8b3ac8a0c44
scope.8.id=function:_stop_player_movement:59
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=64
scope.8.semanticHash=c3b862bcd8a47524
scope.9.id=function:status_ops.stop_all_players_movement:76
scope.9.kind=function
scope.9.startLine=76
scope.9.endLine=81
scope.9.semanticHash=b705ccbb3a5540d3
]]
