local runtime_state = {}

local function _runtime_state()
return require("src.state.runtime")
end

function runtime_state.ensure_all(state)
  return _runtime_state().ensure_all(state)
end

function runtime_state.ensure_ui_runtime(state)
  return _runtime_state().ensure_ui_runtime(state)
end

function runtime_state.ensure_board_runtime(state)
  return _runtime_state().ensure_board_runtime(state)
end

function runtime_state.ensure_anim_runtime(state)
  return _runtime_state().ensure_anim_runtime(state)
end

function runtime_state.ensure_turn_runtime(state)
  return _runtime_state().ensure_turn_runtime(state)
end

function runtime_state.ensure_debug_runtime(state)
  return _runtime_state().ensure_debug_runtime(state)
end

function runtime_state.log_once(state, level, key, ...)
  return _runtime_state().log_once(state, level, key, ...)
end

function runtime_state.is_ui_dirty(state)
  return _runtime_state().is_ui_dirty(state)
end

function runtime_state.set_ui_dirty(state, dirty)
  return _runtime_state().set_ui_dirty(state, dirty)
end

function runtime_state.get_ui_model(state)
  return _runtime_state().get_ui_model(state)
end

function runtime_state.set_ui_model(state, model)
  return _runtime_state().set_ui_model(state, model)
end

-- 当前 ui_model 上挂的 choice（可能已过期）；无模型或无 choice 时返回 nil。
function runtime_state.get_ui_model_choice(state)
  local current_model = runtime_state.get_ui_model(state)
  return current_model and current_model.choice or nil
end

function runtime_state.get_pending_choice(state)
  return _runtime_state().get_pending_choice(state)
end

function runtime_state.get_pending_choice_id(state)
  return _runtime_state().get_pending_choice_id(state)
end

function runtime_state.set_pending_choice_id(state, choice_id)
  return _runtime_state().set_pending_choice_id(state, choice_id)
end

function runtime_state.get_pending_choice_elapsed(state)
  return _runtime_state().get_pending_choice_elapsed(state)
end

function runtime_state.set_pending_choice_elapsed(state, elapsed_seconds)
  return _runtime_state().set_pending_choice_elapsed(state, elapsed_seconds)
end

function runtime_state.set_pending_choice(state, choice, opts)
  return _runtime_state().set_pending_choice(state, choice, opts)
end

function runtime_state.get_modal_elapsed(state)
  return _runtime_state().get_modal_elapsed(state)
end

function runtime_state.get_modal_ref(state)
  return _runtime_state().get_modal_ref(state)
end

function runtime_state.set_modal_timer(state, payload)
  return _runtime_state().set_modal_timer(state, payload)
end

function runtime_state.set_follow_target_position(state, player_id, position, opts)
  return _runtime_state().set_follow_target_position(state, player_id, position, opts)
end

function runtime_state.get_follow_target_position(state, player_id)
  return _runtime_state().get_follow_target_position(state, player_id)
end

return runtime_state

--[[ mutate4lua-manifest
version=4
projectHash=c0a863e1b6ea5be8
scope.0.id=chunk:src/ui/state/runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=102
scope.0.semanticHash=0624a45e6e6fa7da
scope.1.id=function:_runtime_state
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=361867a8848129cb
scope.2.id=function:runtime_state.ensure_all
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=9
scope.2.semanticHash=f1ce1850b7232305
scope.3.id=function:runtime_state.ensure_ui_runtime
scope.3.kind=function
scope.3.startLine=11
scope.3.endLine=13
scope.3.semanticHash=f1ce1850b7232305
scope.4.id=function:runtime_state.ensure_board_runtime
scope.4.kind=function
scope.4.startLine=15
scope.4.endLine=17
scope.4.semanticHash=f1ce1850b7232305
scope.5.id=function:runtime_state.ensure_anim_runtime
scope.5.kind=function
scope.5.startLine=19
scope.5.endLine=21
scope.5.semanticHash=f1ce1850b7232305
scope.6.id=function:runtime_state.ensure_turn_runtime
scope.6.kind=function
scope.6.startLine=23
scope.6.endLine=25
scope.6.semanticHash=f1ce1850b7232305
scope.7.id=function:runtime_state.ensure_debug_runtime
scope.7.kind=function
scope.7.startLine=27
scope.7.endLine=29
scope.7.semanticHash=f1ce1850b7232305
scope.8.id=function:runtime_state.log_once
scope.8.kind=function
scope.8.startLine=31
scope.8.endLine=33
scope.8.semanticHash=c4981f16ef799e2b
scope.9.id=function:runtime_state.is_ui_dirty
scope.9.kind=function
scope.9.startLine=35
scope.9.endLine=37
scope.9.semanticHash=f1ce1850b7232305
scope.10.id=function:runtime_state.set_ui_dirty
scope.10.kind=function
scope.10.startLine=39
scope.10.endLine=41
scope.10.semanticHash=aba9250a8c6b104f
scope.11.id=function:runtime_state.get_ui_model
scope.11.kind=function
scope.11.startLine=43
scope.11.endLine=45
scope.11.semanticHash=f1ce1850b7232305
scope.12.id=function:runtime_state.set_ui_model
scope.12.kind=function
scope.12.startLine=47
scope.12.endLine=49
scope.12.semanticHash=aba9250a8c6b104f
scope.13.id=function:runtime_state.get_ui_model_choice
scope.13.kind=function
scope.13.startLine=52
scope.13.endLine=55
scope.13.semanticHash=9225cfe7b87d962b
scope.14.id=function:runtime_state.get_pending_choice
scope.14.kind=function
scope.14.startLine=57
scope.14.endLine=59
scope.14.semanticHash=f1ce1850b7232305
scope.15.id=function:runtime_state.get_pending_choice_id
scope.15.kind=function
scope.15.startLine=61
scope.15.endLine=63
scope.15.semanticHash=f1ce1850b7232305
scope.16.id=function:runtime_state.set_pending_choice_id
scope.16.kind=function
scope.16.startLine=65
scope.16.endLine=67
scope.16.semanticHash=aba9250a8c6b104f
scope.17.id=function:runtime_state.get_pending_choice_elapsed
scope.17.kind=function
scope.17.startLine=69
scope.17.endLine=71
scope.17.semanticHash=f1ce1850b7232305
scope.18.id=function:runtime_state.set_pending_choice_elapsed
scope.18.kind=function
scope.18.startLine=73
scope.18.endLine=75
scope.18.semanticHash=aba9250a8c6b104f
scope.19.id=function:runtime_state.set_pending_choice
scope.19.kind=function
scope.19.startLine=77
scope.19.endLine=79
scope.19.semanticHash=d590c542c8c308c5
scope.20.id=function:runtime_state.get_modal_elapsed
scope.20.kind=function
scope.20.startLine=81
scope.20.endLine=83
scope.20.semanticHash=f1ce1850b7232305
scope.21.id=function:runtime_state.get_modal_ref
scope.21.kind=function
scope.21.startLine=85
scope.21.endLine=87
scope.21.semanticHash=f1ce1850b7232305
scope.22.id=function:runtime_state.set_modal_timer
scope.22.kind=function
scope.22.startLine=89
scope.22.endLine=91
scope.22.semanticHash=aba9250a8c6b104f
scope.23.id=function:runtime_state.set_follow_target_position
scope.23.kind=function
scope.23.startLine=93
scope.23.endLine=95
scope.23.semanticHash=360776c78d632b1f
scope.24.id=function:runtime_state.get_follow_target_position
scope.24.kind=function
scope.24.startLine=97
scope.24.endLine=99
scope.24.semanticHash=aba9250a8c6b104f
]]
