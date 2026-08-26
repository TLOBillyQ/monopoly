local with_client_role = require("src.ui.render.support.with_client_role")
local event_log = require("src.state.event_log")
local ui_event_state = require("src.ui.coord.event_state")
local runtime = require("src.ui.render.support.runtime_ui")
local role_id_utils = require("src.foundation.identity")
local ui_view = require("src.ui.coord.ui_runtime")

local event_log_ports = {}
-- 保守下界：宿主运行时读不到字号/节点高度/分辨率（ADR 0060），可视容量无法推导；
-- 语义是「最小支持机型也不溢出」，不是「填满屏幕」。
local DISPLAY_LINE_LIMIT = 20

local function _resolve_event_text(game)
  if game and game.state and game.state.event_log then
    -- 宿主日志节点是不可滚动的 ELabel；窗口超限后只能把最新一段放进可视文本，
    -- 让最新行动自然落在底部，同时状态层仍保留完整容量内的历史。
    return event_log.get_text(game.state.event_log, DISPLAY_LINE_LIMIT)
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
    ui_view.set_event_log_for_role(state, role, _resolve_event_text(state and state.game))
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

function event_log_ports.build()
  return {
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
version=4
projectHash=2ff1ba77fbbddaeb
scope.0.id=chunk:src/ui/ports/event_log.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=90
scope.0.semanticHash=9ee5a75ed1acb84a
scope.1.id=function:_resolve_event_text
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=20
scope.1.semanticHash=3ab538ab0697d822
scope.2.id=function:_apply_enabled_change
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=34
scope.2.semanticHash=203764a34a3b08f1
scope.3.id=function:_read_current_seq
scope.3.kind=function
scope.3.startLine=36
scope.3.endLine=41
scope.3.semanticHash=f41a35154eff9718
scope.4.id=function:_sync_event_content
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=49
scope.4.semanticHash=bc0203708a47c355
scope.5.id=function:_sync_event_log_inner
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=62
scope.5.semanticHash=14d92dea7f15e4c3
scope.6.id=function:_sync_event_log_outer
scope.6.kind=function
scope.6.startLine=64
scope.6.endLine=72
scope.6.semanticHash=52538922e3481926
scope.7.id=function:event_log_ports.build
scope.7.kind=function
scope.7.startLine=74
scope.7.endLine=87
scope.7.semanticHash=ad6fce672e1d3128
scope.8.id=function:<anonymous>
scope.8.kind=function
scope.8.startLine=76
scope.8.endLine=82
scope.8.semanticHash=dcd7fcb7794ea045
scope.9.id=function:<anonymous>#2
scope.9.kind=function
scope.9.startLine=83
scope.9.endLine=85
scope.9.semanticHash=aba9250a8c6b104f
]]
