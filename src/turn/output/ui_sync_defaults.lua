local M = {}

-- turn 层不认识 UI 状态里的门控键名：门控语义一律经 ui_sync 端口的
-- resolve_ui_gate（gate 值对象，见 src/ui/ports/ui_sync/gate.lua）获取；
-- 端口缺失时回退到全关的惰性 gate。
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

local function _tick_timeout_step(load_tick_timeout, step_method)
  return function(game, state, dt)
    local tick_timeout = load_tick_timeout()
    tick_timeout[step_method](game, state, dt)
  end
end

function M.build_base_ui_sync_ports(load_tick_timeout, load_tick_ui_sync)
  return {
    apply_input_lock = function() end,
    step_choice_timeout = _tick_timeout_step(load_tick_timeout, "step_default_choice"),
    step_modal_timeout = _tick_timeout_step(load_tick_timeout, "step_default_modal"),
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

local function _fill_default(ui_sync_ports, base_ui_sync_ports, key, resolver)
  if ui_sync_ports[key] == nil or ui_sync_ports[key] == base_ui_sync_ports[key] then
    ui_sync_ports[key] = resolver(ui_sync_ports)
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

local _ui_sync_specs = _build_ui_sync_specs()

function M.fill_ui_sync_defaults(ui_sync_ports, base_ui_sync_ports)
  _apply_ui_sync_defaults(ui_sync_ports, base_ui_sync_ports, _ui_sync_specs)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=57d96d32ac410d7f
scope.0.id=chunk:src/turn/output/ui_sync_defaults.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=138
scope.0.semanticHash=79dfc6336f345a39
scope.1.id=function:_bool_field:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=7d27f6d5a5207b23
scope.2.id=function:_opt_field:7
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=9
scope.2.semanticHash=b2cdcb2b46bbb898
scope.3.id=function:_build_ui_gate:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=30
scope.3.semanticHash=6c88f6d0715c7618
scope.4.id=function:_resolve_ui_gate_from_state:32
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=36
scope.4.semanticHash=630e05f25b84c5c9
scope.5.id=function:anonymous@39:39
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=42
scope.5.semanticHash=23be3b826abd0741
scope.6.id=function:_tick_timeout_step:38
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=43
scope.6.semanticHash=26f7d77dfdb8a3a2
scope.7.id=function:anonymous@47:47
scope.7.kind=function
scope.7.startLine=47
scope.7.endLine=47
scope.7.semanticHash=b53995942fd14a6f
scope.8.id=function:anonymous@50:50
scope.8.kind=function
scope.8.startLine=50
scope.8.endLine=53
scope.8.semanticHash=cc804b7081d4fe2d
scope.9.id=function:anonymous@55:55
scope.9.kind=function
scope.9.startLine=55
scope.9.endLine=55
scope.9.semanticHash=702fe5f9c3314e07
scope.10.id=function:anonymous@56:56
scope.10.kind=function
scope.10.startLine=56
scope.10.endLine=56
scope.10.semanticHash=c168b2cdb12a737a
scope.11.id=function:anonymous@57:57
scope.11.kind=function
scope.11.startLine=57
scope.11.endLine=57
scope.11.semanticHash=c168b2cdb12a737a
scope.12.id=function:anonymous@58:58
scope.12.kind=function
scope.12.startLine=58
scope.12.endLine=58
scope.12.semanticHash=c168b2cdb12a737a
scope.13.id=function:anonymous@59:59
scope.13.kind=function
scope.13.startLine=59
scope.13.endLine=59
scope.13.semanticHash=d8269153568043a6
scope.14.id=function:anonymous@60:60
scope.14.kind=function
scope.14.startLine=60
scope.14.endLine=60
scope.14.semanticHash=c168b2cdb12a737a
scope.15.id=function:anonymous@61:61
scope.15.kind=function
scope.15.startLine=61
scope.15.endLine=61
scope.15.semanticHash=c168b2cdb12a737a
scope.16.id=function:anonymous@62:62
scope.16.kind=function
scope.16.startLine=62
scope.16.endLine=62
scope.16.semanticHash=c168b2cdb12a737a
scope.17.id=function:anonymous@63:63
scope.17.kind=function
scope.17.startLine=63
scope.17.endLine=63
scope.17.semanticHash=c168b2cdb12a737a
scope.18.id=function:anonymous@64:64
scope.18.kind=function
scope.18.startLine=64
scope.18.endLine=64
scope.18.semanticHash=d8269153568043a6
scope.19.id=function:anonymous@65:65
scope.19.kind=function
scope.19.startLine=65
scope.19.endLine=65
scope.19.semanticHash=c168b2cdb12a737a
scope.20.id=function:M.build_base_ui_sync_ports:45
scope.20.kind=function
scope.20.startLine=45
scope.20.endLine=67
scope.20.semanticHash=21aa9b869110bc8e
scope.21.id=function:_default_get_ui_state:69
scope.21.kind=function
scope.21.startLine=69
scope.21.endLine=71
scope.21.semanticHash=af966889f53ea657
scope.22.id=function:anonymous@75:75
scope.22.kind=function
scope.22.startLine=75
scope.22.endLine=77
scope.22.semanticHash=335029cbf302aeef
scope.23.id=function:anonymous@74:74
scope.23.kind=function
scope.23.startLine=74
scope.23.endLine=78
scope.23.semanticHash=0daa1785d91606b8
scope.24.id=function:_default_ui_field:73
scope.24.kind=function
scope.24.startLine=73
scope.24.endLine=79
scope.24.semanticHash=98a02818db5107aa
scope.25.id=function:anonymous@85:85
scope.25.kind=function
scope.25.startLine=85
scope.25.endLine=95
scope.25.semanticHash=c6df20727642ee3e
scope.26.id=function:_default_set_input_blocked:84
scope.26.kind=function
scope.26.startLine=84
scope.26.endLine=96
scope.26.semanticHash=93fa329cba53b3a6
scope.27.id=function:anonymous@99:99
scope.27.kind=function
scope.27.startLine=99
scope.27.endLine=103
scope.27.semanticHash=a3d5250c6c1905d1
scope.28.id=function:_default_resolve_ui_gate:98
scope.28.kind=function
scope.28.startLine=98
scope.28.endLine=104
scope.28.semanticHash=788726c8cb8c0d12
scope.29.id=function:_fill_default:106
scope.29.kind=function
scope.29.startLine=106
scope.29.endLine=110
scope.29.semanticHash=4963e98c1886d94e
scope.30.id=function:anonymous@114:114
scope.30.kind=function
scope.30.startLine=114
scope.30.endLine=114
scope.30.semanticHash=bd452c6e51eb170b
scope.31.id=function:anonymous@115:115
scope.31.kind=function
scope.31.startLine=115
scope.31.endLine=115
scope.31.semanticHash=c43b4c7809000d39
scope.32.id=function:anonymous@116:116
scope.32.kind=function
scope.32.startLine=116
scope.32.endLine=116
scope.32.semanticHash=a6c6d2c0c3a932b7
scope.33.id=function:anonymous@117:117
scope.33.kind=function
scope.33.startLine=117
scope.33.endLine=117
scope.33.semanticHash=0a8cc872da96fa52
scope.34.id=function:anonymous@118:118
scope.34.kind=function
scope.34.startLine=118
scope.34.endLine=118
scope.34.semanticHash=bdb0f57de41eff91
scope.35.id=function:anonymous@119:119
scope.35.kind=function
scope.35.startLine=119
scope.35.endLine=119
scope.35.semanticHash=2c69db33ce44435a
scope.36.id=function:_build_ui_sync_specs:112
scope.36.kind=function
scope.36.startLine=112
scope.36.endLine=123
scope.36.semanticHash=faeefec481cf51b0
scope.37.id=function:M.fill_ui_sync_defaults:133
scope.37.kind=function
scope.37.startLine=133
scope.37.endLine=135
scope.37.semanticHash=204896c21523dc31
]]
