local canvas_store = require("src.ui.state.canvas_store")

local ui_gate_sync = {}
local _cached_gate = {}

local function _read_flag(ui, key)
  return ui and ui[key] == true or false
end

local function _read_value(ui, key)
  return ui and ui[key] or nil
end

local function _resolve_popup_auto_close_seconds(ui)
  local popup = ui and ui.popup_payload or nil
  return popup and popup.auto_close_seconds or nil
end

function ui_gate_sync.get_ui_state(state, common)
  return common.get_ui_state(state)
end

function ui_gate_sync.resolve_ui_gate(state, common)
  local ui = common.get_ui_state(state)
  _cached_gate.input_blocked = _read_flag(ui, "input_blocked")
  _cached_gate.choice_active = _read_flag(ui, "choice_active")
  _cached_gate.market_active = _read_flag(ui, "market_active")
  _cached_gate.popup_active = _read_flag(ui, "popup_active")
  _cached_gate.popup_seq = _read_value(ui, "popup_seq")
  _cached_gate.popup_auto_close_seconds = _resolve_popup_auto_close_seconds(ui)
  _cached_gate.popup_owner_index = _read_value(ui, "popup_owner_index")
  return _cached_gate
end

function ui_gate_sync.is_input_blocked(state, common)
  return _read_flag(common.get_ui_state(state), "input_blocked")
end

function ui_gate_sync.is_popup_active(state, common)
  return _read_flag(common.get_ui_state(state), "popup_active")
end

function ui_gate_sync.is_choice_active(state, common)
  return _read_flag(common.get_ui_state(state), "choice_active")
end

function ui_gate_sync.is_market_active(state, common)
  return _read_flag(common.get_ui_state(state), "market_active")
end

function ui_gate_sync.get_popup_owner_index(state, common)
  return _read_value(common.get_ui_state(state), "popup_owner_index")
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
version=2
projectHash=2bcc8dbd5f1ff4ae
scope.0.id=chunk:src/ui/ports/ui_sync/gate.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=70
scope.0.semanticHash=0980e77152edbb96
scope.0.lastMutatedAt=2026-05-29T14:23:21Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=1
scope.0.lastMutationKilled=1
scope.1.id=function:_read_flag:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=64c5f3c6c9f06a2e
scope.1.lastMutatedAt=2026-05-29T14:23:21Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_read_value:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=f3efd5ba51a940a3
scope.2.lastMutatedAt=2026-05-29T14:23:21Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=2
scope.2.lastMutationKilled=2
scope.3.id=function:_resolve_popup_auto_close_seconds:14
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=17
scope.3.semanticHash=7d7ddfa672bdfaab
scope.3.lastMutatedAt=2026-05-29T14:23:21Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:ui_gate_sync.get_ui_state:19
scope.4.kind=function
scope.4.startLine=19
scope.4.endLine=21
scope.4.semanticHash=e82d4f682d6075ee
scope.4.lastMutatedAt=2026-05-29T14:23:21Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:ui_gate_sync.resolve_ui_gate:23
scope.5.kind=function
scope.5.startLine=23
scope.5.endLine=33
scope.5.semanticHash=0734f601d733ff68
scope.5.lastMutatedAt=2026-05-29T14:23:21Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=8
scope.5.lastMutationKilled=8
scope.6.id=function:ui_gate_sync.is_input_blocked:35
scope.6.kind=function
scope.6.startLine=35
scope.6.endLine=37
scope.6.semanticHash=ba905bbe6c07d3c9
scope.6.lastMutatedAt=2026-05-29T14:23:21Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:ui_gate_sync.is_popup_active:39
scope.7.kind=function
scope.7.startLine=39
scope.7.endLine=41
scope.7.semanticHash=873c9c1cb9af7d85
scope.7.lastMutatedAt=2026-05-29T14:23:21Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:ui_gate_sync.is_choice_active:43
scope.8.kind=function
scope.8.startLine=43
scope.8.endLine=45
scope.8.semanticHash=fabba1bcac2ca31d
scope.8.lastMutatedAt=2026-05-29T14:23:21Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:ui_gate_sync.is_market_active:47
scope.9.kind=function
scope.9.startLine=47
scope.9.endLine=49
scope.9.semanticHash=46850458c6e22c9d
scope.9.lastMutatedAt=2026-05-29T14:23:21Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=1
scope.10.id=function:ui_gate_sync.get_popup_owner_index:51
scope.10.kind=function
scope.10.startLine=51
scope.10.endLine=53
scope.10.semanticHash=0e5e053370c635b8
scope.10.lastMutatedAt=2026-05-29T14:23:21Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=1
scope.10.lastMutationKilled=1
scope.11.id=function:anonymous@63:63
scope.11.kind=function
scope.11.startLine=63
scope.11.endLine=65
scope.11.semanticHash=27a859dc2015644f
scope.11.lastMutatedAt=2026-05-29T14:23:21Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=no_sites
scope.11.lastMutationSites=0
scope.11.lastMutationKilled=0
scope.12.id=function:ui_gate_sync.set_input_blocked:55
scope.12.kind=function
scope.12.startLine=55
scope.12.endLine=67
scope.12.semanticHash=c70385bd9c8761d1
scope.12.lastMutatedAt=2026-05-29T14:23:21Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=7
scope.12.lastMutationKilled=7
]]
