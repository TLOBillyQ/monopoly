local ui_events = require("src.ui.coord.ui_events")
local number_utils = require("src.foundation.number")

local canvas_events_steps = {}

local _captured = {}
local _installed = false
local _original_send_to_role = nil
local _original_send_to_all = nil

local function _resolve_role_id(role)
  if type(role) ~= "table" then
    return nil
  end
  if type(role.get_roleid) == "function" then
    local ok, id = pcall(role.get_roleid)
    if ok then
      return id
    end
  end
  return role.id
end

local function _install_capture()
  if _installed then
    return
  end
  _original_send_to_role = ui_events.send_to_role
  _original_send_to_all = ui_events.send_to_all
  ui_events.send_to_role = function(role, event_name, payload)
    _captured[#_captured + 1] = {
      scope = "role",
      role_id = _resolve_role_id(role),
      event = event_name,
    }
    return _original_send_to_role(role, event_name, payload)
  end
  ui_events.send_to_all = function(event_name, payload)
    _captured[#_captured + 1] = {
      scope = "all",
      role_id = nil,
      event = event_name,
    }
    return _original_send_to_all(event_name, payload)
  end
  _installed = true
end

local function _reset_capture()
  for i = #_captured, 1, -1 do
    _captured[i] = nil
  end
end

local function _world_role_id(world)
  return number_utils.to_integer(world.ui_role_id) or 1
end

local function _other_role_id(role_id)
  if role_id == 1 then
    return 2
  end
  return 1
end

local function _has_event_for_role(event_name, role_id)
  for _, entry in ipairs(_captured) do
    if entry.event == event_name then
      if entry.scope == "all" then
        return true
      end
      if entry.scope == "role" and tostring(entry.role_id) == tostring(role_id) then
        return true
      end
    end
  end
  return false
end

function canvas_events_steps.handlers()
  _install_capture()
  return {
    ["开始捕获画布事件"] = function(_)
      _install_capture()
      _reset_capture()
      return true
    end,

    ['画布事件"<事件>"已发送给自己'] = function(world, example)
      local event_name = tostring(example["事件"] or "")
      local role_id = _world_role_id(world)
      if _has_event_for_role(event_name, role_id) then
        return true
      end
      return nil, "expected canvas event " .. event_name ..
        " for role " .. tostring(role_id) .. " not captured"
    end,

    ['画布事件"<事件>"未发送给自己'] = function(world, example)
      local event_name = tostring(example["事件"] or "")
      local role_id = _world_role_id(world)
      for _, entry in ipairs(_captured) do
        if entry.event == event_name
          and entry.scope == "role"
          and tostring(entry.role_id) == tostring(role_id) then
          return nil, "unexpected canvas event " .. event_name ..
            " was sent to role " .. tostring(role_id)
        end
      end
      return true
    end,

    ['画布事件"<事件>"已发送给其他玩家'] = function(world, example)
      local event_name = tostring(example["事件"] or "")
      local other_id = _other_role_id(_world_role_id(world))
      if _has_event_for_role(event_name, other_id) then
        return true
      end
      return nil, "expected canvas event " .. event_name ..
        " for other role " .. tostring(other_id) .. " not captured"
    end,

    ['画布事件"<事件>"未发送给其他玩家'] = function(world, example)
      local event_name = tostring(example["事件"] or "")
      local other_id = _other_role_id(_world_role_id(world))
      for _, entry in ipairs(_captured) do
        if entry.event == event_name
          and entry.scope == "role"
          and tostring(entry.role_id) == tostring(other_id) then
          return nil, "unexpected canvas event " .. event_name ..
            " was sent to other role " .. tostring(other_id)
        end
      end
      return true
    end,

    ['画布事件"<事件>"已广播'] = function(_, example)
      local event_name = tostring(example["事件"] or "")
      for _, entry in ipairs(_captured) do
        if entry.scope == "all" and entry.event == event_name then
          return true
        end
      end
      return nil, "expected broadcast canvas event " .. event_name .. " not captured"
    end,
  }
end

canvas_events_steps._captured = _captured

return canvas_events_steps
