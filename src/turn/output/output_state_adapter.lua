-- Turn flow-local bridge that syncs runtime-facing output back into ui_runtime state.
local runtime_state = require("src.state.state_access.runtime_state")
local output_state_adapter = {}

function output_state_adapter.invalidate_ui(state)
  if runtime_state.is_ui_dirty(state) then
    return false
  end
  runtime_state.set_ui_dirty(state, true)
  return true
end

function output_state_adapter.invalidate_ui_model(state)
  return output_state_adapter.invalidate_ui(state)
end

function output_state_adapter.clear_ui_dirty(state)
  if not runtime_state.is_ui_dirty(state) then
    return false
  end
  runtime_state.set_ui_dirty(state, false)
  return true
end

function output_state_adapter.is_ui_dirty(state)
  return runtime_state.is_ui_dirty(state)
end

function output_state_adapter.sync_ui_model(state, model)
  return runtime_state.set_ui_model(state, model)
end

function output_state_adapter.get_ui_model(state)
  return runtime_state.get_ui_model(state)
end

function output_state_adapter.sync_pending_choice(state, choice, opts)
  return runtime_state.set_pending_choice(state, choice, opts)
end

function output_state_adapter.clear_pending_choice(state)
  return output_state_adapter.sync_pending_choice(state, nil, {
    choice_id = nil,
    elapsed_seconds = 0,
  })
end

function output_state_adapter.get_pending_choice(state)
  return runtime_state.get_pending_choice(state)
end

function output_state_adapter.get_pending_choice_id(state)
  return runtime_state.get_pending_choice_id(state)
end

function output_state_adapter.get_pending_choice_elapsed(state)
  return runtime_state.get_pending_choice_elapsed(state)
end

function output_state_adapter.set_pending_choice_elapsed(state, elapsed_seconds)
  return runtime_state.set_pending_choice_elapsed(state, elapsed_seconds)
end

function output_state_adapter.set_pending_choice_id(state, choice_id)
  return runtime_state.set_pending_choice_id(state, choice_id)
end

function output_state_adapter.sync_modal_timer(state, payload)
  return runtime_state.set_modal_timer(state, payload)
end

function output_state_adapter.get_modal_elapsed(state)
  return runtime_state.get_modal_elapsed(state)
end

function output_state_adapter.get_modal_ref(state)
  return runtime_state.get_modal_ref(state)
end

function output_state_adapter.build_runtime_output_ports()
  return {
    invalidate_ui = output_state_adapter.invalidate_ui,
    invalidate_ui_model = output_state_adapter.invalidate_ui_model,
    clear_ui_dirty = output_state_adapter.clear_ui_dirty,
    is_ui_dirty = output_state_adapter.is_ui_dirty,
    sync_ui_model = output_state_adapter.sync_ui_model,
    get_ui_model = output_state_adapter.get_ui_model,
    sync_pending_choice = output_state_adapter.sync_pending_choice,
    clear_pending_choice = output_state_adapter.clear_pending_choice,
    get_pending_choice = output_state_adapter.get_pending_choice,
    get_pending_choice_id = output_state_adapter.get_pending_choice_id,
    get_pending_choice_elapsed = output_state_adapter.get_pending_choice_elapsed,
    set_pending_choice_elapsed = output_state_adapter.set_pending_choice_elapsed,
    set_pending_choice_id = output_state_adapter.set_pending_choice_id,
    sync_modal_timer = output_state_adapter.sync_modal_timer,
    get_modal_elapsed = output_state_adapter.get_modal_elapsed,
    get_modal_ref = output_state_adapter.get_modal_ref,
  }
end

function output_state_adapter.build_base_output_ports()
  return output_state_adapter.build_runtime_output_ports()
end

function output_state_adapter.fill_output_defaults()
end

return output_state_adapter
