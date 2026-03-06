local mirror = {}

local function _write(state, key, value)
  if type(state) ~= "table" then
    return
  end
  rawset(state, key, value)
end

function mirror.wrap(output_ports)
  assert(type(output_ports) == "table", "missing output_ports")
  return {
    invalidate_ui = function(state)
      local changed = output_ports.invalidate_ui(state)
      _write(state, "ui_dirty", output_ports.is_ui_dirty(state))
      return changed
    end,
    clear_ui_dirty = function(state)
      local changed = output_ports.clear_ui_dirty(state)
      _write(state, "ui_dirty", output_ports.is_ui_dirty(state))
      return changed
    end,
    is_ui_dirty = output_ports.is_ui_dirty,
    sync_ui_model = function(state, model)
      local result = output_ports.sync_ui_model(state, model)
      _write(state, "ui_model", model)
      return result
    end,
    get_ui_model = output_ports.get_ui_model,
    sync_pending_choice = function(state, choice, opts)
      local result = output_ports.sync_pending_choice(state, choice, opts)
      local choice_id = output_ports.get_pending_choice_id(state)
      local elapsed_seconds = output_ports.get_pending_choice_elapsed(state)
      _write(state, "pending_choice", choice)
      _write(state, "pending_choice_id", choice_id)
      _write(state, "pending_choice_elapsed", elapsed_seconds)
      return result
    end,
    clear_pending_choice = function(state)
      local result = output_ports.clear_pending_choice(state)
      _write(state, "pending_choice", nil)
      _write(state, "pending_choice_id", nil)
      _write(state, "pending_choice_elapsed", 0)
      return result
    end,
    get_pending_choice = output_ports.get_pending_choice,
    get_pending_choice_id = output_ports.get_pending_choice_id,
    get_pending_choice_elapsed = output_ports.get_pending_choice_elapsed,
    set_pending_choice_elapsed = function(state, elapsed_seconds)
      local result = output_ports.set_pending_choice_elapsed(state, elapsed_seconds)
      _write(state, "pending_choice_elapsed", result)
      return result
    end,
    set_pending_choice_id = function(state, choice_id)
      local result = output_ports.set_pending_choice_id(state, choice_id)
      _write(state, "pending_choice_id", result)
      return result
    end,
    sync_modal_timer = function(state, payload)
      local ref, elapsed_seconds = output_ports.sync_modal_timer(state, payload)
      _write(state, "ui_modal_ref", ref)
      _write(state, "ui_modal_elapsed", elapsed_seconds)
      return ref, elapsed_seconds
    end,
    get_modal_elapsed = output_ports.get_modal_elapsed,
    get_modal_ref = output_ports.get_modal_ref,
  }
end

return mirror
