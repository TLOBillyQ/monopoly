local ui_controls = {}

local function _has_ui_method(ui, method_name)
  return ui ~= nil and type(ui[method_name]) == "function"
end

local function _clear_control_text(ui, name)
  if not name or ui == nil then
    return
  end
  if _has_ui_method(ui, "set_label") then
    ui:set_label(name, "")
  end
  if _has_ui_method(ui, "set_button") then
    ui:set_button(name, "")
  end
end

function ui_controls.set_control_state(ui, name, options)
  if not name or ui == nil then
    return
  end

  local control_options = options or {}
  if control_options.visible ~= nil and _has_ui_method(ui, "set_visible") then
    ui:set_visible(name, control_options.visible == true)
  end

  if control_options.touch_enabled ~= nil and _has_ui_method(ui, "set_touch_enabled") then
    ui:set_touch_enabled(name, control_options.touch_enabled == true)
  end
end

function ui_controls.set_controls_state(ui, names, options)
  if type(names) ~= "table" then
    return
  end

  for _, name in ipairs(names) do
    ui_controls.set_control_state(ui, name, options)
  end
end

function ui_controls.set_slot_state(ui, slot, options_by_key)
  if type(slot) ~= "table" then
    return
  end

  local key_options = options_by_key or {}
  for key, options in pairs(key_options) do
    ui_controls.set_control_state(ui, slot[key], options)
  end
end

function ui_controls.reset_choice_screen(ui, screen)
  if type(screen) ~= "table" then
    return
  end

  ui_controls.set_control_state(ui, screen.root, { visible = false })
  _clear_control_text(ui, screen.title)
  _clear_control_text(ui, screen.body)
  _clear_control_text(ui, screen.confirm)
  _clear_control_text(ui, screen.cancel)
  ui_controls.set_control_state(ui, screen.confirm, { visible = false, touch_enabled = false })
  ui_controls.set_control_state(ui, screen.cancel, { visible = false, touch_enabled = false })
  ui_controls.set_controls_state(ui, screen.option_buttons, { visible = false, touch_enabled = false })
  ui_controls.set_controls_state(ui, screen.slot_labels, { visible = false, touch_enabled = false })
  ui_controls.set_controls_state(ui, screen.slot_projections, { visible = false, touch_enabled = false })
  ui_controls.set_control_state(ui, screen.under_button, { visible = false, touch_enabled = false })
end

return ui_controls
