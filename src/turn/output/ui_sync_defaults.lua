local M = {}

-- turn 层不认识 UI 状态里的门控键名：门控语义一律经 ui_sync 端口的
-- resolve_ui_gate（gate 值对象，见 src/ui/ports/ui_sync/gate.lua）获取。
--
-- 显式契约（gameplay_loop_ports.resolve(nil) 或 ui_sync 组部分覆盖时生效）：
-- * 默认 resolve_ui_gate 不读 state.ui，恒返回全关的惰性 gate；
-- * 默认 set_input_blocked 惰性：不落写 UI 输入锁标志，恒返回 false；
-- * 需要真实门控（读或写）的调用方必须在 ui_sync 组注入
--   resolve_ui_gate / set_input_blocked（生产链路由 presentation 端口提供，
--   见 src/ui/ports/ui_sync.lua）。
-- 防静默降级：override 组提供了任一门控查询/落写键却缺 resolve_ui_gate 时，
-- fill_ui_sync_defaults 直接报错（见 _assert_gate_overrides_consistent）。
local _inert_gate = {
  input_blocked = false,
  choice_active = false,
  market_active = false,
  popup_active = false,
  popup_seq = nil,
  popup_auto_close_seconds = nil,
  popup_owner_index = nil,
}

local function _resolve_inert_gate()
  return _inert_gate
end

local function _lazy_step(load_module, step_method)
  return function(game, state, dt)
    local mod = load_module()
    mod[step_method](game, state, dt)
  end
end

-- #602 外壳退役:选择/弹层超时步进分别直读 choice_timeout 与 modal_timeout
-- 两个本源模块,不再经过外壳 loader。
function M.build_base_ui_sync_ports(load_choice_timeout, load_tick_ui_sync, load_modal_timeout)
  return {
    apply_input_lock = function() end,
    step_choice_timeout = _lazy_step(load_choice_timeout, "step_default"),
    step_modal_timeout = _lazy_step(load_modal_timeout, "step_default"),
    update_countdown = function(game, state)
      local tick_ui_sync = load_tick_ui_sync()
      tick_ui_sync.update_countdown(game, state)
    end,
    resolve_ui_gate = _resolve_inert_gate,
    build_model = function() return {} end,
    refresh_from_dirty = function() return false end,
    follow_camera = function() return false end,
    sync_camera_position = function() return false end,
    get_ui_state = function() return nil end,
    is_input_blocked = function() return false end,
    is_popup_active = function() return false end,
    is_choice_active = function() return false end,
    get_popup_owner_index = function() return nil end,
    set_input_blocked = function() return false end,
    probe_choice_ui_missing = function() end,
  }
end

local function _default_get_ui_state(state)
  return state and state.ui or nil
end

local function _default_gate_flag(field)
  return function(ui_sync_ports)
    return function(state)
      return ui_sync_ports.resolve_ui_gate(state)[field] == true
    end
  end
end

local function _default_gate_value(field)
  return function(ui_sync_ports)
    return function(state)
      return ui_sync_ports.resolve_ui_gate(state)[field]
    end
  end
end

local function _default_set_input_blocked()
  return function()
    return false
  end
end

-- fill 生成的默认实现集合（弱键）：loop 会把已解析端口组写回
-- state.gameplay_loop_ports 并在下个 tick 重新 resolve，这些派生默认
-- 不算「调用方 override」，防静默降级校验不得对其误报。
local _derived_defaults = setmetatable({}, { __mode = "k" })

local function _fill_default(ui_sync_ports, base_ui_sync_ports, key, resolver)
  if ui_sync_ports[key] == nil or ui_sync_ports[key] == base_ui_sync_ports[key] then
    local fn = resolver(ui_sync_ports)
    _derived_defaults[fn] = true
    ui_sync_ports[key] = fn
  end
end

