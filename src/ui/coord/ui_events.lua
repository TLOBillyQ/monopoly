local nodes = require("Data.UIManagerNodes")

local function _collect_canvas_names(node_entries)
  local names = {}
  for _, entry in pairs(node_entries) do
    if type(entry) == "table" and entry[2] == "ECanvas" then
      names[#names + 1] = entry[1]
    end
  end
  table.sort(names)
  return names
end

local function _build_event_maps(canvas_names)
  local show, hide = {}, {}
  for _, name in ipairs(canvas_names) do
    show[name] = "显示" .. name
    hide[name] = "隐藏" .. name
  end
  return show, hide
end

local canvas_names = _collect_canvas_names(nodes)
local show_events, hide_events = _build_event_maps(canvas_names)

local ui_events = {
  canvas_names = canvas_names,
  show = show_events,
  hide = hide_events,
  roles = nil,
}


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

--[[ mutate4lua-manifest
version=4
projectHash=f718496fae24e8e2
scope.0.id=chunk:src/ui/coord/ui_events.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=60
scope.0.semanticHash=12acfa8bc95bb0c3
scope.1.id=function:_collect_canvas_names
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=12
scope.1.semanticHash=5aca701b2619405f
scope.2.id=function:_build_event_maps
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=21
scope.2.semanticHash=3ce5d2b5d17f79e9
scope.3.id=function:ui_events.set_roles
scope.3.kind=function
scope.3.startLine=34
scope.3.endLine=36
scope.3.semanticHash=a9d82726f0169db1
scope.4.id=function:ui_events.send_to_all
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=48
scope.4.semanticHash=7ca347df0683b059
scope.5.id=function:ui_events.send_to_role
scope.5.kind=function
scope.5.startLine=50
scope.5.endLine=57
scope.5.semanticHash=8293d8c76874aa00
]]
