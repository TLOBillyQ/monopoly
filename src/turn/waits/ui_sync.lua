local tick_timeout = require("src.turn.waits.timeout")
local runtime_state = require("src.state.runtime")
local DeadlineService = require("src.turn.deadlines")
local dirty_tracker = require("src.state.dirty_tracker")

local tick_ui_sync = {}

local _ceil = math.ceil

local _log_prefix = "[Eggy]"

local function _resolve_detained_countdown(turn)
  local remaining = (turn.detained_wait_seconds or 0) - (turn.detained_wait_elapsed or 0)
  if remaining < 0 then
    remaining = 0
  end
  return true, _ceil(remaining)
end

local function _resolve_pending_choice_countdown(state, gate, timeout, pending_choice)
  local pending_choice_elapsed = runtime_state.get_pending_choice_elapsed(state)
  if pending_choice_elapsed < 0 then
    pending_choice_elapsed = 0
  end
  if gate.choice_active ~= true and gate.market_active ~= true then
    runtime_state.log_once(
      state,
      "info",
      "countdown_runtime_choice_without_ui_" .. tostring(pending_choice.id),
      _log_prefix,
      "countdown driven by runtime pending choice without ui choice screen",
      "choice_id=" .. tostring(pending_choice.id),
      "kind=" .. tostring(pending_choice.kind)
    )
  end
  local remaining = timeout - pending_choice_elapsed
  if remaining < 0 then
    remaining = 0
  end
  return true, _ceil(remaining)
end

local function _resolve_popup_countdown(game, state)
  local popup_timeout = tick_timeout.resolve_modal_timeout_seconds(game, state)
  if popup_timeout <= 0 then
    return false, 0
  end
  local remaining = popup_timeout - runtime_state.get_modal_elapsed(state)
  if remaining < 0 then
    remaining = 0
  end
  return true, _ceil(remaining)
end

local function _resolve_action_button_countdown(state, timeout)
  local remaining = timeout - (state.action_button_elapsed or 0)
  if remaining < 0 then
    remaining = 0
  end
  return true, _ceil(remaining)
end

local function _resolve_countdown_state(game, state, turn, timeout, gate)
  local pending_choice = turn.pending_choice or runtime_state.get_pending_choice(state)
  if turn.detained_wait_active then
    return _resolve_detained_countdown(turn)
  end
  if timeout <= 0 then
    return false, 0
  end
  if pending_choice ~= nil then
    return _resolve_pending_choice_countdown(state, gate, timeout, pending_choice)
  end
  if gate.popup_active == true then
    return _resolve_popup_countdown(game, state)
  end
  if state.action_button_active then
    return _resolve_action_button_countdown(state, timeout)
  end
  return false, 0
end


local function _resolve_deadline_countdown(state)
  local primary = DeadlineService.peek(state, "primary")
  if primary == nil then
    return nil, nil, nil
  end
  return true, _ceil(primary.remaining_seconds or 0), primary.level
end

function tick_ui_sync.update_countdown(game, state)
  local turn = game and game.turn or nil
  if not turn then
    return
  end
  local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
  local gate = tick_timeout.resolve_modal_gate(state)
  local active, seconds, level = _resolve_deadline_countdown(state)
  if active == nil then
    active, seconds = _resolve_countdown_state(game, state, turn, timeout, gate)
  end
  if seconds ~= state.countdown_last then
    state.countdown_last = seconds
    turn.countdown_seconds = seconds
    dirty_tracker.mark(game.dirty, "turn_countdown")
  end
  if active ~= state.countdown_active_last then
    state.countdown_active_last = active
    turn.countdown_active = active
    dirty_tracker.mark(game.dirty, "turn_countdown")
  end
  if level ~= state.countdown_warn_level_last then
    state.countdown_warn_level_last = level
    turn.countdown_warn_level = level
    dirty_tracker.mark(game.dirty, "turn_countdown")
  end
end

return tick_ui_sync

--[[ mutate4lua-manifest
version=2
projectHash=a91d13763acc92dc
scope.0.id=chunk:src/turn/waits/ui_sync.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=121
scope.0.semanticHash=72e437f75656ab55
scope.1.id=function:_resolve_detained_countdown:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=18
scope.1.semanticHash=28c3df38e134307d
scope.2.id=function:_resolve_pending_choice_countdown:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=41
scope.2.semanticHash=c4ae8e52a55ccf2a
scope.3.id=function:_resolve_popup_countdown:43
scope.3.kind=function
scope.3.startLine=43
scope.3.endLine=53
scope.3.semanticHash=9359382008f0fccb
scope.4.id=function:_resolve_action_button_countdown:55
scope.4.kind=function
scope.4.startLine=55
scope.4.endLine=61
scope.4.semanticHash=138e6f42e8173f9c
scope.5.id=function:_resolve_countdown_state:63
scope.5.kind=function
scope.5.startLine=63
scope.5.endLine=81
scope.5.semanticHash=778ad8d0afd69b91
scope.6.id=function:_resolve_deadline_countdown:84
scope.6.kind=function
scope.6.startLine=84
scope.6.endLine=90
scope.6.semanticHash=a7847c45c708c1e1
scope.7.id=function:tick_ui_sync.update_countdown:92
scope.7.kind=function
scope.7.startLine=92
scope.7.endLine=118
scope.7.semanticHash=fc8034bf9d96b05c
]]
