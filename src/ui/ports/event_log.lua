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

local function _sync_event_log_inner()
  local state = _sel_state
  local role_id = _sel_role_id
  local role = _sel_role
  local event_log_enabled = ui_event_state.resolve_event_log_enabled(state, role_id)
  if role_id_utils.read(state._debug_log_enabled_by_role, role_id) ~= event_log_enabled then
    role_id_utils.write(state._debug_log_enabled_by_role, role_id, event_log_enabled)
    ui_view.set_event_log_visible_for_role(state, role, event_log_enabled)
    if event_log_enabled then
      role_id_utils.write(state._debug_log_seq_by_role, role_id, nil)
    else
      ui_view.set_event_log_for_role(state, role, "")
    end
  end
  if event_log_enabled then
    local seq = 0
    if state and state.game and state.game.state and state.game.state.event_log then
      seq = event_log.get_seq(state.game.state.event_log)
    end
    if seq ~= role_id_utils.read(state._debug_log_seq_by_role, role_id) then
      role_id_utils.write(state._debug_log_seq_by_role, role_id, seq)
      local max_lines = debug_flags.debug_log_max_lines or 50
      ui_view.set_event_log_for_role(state, role, _resolve_event_text(state and state.game, max_lines))
    end
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
projectHash=e092e0a42f562041
scope.0.id=chunk:src/ui/ports/event_log.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=78
scope.0.semanticHash=c16fa30238351455
scope.1.id=function:_resolve_event_text:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=16
scope.1.semanticHash=aee3c64d64b2620a
scope.2.id=function:_sync_event_log_inner:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=47
scope.2.semanticHash=652b75f2b8c58523
scope.3.id=function:_sync_event_log_outer:49
scope.3.kind=function
scope.3.startLine=49
scope.3.endLine=57
scope.3.semanticHash=ab0ff1f6b7d803e4
scope.4.id=function:anonymous@61:61
scope.4.kind=function
scope.4.startLine=61
scope.4.endLine=63
scope.4.semanticHash=84923318e578a190
scope.5.id=function:anonymous@64:64
scope.5.kind=function
scope.5.startLine=64
scope.5.endLine=70
scope.5.semanticHash=9ea98170e326b70f
scope.6.id=function:anonymous@71:71
scope.6.kind=function
scope.6.startLine=71
scope.6.endLine=73
scope.6.semanticHash=ecaef25e2cbb9f5f
scope.7.id=function:event_log_ports.build:59
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=75
scope.7.semanticHash=08ddeb3f54ebbab0
]]
