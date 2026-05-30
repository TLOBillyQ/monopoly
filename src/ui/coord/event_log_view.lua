local runtime = require("src.ui.render.runtime_ui")
local role_id_utils = require("src.foundation.identity")

local M = {}

local function _ensure_debug_tables(ui)
  if type(ui.debug_visible_by_role) ~= "table" then
    ui.debug_visible_by_role = {}
  end
  if type(ui.debug_log_enabled_by_role) ~= "table" then
    ui.debug_log_enabled_by_role = {}
  end
end

local function _record_role_visibility(ui, role_id, resolved)
  _ensure_debug_tables(ui)
  role_id_utils.write(ui.debug_visible_by_role, role_id, resolved)
  role_id_utils.write(ui.debug_log_enabled_by_role, role_id, resolved)
end

local function _resolve_debug_log_ui(state)
  local ui = state and state.ui
  if not ui or not ui.set_event_log then
    return nil
  end
  return ui
end

function M.set_event_log(state, text)
  local ui = _resolve_debug_log_ui(state)
  if ui == nil then
    return
  end
  ui:set_event_log(text or "")
end

local _el_ui
local _el_text
local function _set_event_log_callback()
  _el_ui:set_event_log(_el_text)
end

function M.set_event_log_for_role(state, role, text)
  local ui = _resolve_debug_log_ui(state)
  if ui == nil or role == nil then
    return
  end
  _el_ui = ui
  _el_text = text or ""
  runtime.with_client_role(role, _set_event_log_callback)
end

local _elv_ui
local _elv_visible
local function _set_event_log_visible_callback()
  _elv_ui:set_event_log_visible(_elv_visible)
end

function M.set_event_log_visible_for_role(state, role, visible)
  local ui = state and state.ui
  if not ui or not ui.set_event_log_visible then
    return false
  end
  local role_id = role_id_utils.normalize(runtime.resolve_role_id(role))
  if role_id == nil then
    return false
  end
  local resolved = visible == true
  _elv_ui = ui
  _elv_visible = resolved
  runtime.with_client_role(role, _set_event_log_visible_callback)
  _record_role_visibility(ui, role_id, resolved)
  return true
end

function M.set_event_log_visible(state, visible)
  local role = runtime.get_client_role()
  if role ~= nil then
    return M.set_event_log_visible_for_role(state, role, visible)
  end
  local ui = state and state.ui
  if not ui or not ui.set_event_log_visible then
    return false
  end
  local resolved = visible == true
  -- 启动/兼容路径：无角色上下文时仍允许全局写入，但运行态逻辑不依赖它。
  ui:set_event_log_visible(resolved)
  ui.debug_visible = resolved
  return true
end

local function _set_visibility(state, role_id, visible)
  local ui = state and state.ui
  if not ui then
    return false
  end
  local rid = role_id_utils.normalize(role_id)
  if rid == nil then
    return false
  end
  local resolved = visible == true
  _record_role_visibility(ui, rid, resolved)
  if ui.set_event_log_visible then
    ui:set_event_log_visible(resolved)
  end
  return true
end

function M.open(state, role_id)
  return _set_visibility(state, role_id, true)
end

function M.close(state, role_id)
  return _set_visibility(state, role_id, false)
end

function M.is_open(state, role_id)
  local ui = state and state.ui
  if not ui or type(ui.debug_visible_by_role) ~= "table" then
    return false
  end
  return role_id_utils.read(ui.debug_visible_by_role, role_id) == true
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=779642ec79ff3a10
scope.0.id=chunk:src/ui/coord/event_log_view.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=126
scope.0.semanticHash=607a504348377d74
scope.1.id=function:_ensure_debug_tables:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=13
scope.1.semanticHash=581c77385746176e
scope.2.id=function:_record_role_visibility:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=19
scope.2.semanticHash=d7fc43b1dc71bad3
scope.3.id=function:_resolve_debug_log_ui:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=27
scope.3.semanticHash=23127f8ba3d23587
scope.4.id=function:M.set_event_log:29
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=35
scope.4.semanticHash=2275048d8d5632ea
scope.5.id=function:_set_event_log_callback:39
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=41
scope.5.semanticHash=9bc34086c3a98eb2
scope.6.id=function:M.set_event_log_for_role:43
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=51
scope.6.semanticHash=fe6bad84b675dd2e
scope.7.id=function:_set_event_log_visible_callback:55
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=57
scope.7.semanticHash=6750d27d8d01818d
scope.8.id=function:M.set_event_log_visible_for_role:59
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=74
scope.8.semanticHash=1c7930418b2e90f2
scope.9.id=function:M.set_event_log_visible:76
scope.9.kind=function
scope.9.startLine=76
scope.9.endLine=90
scope.9.semanticHash=39ccbca75a11e6b2
scope.10.id=function:_set_visibility:92
scope.10.kind=function
scope.10.startLine=92
scope.10.endLine=107
scope.10.semanticHash=7ab82db95064e7a9
scope.11.id=function:M.open:109
scope.11.kind=function
scope.11.startLine=109
scope.11.endLine=111
scope.11.semanticHash=ce1163ac64f48f61
scope.12.id=function:M.close:113
scope.12.kind=function
scope.12.startLine=113
scope.12.endLine=115
scope.12.semanticHash=e182b5c28a9e6260
scope.13.id=function:M.is_open:117
scope.13.kind=function
scope.13.startLine=117
scope.13.endLine=123
scope.13.semanticHash=210160b8a85bebe8
]]