local function _build_ui_sync_specs()
  return {
    { key = "get_ui_state", resolver = function() return _default_get_ui_state end },
    { key = "resolve_ui_gate", resolver = function() return _resolve_inert_gate end },
    { key = "is_input_blocked", resolver = _default_gate_flag("input_blocked") },
    { key = "is_popup_active", resolver = _default_gate_flag("popup_active") },
    { key = "is_choice_active", resolver = _default_gate_flag("choice_active") },
    { key = "get_popup_owner_index", resolver = _default_gate_value("popup_owner_index") },
    { key = "set_input_blocked", resolver = _default_set_input_blocked },
  }
end

local function _apply_ui_sync_defaults(ui_sync_ports, base_ui_sync_ports, specs)
  for _, spec in ipairs(specs) do
    _fill_default(ui_sync_ports, base_ui_sync_ports, spec.key, spec.resolver)
  end
end

-- 依赖 gate 语义的查询/落写键：override 提供了其中任意一个却缺 resolve_ui_gate
-- 时，resolve_ui_gate 会静默回退惰性 gate，与真实查询产生不一致信号，故直接报错。
local _gate_dependent_keys = {
  "is_input_blocked",
  "is_popup_active",
  "is_choice_active",
  "get_popup_owner_index",
  "set_input_blocked",
}

local function _is_overridden(ui_sync_ports, base_ui_sync_ports, key)
  local fn = ui_sync_ports[key]
  return fn ~= nil and fn ~= base_ui_sync_ports[key] and not _derived_defaults[fn]
end

local function _assert_gate_overrides_consistent(ui_sync_ports, base_ui_sync_ports)
  if _is_overridden(ui_sync_ports, base_ui_sync_ports, "resolve_ui_gate") then
    return
  end
  for _, key in ipairs(_gate_dependent_keys) do
    if _is_overridden(ui_sync_ports, base_ui_sync_ports, key) then
      error("ui_sync override provides " .. key
        .. " but lacks resolve_ui_gate; default resolve_ui_gate is inert (never reads state.ui)"
        .. " -- provide resolve_ui_gate to keep gate signals consistent")
    end
  end
end

local _ui_sync_specs = _build_ui_sync_specs()

function M.fill_ui_sync_defaults(ui_sync_ports, base_ui_sync_ports)
  _assert_gate_overrides_consistent(ui_sync_ports, base_ui_sync_ports)
  _apply_ui_sync_defaults(ui_sync_ports, base_ui_sync_ports, _ui_sync_specs)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=4b48e888ba017b36
