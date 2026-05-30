-- Turn flow-local bridge that syncs runtime-facing output back into ui_runtime state.
local runtime_state = require("src.state.runtime")
local state_adapter = {}

function state_adapter.invalidate_ui_model(state)
  if runtime_state.is_ui_dirty(state) then
    return false
  end
  runtime_state.set_ui_dirty(state, true)
  return true
end

function state_adapter.clear_ui_dirty(state)
  if not runtime_state.is_ui_dirty(state) then
    return false
  end
  runtime_state.set_ui_dirty(state, false)
  return true
end

state_adapter.is_ui_dirty = runtime_state.is_ui_dirty
state_adapter.sync_ui_model = runtime_state.set_ui_model
state_adapter.get_ui_model = runtime_state.get_ui_model
state_adapter.sync_pending_choice = runtime_state.set_pending_choice

local _clear_choice_opts = { choice_id = nil, elapsed_seconds = 0 }

function state_adapter.clear_pending_choice(state)
  return state_adapter.sync_pending_choice(state, nil, _clear_choice_opts)
end

state_adapter.get_pending_choice = runtime_state.get_pending_choice
state_adapter.get_pending_choice_id = runtime_state.get_pending_choice_id
state_adapter.get_pending_choice_elapsed = runtime_state.get_pending_choice_elapsed
state_adapter.set_pending_choice_elapsed = runtime_state.set_pending_choice_elapsed
state_adapter.set_pending_choice_id = runtime_state.set_pending_choice_id
state_adapter.sync_modal_timer = runtime_state.set_modal_timer
state_adapter.get_modal_elapsed = runtime_state.get_modal_elapsed
state_adapter.get_modal_ref = runtime_state.get_modal_ref

function state_adapter.build_runtime_output_ports()
  return {
    invalidate_ui_model = state_adapter.invalidate_ui_model,
    clear_ui_dirty = state_adapter.clear_ui_dirty,
    is_ui_dirty = state_adapter.is_ui_dirty,
    sync_ui_model = state_adapter.sync_ui_model,
    get_ui_model = state_adapter.get_ui_model,
    sync_pending_choice = state_adapter.sync_pending_choice,
    clear_pending_choice = state_adapter.clear_pending_choice,
    get_pending_choice = state_adapter.get_pending_choice,
    get_pending_choice_id = state_adapter.get_pending_choice_id,
    get_pending_choice_elapsed = state_adapter.get_pending_choice_elapsed,
    set_pending_choice_elapsed = state_adapter.set_pending_choice_elapsed,
    set_pending_choice_id = state_adapter.set_pending_choice_id,
    sync_modal_timer = state_adapter.sync_modal_timer,
    get_modal_elapsed = state_adapter.get_modal_elapsed,
    get_modal_ref = state_adapter.get_modal_ref,
  }
end

return state_adapter

--[[ mutate4lua-manifest
version=2
projectHash=e7d2d6c5465c8fdf
scope.0.id=chunk:src/turn/output/state_adapter.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=62
scope.0.semanticHash=c1d81c25714168b7
scope.1.id=function:state_adapter.invalidate_ui_model:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=f13730d2b7541aed
scope.2.id=function:state_adapter.clear_ui_dirty:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=19
scope.2.semanticHash=d07d9f5e6dcf1e8a
scope.3.id=function:state_adapter.clear_pending_choice:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=30
scope.3.semanticHash=3ded50c28191e268
scope.4.id=function:state_adapter.build_runtime_output_ports:41
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=59
scope.4.semanticHash=eac2dc006c4d3ea0
]]
