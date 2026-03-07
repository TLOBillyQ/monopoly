local mirror = {}

function mirror.wrap(output_ports)
  assert(type(output_ports) == "table", "missing output_ports")
  return {
    invalidate_ui = output_ports.invalidate_ui,
    clear_ui_dirty = output_ports.clear_ui_dirty,
    is_ui_dirty = output_ports.is_ui_dirty,
    sync_ui_model = output_ports.sync_ui_model,
    get_ui_model = output_ports.get_ui_model,
    sync_pending_choice = output_ports.sync_pending_choice,
    clear_pending_choice = output_ports.clear_pending_choice,
    get_pending_choice = output_ports.get_pending_choice,
    get_pending_choice_id = output_ports.get_pending_choice_id,
    get_pending_choice_elapsed = output_ports.get_pending_choice_elapsed,
    set_pending_choice_elapsed = output_ports.set_pending_choice_elapsed,
    set_pending_choice_id = output_ports.set_pending_choice_id,
    sync_modal_timer = output_ports.sync_modal_timer,
    get_modal_elapsed = output_ports.get_modal_elapsed,
    get_modal_ref = output_ports.get_modal_ref,
  }
end

return mirror
