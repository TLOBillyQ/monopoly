local runtime_state = require("src.core.state_access.runtime_state")
local output_port = {}

function output_port.invalidate_ui(state)
  if runtime_state.is_ui_dirty(state) then
    return false
  end
  runtime_state.set_ui_dirty(state, true)
  return true
end

function output_port.clear_ui_dirty(state)
  if not runtime_state.is_ui_dirty(state) then
    return false
  end
  runtime_state.set_ui_dirty(state, false)
  return true
end

function output_port.is_ui_dirty(state)
  return runtime_state.is_ui_dirty(state)
end

function output_port.sync_ui_model(state, model)
  return runtime_state.set_ui_model(state, model)
end

function output_port.get_ui_model(state)
  return runtime_state.get_ui_model(state)
end

function output_port.sync_pending_choice(state, choice, opts)
  return runtime_state.set_pending_choice(state, choice, opts)
end

function output_port.clear_pending_choice(state)
  return output_port.sync_pending_choice(state, nil, {
    choice_id = nil,
    elapsed_seconds = 0,
  })
end

function output_port.get_pending_choice(state)
  return runtime_state.get_pending_choice(state)
end

function output_port.get_pending_choice_id(state)
  return runtime_state.get_pending_choice_id(state)
end

function output_port.get_pending_choice_elapsed(state)
  return runtime_state.get_pending_choice_elapsed(state)
end

function output_port.set_pending_choice_elapsed(state, elapsed_seconds)
  return runtime_state.set_pending_choice_elapsed(state, elapsed_seconds)
end

function output_port.set_pending_choice_id(state, choice_id)
  return runtime_state.set_pending_choice_id(state, choice_id)
end

function output_port.sync_modal_timer(state, payload)
  return runtime_state.set_modal_timer(state, payload)
end

function output_port.get_modal_elapsed(state)
  return runtime_state.get_modal_elapsed(state)
end

function output_port.get_modal_ref(state)
  return runtime_state.get_modal_ref(state)
end

function output_port.build_runtime_output_ports()
  return {
    invalidate_ui = output_port.invalidate_ui,
    clear_ui_dirty = output_port.clear_ui_dirty,
    is_ui_dirty = output_port.is_ui_dirty,
    sync_ui_model = output_port.sync_ui_model,
    get_ui_model = output_port.get_ui_model,
    sync_pending_choice = output_port.sync_pending_choice,
    clear_pending_choice = output_port.clear_pending_choice,
    get_pending_choice = output_port.get_pending_choice,
    get_pending_choice_id = output_port.get_pending_choice_id,
    get_pending_choice_elapsed = output_port.get_pending_choice_elapsed,
    set_pending_choice_elapsed = output_port.set_pending_choice_elapsed,
    set_pending_choice_id = output_port.set_pending_choice_id,
    sync_modal_timer = output_port.sync_modal_timer,
    get_modal_elapsed = output_port.get_modal_elapsed,
    get_modal_ref = output_port.get_modal_ref,
  }
end

function output_port.build_base_output_ports()
  return output_port.build_runtime_output_ports()
end

function output_port.fill_output_defaults()
end

return output_port
