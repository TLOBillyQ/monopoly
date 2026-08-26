-- 待决选择超时模块(#602):自包含不变接线——端口组解析、deadline 服务、
-- resolve/force_skip 由模块内部自持,不再占据构造 interface;外壳 timeout.lua
-- 整体退役。构造键只留真实变化点(7 个);resolve_choice_ui_state 提升为显式
-- 必需键,不再是契约外静默穿透。
-- 内部拆分(refactorer 收尾):tick 引擎在 choice_timeout_engine,deadline 簿记
-- 在 choice_timeout_tracking,时长解析在 choice_timeout_duration;本文件保持
-- ChoiceTimeout 公共面(new / resolve_choice_timeout_seconds / step_default)
-- 与默认装配,调用方不变。
local engine = require("src.turn.waits.choice_timeout_engine")
local duration = require("src.turn.waits.choice_timeout_duration")
local timing = require("src.config.gameplay.timing")
local runtime_state = require("src.state.runtime")
local resolve_port = require("src.turn.output.resolve_port")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local modal_timeout = require("src.turn.waits.modal_timeout")

local ChoiceTimeout = {}

ChoiceTimeout.new = engine.new
ChoiceTimeout.resolve_choice_timeout_seconds = duration.resolve_choice_timeout_seconds

-- modal 端口只参与一件事:超时自动代答派发时挂 on_close_choice,让真实选择
-- 弹窗随裁定收屏(「超时收屏」验收场景)。这是选择超时对 modal 的唯一接线,
-- 评估结论见 docs/decisions.md #602 条。
local _dispatch_close_opts = { on_close_choice = nil }
local _cached_dispatch_modal_ref = nil
local function _dispatch_action_with_close_choice(game, state, action)
  local modal_ports = modal_timeout.resolve_modal_ports(state)
  if not modal_ports then
    return turn_dispatch.dispatch_action(game, state, action, nil)
  end
  if _cached_dispatch_modal_ref ~= modal_ports then
    _cached_dispatch_modal_ref = modal_ports
    _dispatch_close_opts.on_close_choice = function(ctx)
      modal_ports.close_choice_modal(ctx)
    end
  end
  return turn_dispatch.dispatch_action(game, state, action, _dispatch_close_opts)
end

local function _resolve_ui_sync_ports(state)
  return resolve_port.resolve(state, "ui_sync", nil)
end

-- 默认装配(自 timeout.lua 迁入,行为保持):生产与测试不再各自拼写同一份
-- 不变接线;装配方(loop 端口)直接用 step_default,定制方走 ChoiceTimeout.new。
local _choice_ui_fallback = {}

local _default_dependencies = {
  build_action = function(game_ctx, state_ctx, choice, action_ctx)
    return choice_auto_policy.decide(game_ctx, state_ctx, choice, action_ctx)
  end,
  dispatch_action_with_close_choice = _dispatch_action_with_close_choice,
  get_timeout_seconds = function(game, state)
    return ChoiceTimeout.resolve_choice_timeout_seconds(game, state)
  end,
  get_min_visible_seconds = function()
    return timing.auto_decision_delay_seconds or 0
  end,
}

_default_dependencies.on_pending_choice = function(game, state, pending)
  local ports = _resolve_ui_sync_ports(state)
  if ports and type(ports.on_pending_choice) == "function" then
    return ports.on_pending_choice(game, state, pending)
  end
end

_default_dependencies.is_choice_active = function(state)
  local ports = _resolve_ui_sync_ports(state)
  if ports and type(ports.is_choice_active) == "function" then
    return ports.is_choice_active(state)
  end
  return runtime_state.get_pending_choice(state) ~= nil
end

_default_dependencies.resolve_choice_ui_state = function(game, state, choice)
  local ports = _resolve_ui_sync_ports(state)
  if ports and type(ports.resolve_choice_ui_state) == "function" then
    return ports.resolve_choice_ui_state(game, state, choice)
  end
  _choice_ui_fallback.route_key = choice and choice.route_key or nil
  _choice_ui_fallback.should_warn = false
  return _choice_ui_fallback
end

local _default_choice_timeout = ChoiceTimeout.new(_default_dependencies)

function ChoiceTimeout.step_default(game, state, dt)
  return _default_choice_timeout.step(game, state, dt)
end

return ChoiceTimeout

--[[ mutate4lua-manifest
version=4
projectHash=06cb8cc164a7dcc6
scope.0.id=chunk:src/turn/waits/choice_timeout.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=95
scope.0.semanticHash=d5deeb2933b5cefb
scope.1.id=function:_dispatch_action_with_close_choice
scope.1.kind=function
scope.1.startLine=28
scope.1.endLine=40
scope.1.semanticHash=73fbd269c2db68dc
scope.2.id=function:_dispatch_close_opts.on_close_choice
scope.2.kind=function
scope.2.startLine=35
scope.2.endLine=37
scope.2.semanticHash=c772a22f8680e278
scope.3.id=function:_resolve_ui_sync_ports
scope.3.kind=function
scope.3.startLine=42
scope.3.endLine=44
scope.3.semanticHash=4368ca26832c9549
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=53
scope.4.semanticHash=360776c78d632b1f
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=55
scope.5.endLine=57
scope.5.semanticHash=aba9250a8c6b104f
scope.6.id=function:<anonymous>#3
scope.6.kind=function
scope.6.startLine=58
scope.6.endLine=60
scope.6.semanticHash=30522eb92944bea7
scope.7.id=function:_default_dependencies.on_pending_choice
scope.7.kind=function
scope.7.startLine=63
scope.7.endLine=68
scope.7.semanticHash=85c5dcd9d5e882b2
scope.8.id=function:_default_dependencies.is_choice_active
scope.8.kind=function
scope.8.startLine=70
scope.8.endLine=76
scope.8.semanticHash=1e2a45ff9a5613ee
scope.9.id=function:_default_dependencies.resolve_choice_ui_state
scope.9.kind=function
scope.9.startLine=78
scope.9.endLine=86
scope.9.semanticHash=5a040268cd6fbc8e
scope.10.id=function:ChoiceTimeout.step_default
scope.10.kind=function
scope.10.startLine=90
scope.10.endLine=92
scope.10.semanticHash=d590c542c8c308c5
]]
