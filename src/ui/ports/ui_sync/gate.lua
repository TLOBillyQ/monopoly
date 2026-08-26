local canvas_store = require("src.ui.state.canvas_store")

local ui_gate_sync = {}
local _cached_gate = {}
local _query_gate = {}

-- 布尔门控键统一走「非 true 即 false」，缺 ui 时也必须落 false 而非 nil。
local function _read_flag(ui, key)
  return ui and ui[key] == true or false
end

-- 透传键：缺 ui 时为 nil，不做布尔归一。
local function _read_value(ui, key)
  return ui and ui[key] or nil
end

local function _resolve_popup_auto_close_seconds(ui)
  local popup = ui and ui.popup_payload or nil
  return popup and popup.auto_close_seconds or nil
end

-- gate 值对象：门控语义（input_blocked / choice_active / market_active /
-- popup_active / popup_seq / popup_auto_close_seconds / popup_owner_index）。
-- 「哪些 state.ui.* 键决定这些语义」的映射只存在于 snapshot 一处。
function ui_gate_sync.snapshot(ui, out)
  local gate = out or {}
  gate.input_blocked = _read_flag(ui, "input_blocked")
  gate.choice_active = _read_flag(ui, "choice_active")
  gate.market_active = _read_flag(ui, "market_active")
  gate.popup_active = _read_flag(ui, "popup_active")
  gate.popup_seq = _read_value(ui, "popup_seq")
  gate.popup_auto_close_seconds = _resolve_popup_auto_close_seconds(ui)
  gate.popup_owner_index = _read_value(ui, "popup_owner_index")
  return gate
end

local function _query(state, common)
  return ui_gate_sync.snapshot(common.get_ui_state(state), _query_gate)
end

function ui_gate_sync.get_ui_state(state, common)
  return common.get_ui_state(state)
end

-- 契约：为省 GC，resolve_ui_gate 复用模块级单例快照——返回的 gate 表
-- 仅在下一次 resolve_ui_gate 调用前有效，后一次调用会就地改写同一张表。
-- 调用方不得跨 resolve 持有该 gate、也不得比较两次 resolve 的返回值；
-- 需要自持副本时用 snapshot(ui)（不传 out，每次返回全新表）。
function ui_gate_sync.resolve_ui_gate(state, common)
  return ui_gate_sync.snapshot(common.get_ui_state(state), _cached_gate)
end

function ui_gate_sync.is_input_blocked(state, common)
  return _query(state, common).input_blocked
end

function ui_gate_sync.is_popup_active(state, common)
  return _query(state, common).popup_active
end

function ui_gate_sync.is_choice_active(state, common)
  return _query(state, common).choice_active
end

function ui_gate_sync.get_popup_owner_index(state, common)
  return _query(state, common).popup_owner_index
end

function ui_gate_sync.set_input_blocked(state, blocked, common)
  local ui = common.get_ui_state(state)
  if not ui then
    return false
  end
  if ui.input_blocked == blocked then
    return false
  end
  canvas_store.patch_slice(state, "base", function()
    ui.input_blocked = blocked
  end)
  return true
end

return ui_gate_sync

--[[ mutate4lua-manifest
version=4
projectHash=3fd12cee245c8cc2
scope.0.id=chunk:src/ui/ports/ui_sync/gate.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=84
scope.0.semanticHash=58efd1b480966de0
scope.1.id=function:_read_flag
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=e57dbd55a7ba0b36
scope.2.id=function:_read_value
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=15
scope.2.semanticHash=cd6b189045fad21d
scope.3.id=function:_resolve_popup_auto_close_seconds
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=20
scope.3.semanticHash=93c839897afe61e5
scope.4.id=function:ui_gate_sync.snapshot
scope.4.kind=function
scope.4.startLine=25
scope.4.endLine=35
scope.4.semanticHash=1395470c0760437f
scope.5.id=function:_query
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=39
scope.5.semanticHash=f646e505d37549c9
scope.6.id=function:ui_gate_sync.get_ui_state
scope.6.kind=function
scope.6.startLine=41
scope.6.endLine=43
scope.6.semanticHash=67a06b9f43804ce2
scope.7.id=function:ui_gate_sync.resolve_ui_gate
scope.7.kind=function
scope.7.startLine=49
scope.7.endLine=51
scope.7.semanticHash=f646e505d37549c9
scope.8.id=function:ui_gate_sync.is_input_blocked
scope.8.kind=function
scope.8.startLine=53
scope.8.endLine=55
scope.8.semanticHash=6a5bce7fdbfbeee2
scope.9.id=function:ui_gate_sync.is_popup_active
scope.9.kind=function
scope.9.startLine=57
scope.9.endLine=59
scope.9.semanticHash=6a5bce7fdbfbeee2
scope.10.id=function:ui_gate_sync.is_choice_active
scope.10.kind=function
scope.10.startLine=61
scope.10.endLine=63
scope.10.semanticHash=6a5bce7fdbfbeee2
scope.11.id=function:ui_gate_sync.get_popup_owner_index
scope.11.kind=function
scope.11.startLine=65
scope.11.endLine=67
scope.11.semanticHash=6a5bce7fdbfbeee2
scope.12.id=function:ui_gate_sync.set_input_blocked
scope.12.kind=function
scope.12.startLine=69
scope.12.endLine=81
scope.12.semanticHash=5c8ecf4368eb01e0
scope.13.id=function:<anonymous>
scope.13.kind=function
scope.13.startLine=77
scope.13.endLine=79
scope.13.semanticHash=15e02bb16069d0a4
]]
