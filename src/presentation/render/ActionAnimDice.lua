local ui_events = require("src.presentation.shared.UIEvents")
local number_utils = require("src.core.utils.NumberUtils")
local host_runtime = require("src.presentation.adapter.HostRuntimePort")

local dice = {}

local function _resolve_face_value(value)
  local face = number_utils.to_integer(value)
  if face and face >= 1 and face <= 6 then
    return face
  end
  return nil
end

local function _resolve_roll_face(anim)
  if not anim then
    return nil
  end
  local rolls = anim.rolls
  local first = type(rolls) == "table" and rolls[1] or nil
  local first_face = _resolve_face_value(first)
  if first_face then
    return first_face
  end
  return _resolve_face_value(anim.total)
end

function dice.play_roll_dice_screen(anim, duration, hold_seconds, opts)
  local runtime = assert(opts and opts.runtime, "missing runtime")
  local dice_nodes = assert(opts and opts.dice_screen_nodes, "missing dice_screen_nodes")
  duration = duration or 0
  hold_seconds = hold_seconds or 0
  local face = _resolve_roll_face(anim)
  if not face then
    face = 1
  end
  local show_event = ui_events.show[dice_nodes.canvas]
  if show_event then
    ui_events.send_to_all(show_event, {})
  end
  ui_events.send_to_all("重置骰子旋转", {})
  ui_events.send_to_all("旋转骰子", {})
  runtime.for_each_role_or_global(function()
    local nodes = {
      screen = runtime.query_node(dice_nodes.canvas),
      spin = runtime.query_node(dice_nodes.spin),
      faces = {},
    }
    for index, name in ipairs(dice_nodes.faces) do
      nodes.faces[index] = runtime.query_node(name)
    end

    nodes.screen.visible = true
    nodes.spin.visible = true
    for _, node in ipairs(nodes.faces or {}) do
      node.visible = false
    end

    host_runtime.schedule(duration, function()
      ui_events.send_to_all("重置骰子旋转", {})
      nodes.spin.visible = false
      if face then
        for index, node in ipairs(nodes.faces or {}) do
          node.visible = face == index
        end
      end
    end)

    host_runtime.schedule(duration + hold_seconds, function()
      local hide_event = ui_events.hide[dice_nodes.canvas]
      if hide_event then
        ui_events.send_to_all(hide_event, {})
      end
      nodes.screen.visible = false
      nodes.spin.visible = false
      for _, node in ipairs(nodes.faces or {}) do
        node.visible = false
      end
    end)
  end)
end

return dice
