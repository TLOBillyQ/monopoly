local ChoiceTimeout = require("src.turn.waits.choice_timeout")
local tick_ui_gate = require("src.turn.waits.ui_gate")
local countdown_resolve = require("src.turn.waits.countdown_resolve")
local dirty_tracker = require("src.state.dirty_tracker")

local tick_ui_sync = {}

-- 值变了才写回 turn 并打脏，避免无谓的 dirty 标记。
local function _sync_countdown_field(game, state, turn, last_key, turn_key, value)
  if value == state[last_key] then
    return
  end
  state[last_key] = value
  turn[turn_key] = value
  dirty_tracker.mark(game.dirty, "turn_countdown")
end

function tick_ui_sync.update_countdown(game, state)
  local turn = game and game.turn or nil
  if not turn then
    return
  end
  local timeout = ChoiceTimeout.resolve_choice_timeout_seconds(game, state)
  local gate = tick_ui_gate.resolve_ui_gate(state)
  local active, seconds, level = countdown_resolve.resolve_deadline(state)
  if active == nil then
    active, seconds = countdown_resolve.resolve_state(game, state, turn, timeout, gate)
  end
  _sync_countdown_field(game, state, turn, "countdown_last", "countdown_seconds", seconds)
  _sync_countdown_field(game, state, turn, "countdown_active_last", "countdown_active", active)
  _sync_countdown_field(game, state, turn, "countdown_warn_level_last", "countdown_warn_level", level)
end

return tick_ui_sync

--[[ mutate4lua-manifest
version=4
projectHash=4fa154fc63d577cc
scope.0.id=chunk:src/turn/waits/ui_sync.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=35
scope.0.semanticHash=7377d8a6254e8ae4
scope.1.id=function:_sync_countdown_field
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=16
scope.1.semanticHash=27c2b6bb85f01e67
scope.2.id=function:tick_ui_sync.update_countdown
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=32
scope.2.semanticHash=cbf3958994eb47f5
]]
