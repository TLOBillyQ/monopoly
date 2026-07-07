local debug_flags = require("src.config.gameplay.debug_flags")
local with_client_role = require("src.ui.utils.with_client_role")
local event_log = require("src.state.event_log")
local ui_event_state = require("src.ui.coord.event_state")
local runtime = require("src.ui.render.runtime_ui")
local role_id_utils = require("src.foundation.identity")
local ui_view = require("src.ui.coord.ui_runtime")

local event_log_ports = {}

local function _resolve_event_text(game, max_lines)
  if game and game.state and game.state.event_log then
    return event_log.get_text(game.state.event_log, max_lines) or ""
  end
  return ""
end

local _sel_state
local _sel_role
local _sel_role_id

local function _apply_enabled_change(state, role, role_id, event_log_enabled)
  role_id_utils.write(state._debug_log_enabled_by_role, role_id, event_log_enabled)
  ui_view.set_event_log_visible_for_role(state, role, event_log_enabled)
  if event_log_enabled then
    role_id_utils.write(state._debug_log_seq_by_role, role_id, nil)
  else
    ui_view.set_event_log_for_role(state, role, "")
  end
end

local function _read_current_seq(state)
  if state and state.game and state.game.state and state.game.state.event_log then
    return event_log.get_seq(state.game.state.event_log)
  end
  return 0
end

local function _sync_event_content(state, role, role_id)
  local seq = _read_current_seq(state)
  if seq ~= role_id_utils.read(state._debug_log_seq_by_role, role_id) then
    role_id_utils.write(state._debug_log_seq_by_role, role_id, seq)
    local max_lines = debug_flags.debug_log_max_lines or 50
    ui_view.set_event_log_for_role(state, role, _resolve_event_text(state and state.game, max_lines))
  end
end

local function _sync_event_log_inner()
  local state = _sel_state
  local role_id = _sel_role_id
  local role = _sel_role
  local event_log_enabled = ui_event_state.resolve_event_log_enabled(state, role_id)
  if role_id_utils.read(state._debug_log_enabled_by_role, role_id) ~= event_log_enabled then
    _apply_enabled_change(state, role, role_id, event_log_enabled)
  end
  if event_log_enabled then
    _sync_event_content(state, role, role_id)
  end
end

local function _sync_event_log_outer(role)
  local role_id = role_id_utils.normalize(runtime.resolve_role_id(role))
  if role_id == nil then
    return
  end
  _sel_role = role
  _sel_role_id = role_id
  with_client_role(runtime, role, _sync_event_log_inner)
end

function event_log_ports.build(common)
  return {
    log_status = function(view)
      common.log_status(view)
    end,
    sync_event_log = function(state)
      state._debug_log_enabled_by_role = state._debug_log_enabled_by_role or {}
      state._debug_log_seq_by_role = state._debug_log_seq_by_role or {}
      _sel_state = state
      runtime.for_each_role_or_global(_sync_event_log_outer)
      runtime.set_client_role(nil)
    end,
    resolve_event_log_enabled = function(state, role_id)
      return ui_event_state.resolve_event_log_enabled(state, role_id)
    end,
  }
end

return event_log_ports

--[[ mutate4lua-manifest
version=2
projectHash=b0e5f78ab9750cc1
scope.0.id=chunk:src/ui/ports/event_log.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=90
scope.0.semanticHash=64413b5fe86ed3f1
scope.1.id=function:_resolve_event_text:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=16
scope.1.semanticHash=aee3c64d64b2620a
scope.2.id=function:_apply_enabled_change:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=30
scope.2.semanticHash=fb1bcf027a9aee62
scope.3.id=function:_read_current_seq:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=37
scope.3.semanticHash=e8d89a91f35eac5f
scope.4.id=function:_sync_event_content:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=46
scope.4.semanticHash=ad17573dc0dad285
scope.5.id=function:_sync_event_log_inner:48
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=59
scope.5.semanticHash=b2e09fef0ee50e37
scope.6.id=function:_sync_event_log_outer:61
scope.6.kind=function
scope.6.startLine=61
scope.6.endLine=69
scope.6.semanticHash=ab0ff1f6b7d803e4
scope.7.id=function:anonymous@73:73
scope.7.kind=function
scope.7.startLine=73
scope.7.endLine=75
scope.7.semanticHash=84923318e578a190
scope.8.id=function:anonymous@76:76
scope.8.kind=function
scope.8.startLine=76
scope.8.endLine=82
scope.8.semanticHash=9ea98170e326b70f
scope.9.id=function:anonymous@83:83
scope.9.kind=function
scope.9.startLine=83
scope.9.endLine=85
scope.9.semanticHash=ecaef25e2cbb9f5f
scope.10.id=function:event_log_ports.build:71
scope.10.kind=function
scope.10.startLine=71
scope.10.endLine=87
scope.10.semanticHash=08ddeb3f54ebbab0
]]
