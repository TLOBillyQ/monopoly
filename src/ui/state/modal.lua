local modal_state = {}
local runtime_state = require("src.ui.state.runtime")
local panel_interrupt = require("src.ui.coord.panel_interrupt")

local function _ui_runtime(state)
  return runtime_state.ensure_ui_runtime(state)
end

function modal_state.open_choice(state, choice_id, option_ids, selected_option_id)
  assert(state ~= nil, "missing state")
  runtime_state.set_pending_choice_elapsed(state, 0)
  runtime_state.set_pending_choice_id(state, choice_id)
  local ui_runtime = _ui_runtime(state)
  ui_runtime.choice_visible_option_ids = option_ids
  ui_runtime.pending_choice_selected_option_id = selected_option_id
end

modal_state.open_market = modal_state.open_choice

function modal_state.select_choice_option(state, option_id)
  assert(state ~= nil, "missing state")
  local ui_runtime = _ui_runtime(state)
  ui_runtime.pending_choice_selected_option_id = option_id
  runtime_state.set_ui_dirty(state, true)
end

modal_state.select_market_option = modal_state.select_choice_option

function modal_state.close_choice(state)
  assert(state ~= nil, "missing state")
  local ui_runtime = _ui_runtime(state)
  ui_runtime.choice_visible_option_ids = nil
  ui_runtime.pending_choice_selected_option_id = nil
end

function modal_state.open_popup(state, payload)
  assert(state ~= nil and state.ui ~= nil, "missing ui state")
  state.ui.popup_active = true
  state.ui.popup_payload = payload
  state.ui.popup_seq = (state.ui.popup_seq or 0) + 1
  panel_interrupt.interrupt(state)
end

function modal_state.close_popup(state)
  assert(state ~= nil and state.ui ~= nil, "missing ui state")
  state.ui.popup_active = false
  state.ui.popup_payload = nil
end

return modal_state

--[[ mutate4lua-manifest
version=2
projectHash=c146db2af753a43b
scope.0.id=chunk:src/ui/state/modal.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=51
scope.0.semanticHash=5c737239ca15b3b9
scope.1.id=function:_ui_runtime:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=7
scope.1.semanticHash=974135f95bd1e20e
scope.2.id=function:modal_state.open_choice:9
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=16
scope.2.semanticHash=727627765cec84de
scope.3.id=function:modal_state.select_choice_option:20
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=25
scope.3.semanticHash=a8207d41e9b59d70
scope.4.id=function:modal_state.close_choice:29
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=34
scope.4.semanticHash=7b611a8360c3bd03
scope.5.id=function:modal_state.open_popup:36
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=42
scope.5.semanticHash=14799ae006c61775
scope.6.id=function:modal_state.close_popup:44
scope.6.kind=function
scope.6.startLine=44
scope.6.endLine=48
scope.6.semanticHash=03842c7bb2df6be9
]]
