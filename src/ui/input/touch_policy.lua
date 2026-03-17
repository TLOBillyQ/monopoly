local always_show_nodes = require("src.ui.schema.always_show_nodes")
local always_show_contract = require("src.ui.schema.always_show_contract")

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
  controls = controls or ui.auto_control_nodes or { always_show_nodes.auto_button, always_show_nodes.auto_label }
  local auto_effect_seen = false
  for _, name in ipairs(controls) do
    if name == always_show_nodes.auto_button then
      ui:set_touch_enabled(name, auto_enabled == true)
    else
      ui:set_touch_enabled(name, false)
    end
    if name == always_show_nodes.auto_effect then
      auto_effect_seen = true
    end
  end
  if not auto_effect_seen then
    ui:set_touch_enabled(always_show_nodes.auto_effect, false)
  end
end

function touch_policy.set_action_log_toggle_touch(ui, enabled)
  if not ui or not ui.set_touch_enabled then
    return
  end
  local value = enabled == true
  local targets = always_show_contract.action_log.toggle_targets
    or { always_show_nodes.action_log_button }
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
