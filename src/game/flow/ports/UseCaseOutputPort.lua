local runtime_state = require("src.core.RuntimeState")

local output_port = {}

local function _write_legacy_field(state, key, value)
  if type(state) ~= "table" then
    return
  end
  rawset(state, key, value)
end

local function _read_legacy_field(state, key)
  if type(state) ~= "table" then
    return nil
  end
  return state[key]
end

local function _ensure_ui_runtime(state)
  return runtime_state.ensure_ui_runtime(state)
end

function output_port.invalidate_ui(state)
  local ui_runtime = _ensure_ui_runtime(state)
  if ui_runtime.ui_dirty == true or _read_legacy_field(state, "ui_dirty") == true then
    return false
  end
  ui_runtime.ui_dirty = true
  _write_legacy_field(state, "ui_dirty", true)
  return true
end

function output_port.clear_ui_dirty(state)
  local ui_runtime = _ensure_ui_runtime(state)
  if ui_runtime.ui_dirty ~= true and _read_legacy_field(state, "ui_dirty") ~= true then
    return false
  end
  ui_runtime.ui_dirty = false
  _write_legacy_field(state, "ui_dirty", false)
  return false
end

function output_port.is_ui_dirty(state)
  local ui_runtime = _ensure_ui_runtime(state)
  if ui_runtime.ui_dirty == nil then
    ui_runtime.ui_dirty = _read_legacy_field(state, "ui_dirty") == true
  end
  return ui_runtime.ui_dirty == true
end

function output_port.sync_ui_model(state, model)
  local ui_runtime = _ensure_ui_runtime(state)
  ui_runtime.ui_model = model
  _write_legacy_field(state, "ui_model", model)
  return model
end

function output_port.get_ui_model(state)
  local ui_runtime = _ensure_ui_runtime(state)
  if ui_runtime.ui_model == nil and state ~= nil then
    ui_runtime.ui_model = _read_legacy_field(state, "ui_model")
  end
  return ui_runtime.ui_model
end

function output_port.sync_pending_choice(state, choice, opts)
  local ui_runtime = _ensure_ui_runtime(state)
  opts = opts or {}
  local choice_id = opts.choice_id
  if choice_id == nil and choice ~= nil then
    choice_id = choice.id
  end
  local elapsed_seconds = opts.elapsed_seconds
  if elapsed_seconds == nil then
    elapsed_seconds = 0
  end

  ui_runtime.pending_choice = choice
  ui_runtime.pending_choice_id = choice_id
  ui_runtime.pending_choice_elapsed = elapsed_seconds

  _write_legacy_field(state, "pending_choice", choice)
  _write_legacy_field(state, "pending_choice_id", choice_id)
  _write_legacy_field(state, "pending_choice_elapsed", elapsed_seconds)
  return choice
end

function output_port.clear_pending_choice(state)
  return output_port.sync_pending_choice(state, nil, {
    choice_id = nil,
    elapsed_seconds = 0,
  })
end

function output_port.get_pending_choice(state)
  local ui_runtime = _ensure_ui_runtime(state)
  return ui_runtime.pending_choice
end

function output_port.get_pending_choice_id(state)
  local ui_runtime = _ensure_ui_runtime(state)
  return ui_runtime.pending_choice_id
end

function output_port.get_pending_choice_elapsed(state)
  local ui_runtime = _ensure_ui_runtime(state)
  return ui_runtime.pending_choice_elapsed or 0
end

function output_port.set_pending_choice_elapsed(state, elapsed_seconds)
  local ui_runtime = _ensure_ui_runtime(state)
  local next_elapsed = elapsed_seconds or 0
  ui_runtime.pending_choice_elapsed = next_elapsed
  _write_legacy_field(state, "pending_choice_elapsed", next_elapsed)
  return next_elapsed
end

function output_port.set_pending_choice_id(state, choice_id)
  local ui_runtime = _ensure_ui_runtime(state)
  ui_runtime.pending_choice_id = choice_id
  _write_legacy_field(state, "pending_choice_id", choice_id)
  return choice_id
end

function output_port.sync_modal_timer(state, payload)
  local ui_runtime = _ensure_ui_runtime(state)
  payload = payload or {}
  local elapsed_seconds = payload.elapsed_seconds or 0
  local ref = payload.ref
  ui_runtime.ui_modal_elapsed = elapsed_seconds
  ui_runtime.ui_modal_ref = ref
  _write_legacy_field(state, "ui_modal_elapsed", elapsed_seconds)
  _write_legacy_field(state, "ui_modal_ref", ref)
  return ref, elapsed_seconds
end

function output_port.get_modal_elapsed(state)
  local ui_runtime = _ensure_ui_runtime(state)
  return ui_runtime.ui_modal_elapsed or 0
end

function output_port.get_modal_ref(state)
  local ui_runtime = _ensure_ui_runtime(state)
  return ui_runtime.ui_modal_ref
end

function output_port.build_base_output_ports()
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

function output_port.fill_output_defaults()
end

return output_port
