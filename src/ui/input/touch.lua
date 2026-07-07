local base_nodes = require("src.ui.schema.base")
local base_contract = require("src.ui.schema.base_contract")

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

local function resolve_auto_controls(ui, controls)
  return controls or ui.auto_control_nodes or { base_nodes.auto_button, base_nodes.auto_label }
end

local function apply_auto_controls(ui, auto_enabled, controls)
  local auto_effect_seen = false
  for _, name in ipairs(controls) do
    if name == base_nodes.auto_button then
      ui:set_touch_enabled(name, auto_enabled == true)
    else
      ui:set_touch_enabled(name, false)
    end
    if name == base_nodes.auto_effect then
      auto_effect_seen = true
    end
  end
  return auto_effect_seen
end

function touch_policy.set_auto_controls_touch(ui, auto_enabled, controls)
  if not ui or not ui.set_touch_enabled then
    return
  end
  controls = resolve_auto_controls(ui, controls)
  if not apply_auto_controls(ui, auto_enabled, controls) then
    ui:set_touch_enabled(base_nodes.auto_effect, false)
  end
end

function touch_policy.set_action_log_toggle_touch(ui, enabled)
  if not ui or not ui.set_touch_enabled then
    return
  end
  local value = enabled == true
  local targets = base_contract.action_log.toggle_targets
    or { base_nodes.action_log_button }
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

--[[ mutate4lua-manifest
version=2
projectHash=d7b88ea7d6fb8052
scope.0.id=chunk:src/ui/input/touch.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=91
scope.0.semanticHash=510b74ede98ff38e
scope.0.lastMutatedAt=2026-07-07T02:45:57Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=34
scope.0.lastMutationKilled=34
scope.1.id=function:resolve_auto_controls:21
scope.1.kind=function
scope.1.startLine=21
scope.1.endLine=23
scope.1.semanticHash=858e323f685de82d
scope.1.lastMutatedAt=2026-07-07T02:45:57Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:touch_policy.set_auto_controls_touch:40
scope.2.kind=function
scope.2.startLine=40
scope.2.endLine=48
scope.2.semanticHash=72978f12cb826e79
scope.2.lastMutatedAt=2026-07-07T02:45:57Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
scope.3.id=function:touch_policy.set_choice_screen_locked:74
scope.3.kind=function
scope.3.startLine=74
scope.3.endLine=88
scope.3.semanticHash=d71a3fd947304630
scope.3.lastMutatedAt=2026-07-07T02:45:57Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=9
scope.3.lastMutationKilled=9
]]
