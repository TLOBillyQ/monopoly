-- 选择超时簿记(#602 拆分):deadline 作用域同步/重置与 owner 缺失清算,
-- 自 choice_timeout.lua 移出,引擎只留 tick 决策主线。
local choice_owner = require("src.turn.choice.owner")
local choice_scope = require("src.turn.deadlines.choice_scope")
local deadlines = require("src.turn.deadlines")

local M = {}

local function _owner_eliminated(owner_player)
  return owner_player ~= nil and owner_player.eliminated == true
end

local function _resolve_force_skip_reason(game, active_choice)
  if choice_owner.has_dangling_owner(game, active_choice) then
    return "owner_dangling"
  end
  if _owner_eliminated(choice_owner.resolve_player(game, active_choice)) then
    return "owner_eliminated"
  end
  return nil
end

-- owner 悬空/被淘汰的窗口不进倒计时:立即 force_skip 清算,不走自动代答。悬空
-- owner 若带「兜底当前回合玩家」的 actor 去派发,只会被 actor 校验拦截,窗口
-- 永不消失、blocked warn 每轮超时刷屏。
function M.maybe_force_skip_owner_missing(game, state, active_choice, output_ports)
  local reason = _resolve_force_skip_reason(game, active_choice)
  if reason ~= nil then
    output_ports.set_pending_choice_elapsed(state, 0)
    deadlines.force_skip(game, state, active_choice, reason)
    return true
  end
  return false
end

local function _cancel_choice_deadlines(state)
  deadlines.cancel(state, "choice")
  deadlines.cancel(state, "market_buy")
end

function M.reset_tracking(state, output_ports)
  output_ports.set_pending_choice_elapsed(state, 0)
  output_ports.set_pending_choice_id(state, nil)
  _cancel_choice_deadlines(state)
end

local function _sync_choice_identity(state, output_ports, active_choice, previous_choice_id)
  if previous_choice_id ~= active_choice.id then
    output_ports.set_pending_choice_elapsed(state, 0)
    output_ports.set_pending_choice_id(state, active_choice.id)
    _cancel_choice_deadlines(state)
  end
end

local function _other_choice_scope(scope)
  return scope == "choice" and "market_buy" or "choice"
end

local function _cancel_other_scope(state, scope)
  local other_scope = _other_choice_scope(scope)
  if deadlines.is_active(state, other_scope) then
    deadlines.cancel(state, other_scope)
  end
end

local function _start_scope_once(state, scope, timeout)
  if not deadlines.is_active(state, scope) then
    deadlines.start(state, scope, {
      timeout_seconds = timeout,
      priority = 100,
    })
  end
end

local function _sync_deadline_scope(state, active_choice, timeout)
  local scope = choice_scope.for_choice(active_choice)
  _cancel_other_scope(state, scope)
  _start_scope_once(state, scope, timeout)
end

function M.sync_tracking(state, output_ports, active_choice, previous_choice_id, timeout)
  _sync_choice_identity(state, output_ports, active_choice, previous_choice_id)
  _sync_deadline_scope(state, active_choice, timeout)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=76393bcff2e18c7d
scope.0.id=chunk:src/turn/waits/choice_timeout_tracking.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=87
scope.0.semanticHash=5593e08b2cb72b3f
scope.1.id=function:_owner_eliminated
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=be8994585243633b
scope.2.id=function:_resolve_force_skip_reason
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=21
scope.2.semanticHash=5f7fdbba41b5f791
scope.3.id=function:M.maybe_force_skip_owner_missing
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=34
scope.3.semanticHash=a6a5a4838b286a36
scope.4.id=function:_cancel_choice_deadlines
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=39
scope.4.semanticHash=b98c437249f994a5
scope.5.id=function:M.reset_tracking
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=45
scope.5.semanticHash=5efb81ec705fa503
scope.6.id=function:_sync_choice_identity
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=53
scope.6.semanticHash=3b8fd0aae9a52e73
scope.7.id=function:_other_choice_scope
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=57
scope.7.semanticHash=ca52c2eb57db3000
scope.8.id=function:_cancel_other_scope
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=64
scope.8.semanticHash=78eeb3ddb03286b1
scope.9.id=function:_start_scope_once
scope.9.kind=function
scope.9.startLine=66
scope.9.endLine=73
scope.9.semanticHash=287834eedf1aad4e
scope.10.id=function:_sync_deadline_scope
scope.10.kind=function
scope.10.startLine=75
scope.10.endLine=79
scope.10.semanticHash=6cf61cb499d2d060
scope.11.id=function:M.sync_tracking
scope.11.kind=function
scope.11.startLine=81
scope.11.endLine=84
scope.11.semanticHash=9def9e730d5d2d14
]]
