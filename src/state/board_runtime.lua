-- state.board_runtime 切片:棋盘位置快照与 follow 目标。
-- 原 src/state/runtime.lua 的 board/follow 块;公共面仍由 runtime.lua 门面转发。
local tables = require("src.foundation.tables")

local M = {}

function M.ensure(state)
  assert(type(state) == "table", "missing state")
  local board_runtime = tables.ensure_table_field(state, "board_runtime")
  if board_runtime.board_last_positions == nil then
    board_runtime.board_last_positions = state.board_last_positions or {}
  end
  if board_runtime.follow_targets == nil then
    board_runtime.follow_targets = {}
  end
  tables.ensure_field(board_runtime, "board_sync_pending", state.board_sync_pending == true)
  tables.ensure_field(board_runtime, "board_last_phase", state.board_last_phase)
  return board_runtime
end

-- Out-of-order follow updates are dropped: a lower seq than the one already
-- recorded means this write is stale. Missing seqs never count as stale.
local function _is_stale_follow_seq(entry, next_seq)
  local last_seq = entry and entry.seq
  if next_seq == nil or last_seq == nil then
    return false
  end
  return next_seq < last_seq
end

local function _apply_follow_target(entry, position, opts, next_seq)
  entry.position = position
  entry.source = opts.source
  entry.seq = next_seq ~= nil and next_seq or entry.seq
end

local function _complete_args(state, player_id, position)
  return state ~= nil and player_id ~= nil and position ~= nil
end

local function _ensure_follow_entry(board_runtime, player_id)
  local entry = board_runtime.follow_targets[player_id]
  if entry == nil then
    entry = {}
    board_runtime.follow_targets[player_id] = entry
  end
  return entry
end

function M.set_follow_target_position(state, player_id, position, opts)
  if not _complete_args(state, player_id, position) then
    return false
  end
  local board_runtime = M.ensure(state)
  opts = opts or {}
  local next_seq = opts.seq
  if _is_stale_follow_seq(board_runtime.follow_targets[player_id], next_seq) then
    return false
  end
  local entry = _ensure_follow_entry(board_runtime, player_id)
  _apply_follow_target(entry, position, opts, next_seq)
  return true
end

function M.get_follow_target_position(state, player_id)
  if state == nil or player_id == nil then
    return nil
  end
  local board_runtime = M.ensure(state)
  local entry = board_runtime.follow_targets[player_id]
  return entry and entry.position or nil
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=fd3f0bc52c2a4a15
scope.0.id=chunk:src/state/board_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=75
scope.0.semanticHash=168d00656cfe70be
scope.1.id=function:M.ensure
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=19
scope.1.semanticHash=d22ce42482d8696b
scope.2.id=function:_is_stale_follow_seq
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=29
scope.2.semanticHash=5083598e8e093bc3
scope.3.id=function:_apply_follow_target
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=35
scope.3.semanticHash=24af63f51409e49a
scope.4.id=function:_complete_args
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=39
scope.4.semanticHash=342b68d7fd51b713
scope.5.id=function:_ensure_follow_entry
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=48
scope.5.semanticHash=8201eb7c77e87d53
scope.6.id=function:M.set_follow_target_position
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=63
scope.6.semanticHash=24f8e3a8e92b72e2
scope.7.id=function:M.get_follow_target_position
scope.7.kind=function
scope.7.startLine=65
scope.7.endLine=72
scope.7.semanticHash=1f8301ca12cd990b
]]
