local ui_nodes = require("visual.nodes")

local touch_policy = {}

function touch_policy.set_many_touch_enabled(ui, names, enabled)
  if not ui or not ui.set_touch_enabled then
    return
  end
  if type(names) ~= "table" then
    return
  end
  local value = enabled == true
  for _, name in ipairs(names) do
    if name then
      ui:set_touch_enabled(name, value)
    end
  end
end

function touch_policy.set_auto_controls_touch(ui, auto_enabled, controls)
  if not ui or not ui.set_touch_enabled then
    return
  end
  controls = controls or ui.auto_control_nodes or { ui_nodes.buttons.auto, ui_nodes.labels.auto }
  for _, name in ipairs(controls) do
    if name == ui_nodes.buttons.auto then
      ui:set_touch_enabled(name, auto_enabled == true)
    else
      ui:set_touch_enabled(name, false)
    end
  end
end

function touch_policy.set_action_log_toggle_touch(ui, enabled)
  if not ui or not ui.set_touch_enabled then
    return
  end
  local value = enabled == true
  local targets = ui_nodes.action_log.toggle_targets
    or { ui_nodes.action_log.toggle_button, ui_nodes.action_log.toggle_image }
  for _, name in ipairs(targets) do
    ui:set_touch_enabled(name, value)
  end
end

function touch_policy.set_runtime_nodes_touch_enabled(nodes, enabled)
  if type(nodes) ~= "table" then
    return
  end
  local value = enabled == true
  for _, node in ipairs(nodes) do
    if node then
      node.disabled = not value
    end
  end
end

function touch_policy.set_choice_screen_locked(ui, screen)
  if not ui or not ui.set_touch_enabled or not screen then
    return
  end
  touch_policy.set_many_touch_enabled(ui, screen.option_buttons or {}, false)
  if screen.under_button then
    ui:set_touch_enabled(screen.under_button, false)
  end
  if screen.confirm then
    ui:set_touch_enabled(screen.confirm, false)
  end
  if screen.cancel then
    ui:set_touch_enabled(screen.cancel, false)
  end
end

return touch_policy
