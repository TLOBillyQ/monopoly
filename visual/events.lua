local nodes = require("Data.UIManagerNodes")

local ui_events = {
  canvas_names = {},
  show = {},
  hide = {},
  roles = nil,
}

for _, entry in pairs(nodes) do
  if type(entry) == "table" then
    local name = entry[1]
    local kind = entry[2]
    if kind == "ECanvas" then
      table.insert(ui_events.canvas_names, name)
    end
  end
end

table.sort(ui_events.canvas_names)

for _, name in ipairs(ui_events.canvas_names) do
  ui_events.show[name] = "显示" .. name
  ui_events.hide[name] = "隐藏" .. name
end


function ui_events.set_roles(roles)
  ui_events.roles = roles
end

function ui_events.send_to_all(event_name, payload)
  assert(event_name ~= nil, "missing event_name")
  local roles = ui_events.roles
  if not roles then
    return
  end
  local data = payload or {}
  for _, role in ipairs(roles) do
    role.send_ui_custom_event(event_name, data)
  end
end

function ui_events.send_to_role(role, event_name, payload)
  assert(role ~= nil, "missing role")
  assert(event_name ~= nil, "missing event_name")
  if not role.send_ui_custom_event then
    return
  end
  role.send_ui_custom_event(event_name, payload or {})
end

return ui_events