scope.0.id=chunk:src/turn/output/ui_sync_defaults.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=154
scope.0.semanticHash=5c7a85afd4831430
scope.1.id=function:_resolve_inert_gate
scope.1.kind=function
scope.1.startLine=24
scope.1.endLine=26
scope.1.semanticHash=1136505bd37c301e
scope.2.id=function:_lazy_step
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=33
scope.2.semanticHash=42901805dc17be21
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=32
scope.3.semanticHash=6715812b412e461f
scope.4.id=function:M.build_base_ui_sync_ports
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=59
scope.4.semanticHash=17e3740da7f2ae5a
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=39
scope.5.semanticHash=f5774b2783966d88
scope.6.id=function:<anonymous>#3
scope.6.kind=function
scope.6.startLine=42
scope.6.endLine=45
scope.6.semanticHash=aee5f81389f04349
scope.7.id=function:<anonymous>#4
scope.7.kind=function
scope.7.startLine=47
scope.7.endLine=47
scope.7.semanticHash=bbb529d084641ee0
scope.8.id=function:<anonymous>#5
scope.8.kind=function
scope.8.startLine=48
scope.8.endLine=48
scope.8.semanticHash=22b57f529f3a8828
scope.9.id=function:<anonymous>#6
scope.9.kind=function
scope.9.startLine=49
scope.9.endLine=49
scope.9.semanticHash=22b57f529f3a8828
scope.10.id=function:<anonymous>#7
scope.10.kind=function
scope.10.startLine=50
scope.10.endLine=50
scope.10.semanticHash=22b57f529f3a8828
scope.11.id=function:<anonymous>#8
scope.11.kind=function
scope.11.startLine=51
scope.11.endLine=51
scope.11.semanticHash=d654da5e94a5e3f3
scope.12.id=function:<anonymous>#9
scope.12.kind=function
scope.12.startLine=52
scope.12.endLine=52
scope.12.semanticHash=22b57f529f3a8828
scope.13.id=function:<anonymous>#10
scope.13.kind=function
scope.13.startLine=53
scope.13.endLine=53
scope.13.semanticHash=22b57f529f3a8828
scope.14.id=function:<anonymous>#11
scope.14.kind=function
scope.14.startLine=54
scope.14.endLine=54
scope.14.semanticHash=22b57f529f3a8828
scope.15.id=function:<anonymous>#12
scope.15.kind=function
scope.15.startLine=55
scope.15.endLine=55
scope.15.semanticHash=d654da5e94a5e3f3
scope.16.id=function:<anonymous>#13
scope.16.kind=function
scope.16.startLine=56
scope.16.endLine=56
scope.16.semanticHash=22b57f529f3a8828
scope.17.id=function:<anonymous>#14
scope.17.kind=function
scope.17.startLine=57
scope.17.endLine=57
scope.17.semanticHash=f5774b2783966d88
scope.18.id=function:_default_get_ui_state
scope.18.kind=function
scope.18.startLine=61
scope.18.endLine=63
scope.18.semanticHash=616a2ca60599c94f
scope.19.id=function:_default_gate_flag
scope.19.kind=function
scope.19.startLine=65
scope.19.endLine=71
scope.19.semanticHash=02c97ecc9f36518f
scope.20.id=function:<anonymous>#15
scope.20.kind=function
scope.20.startLine=66
scope.20.endLine=70
scope.20.semanticHash=5ff72868f0dfc83e
scope.21.id=function:<anonymous>#16
scope.21.kind=function
scope.21.startLine=67
scope.21.endLine=69
scope.21.semanticHash=7e6539c509e8e469
scope.22.id=function:_default_gate_value
scope.22.kind=function
scope.22.startLine=73
scope.22.endLine=79
scope.22.semanticHash=744b6480196cea01
scope.23.id=function:<anonymous>#17
scope.23.kind=function
scope.23.startLine=74
scope.23.endLine=78
scope.23.semanticHash=1943198edea1ad94
scope.24.id=function:<anonymous>#18
scope.24.kind=function
scope.24.startLine=75
scope.24.endLine=77
scope.24.semanticHash=e83acb507c787eab
scope.25.id=function:_default_set_input_blocked
scope.25.kind=function
scope.25.startLine=81
scope.25.endLine=85
scope.25.semanticHash=0fdfd5eddd18b676
scope.26.id=function:<anonymous>#19
scope.26.kind=function
scope.26.startLine=82
scope.26.endLine=84
scope.26.semanticHash=22b57f529f3a8828
scope.27.id=function:_fill_default
scope.27.kind=function
scope.27.startLine=92
scope.27.endLine=98
scope.27.semanticHash=41c2099cea912158
scope.28.id=function:_build_ui_sync_specs
scope.28.kind=function
scope.28.startLine=100
scope.28.endLine=110
scope.28.semanticHash=9f2ad6d5ece4506a
scope.29.id=function:<anonymous>#20
scope.29.kind=function
scope.29.startLine=102
scope.29.endLine=102
scope.29.semanticHash=1136505bd37c301e
scope.30.id=function:<anonymous>#21
scope.30.kind=function
scope.30.startLine=103
scope.30.endLine=103
scope.30.semanticHash=1136505bd37c301e
scope.31.id=function:_apply_ui_sync_defaults
scope.31.kind=function
scope.31.startLine=112
scope.31.endLine=116
scope.31.semanticHash=cd1d10ebef1f411a
scope.32.id=function:_is_overridden
scope.32.kind=function
scope.32.startLine=128
scope.32.endLine=131
scope.32.semanticHash=35324bf49905c40c
scope.33.id=function:_assert_gate_overrides_consistent
scope.33.kind=function
scope.33.startLine=133
scope.33.endLine=144
scope.33.semanticHash=d02c968133f41fbb
scope.34.id=function:M.fill_ui_sync_defaults
scope.34.kind=function
scope.34.startLine=148
scope.34.endLine=151
scope.34.semanticHash=8bd6c77e764223b1
]]
