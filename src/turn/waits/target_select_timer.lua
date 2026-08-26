-- 道具目标选择阶段独立超时。借用 DeadlineService 的 target_select scope；
-- item_phase_ask 二次确认屏激活（pending_confirmation）后注册 deadline，
-- 到点调 deadlines.resolve_target_select。
local timing = require("src.config.gameplay.timing")
local deadlines = require("src.turn.deadlines")
local pending_confirmation = require("src.state.pending_confirmation")
local NumberUtils = require("src.foundation.number")
local choice_owner = require("src.turn.choice.owner")
local afk_signal = require("src.turn.policies.afk_signal")

local M = {}

local function _resolve_target_select_timeout()
  local timeouts = timing.scope_timeouts
  if type(timeouts) == "table" and NumberUtils.is_numeric(timeouts.target_select) and timeouts.target_select > 0 then
    return timeouts.target_select
  end
  return 15
end

local function _is_target_select_active(state)
  return pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
end

local function _pending_choice(game)
  return game and game.turn and game.turn.pending_choice or nil
end

local function _resolve_target_owner(game, choice)
  if choice_owner.has_dangling_owner(game, choice) then
    return nil
  end
  return choice_owner.resolve_player(game, choice)
end

local function _notify_target_timeout(game, state, choice)
  local owner_player = _resolve_target_owner(game, choice)
  if afk_signal.is_timeout_eligible(owner_player) then
    afk_signal.on_timeout_fallback(game, state, owner_player.id, "target_select")
  end
end

-- 窗口该不该注册 target deadline：确认屏激活且当前 choice 可归属（无 turn 的
-- 裸结构兼容既有超时契约，choice 缺失按「无归属窗口」处理，不注册）。
local function _should_arm_target_deadline(game, state, choice_id)
  if not _is_target_select_active(state) then
    return false
  end
  if choice_id == nil and game ~= nil and game.turn ~= nil then
    return false
  end
  return true
end

-- 只结算仍归属同一 choice 的到期窗口：deadline 是在 choice 存活期注册的，
-- 其他路径清窗/换窗后 item_phase_ask 状态可能残留，不得误判为 AFK 或重复推进。
local function _resolve_target_deadline(game, state, choice_id)
  local active_choice = _pending_choice(game)
  if active_choice ~= nil then
    if active_choice.id == choice_id then
      state._target_select_timeout_choice_id = choice_id
      _notify_target_timeout(game, state, active_choice)
      deadlines.resolve_target_select(game, state, { choice = active_choice }, "tick_timeout")
    end
    return
  end
  if game == nil or game.turn == nil then
    state._target_select_timeout_choice_id = choice_id
    deadlines.resolve_target_select(game, state, { choice = nil }, "tick_timeout")
  end
end

-- 当前 choice 已有活跃 deadline 或已消费超时：是则本轮无需重新注册。
local function _has_target_deadline_for_choice(state, choice_id)
  if deadlines.is_active(state, "target_select") then
    return state._target_select_deadline_choice_id == choice_id
  end
  return choice_id ~= nil and state._target_select_timeout_choice_id == choice_id
end

-- 换窗后旧 deadline 作废：取消并清掉已消费标记，重新注册。
local function _cancel_stale_target_deadline(state)
  if deadlines.is_active(state, "target_select") then
    deadlines.cancel(state, "target_select")
    state._target_select_timeout_choice_id = nil
  end
end

local function _choice_id(game)
  local choice = _pending_choice(game)
  if choice ~= nil then
    return choice.id
  end
  return nil
end

function M.step(game, state, dt)
  if type(state) ~= "table" then
    return
  end
  local choice_id = _choice_id(game)
  if not _should_arm_target_deadline(game, state, choice_id) then
    _cancel_stale_target_deadline(state)
    state._target_select_deadline_choice_id = nil
    state._target_select_timeout_choice_id = nil
    return
  end

  if _has_target_deadline_for_choice(state, choice_id) then
    return
  end

  _cancel_stale_target_deadline(state)
  state._target_select_deadline_choice_id = choice_id
  deadlines.start(state, "target_select", {
    timeout_seconds = _resolve_target_select_timeout(),
    priority = 80,
    on_timeout = function()
      _resolve_target_deadline(game, state, choice_id)
    end,
  })
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=71c037a8b3f4255b
scope.0.id=chunk:src/turn/waits/target_select_timer.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=125
scope.0.semanticHash=dfb937f1993d6df3
scope.1.id=function:_resolve_target_select_timeout
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=19
scope.1.semanticHash=5763c53ddd1c419c
scope.2.id=function:_is_target_select_active
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=23
scope.2.semanticHash=d62e2c377e650a89
scope.3.id=function:_pending_choice
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=27
scope.3.semanticHash=c250138038aa193a
scope.4.id=function:_resolve_target_owner
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=34
scope.4.semanticHash=c572deb487071f61
scope.5.id=function:_notify_target_timeout
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=41
scope.5.semanticHash=ed3141957c28b360
scope.6.id=function:_should_arm_target_deadline
scope.6.kind=function
scope.6.startLine=45
scope.6.endLine=53
scope.6.semanticHash=8955409c57ddd2d9
scope.7.id=function:_resolve_target_deadline
scope.7.kind=function
scope.7.startLine=57
scope.7.endLine=71
scope.7.semanticHash=3831425c6d8234dd
scope.8.id=function:_has_target_deadline_for_choice
scope.8.kind=function
scope.8.startLine=74
scope.8.endLine=79
scope.8.semanticHash=c1bfe2b3c5613ce9
scope.9.id=function:_cancel_stale_target_deadline
scope.9.kind=function
scope.9.startLine=82
scope.9.endLine=87
scope.9.semanticHash=1f6b2751b87b63d5
scope.10.id=function:_choice_id
scope.10.kind=function
scope.10.startLine=89
scope.10.endLine=95
scope.10.semanticHash=ae54479fe4072615
scope.11.id=function:M.step
scope.11.kind=function
scope.11.startLine=97
scope.11.endLine=122
scope.11.semanticHash=0ffd4858235b6010
scope.12.id=function:<anonymous>
scope.12.kind=function
scope.12.startLine=118
scope.12.endLine=120
scope.12.semanticHash=4ac65c65acb92f3b
]]
