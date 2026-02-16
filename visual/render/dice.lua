local runtime_constants = require("cfg.RuntimeConstants")
local ui_events = require("visual.events")
local number_utils = require("core.math")

local dice = {}
local spin_steps = 12

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
  local show_event = ui_events.show[dice_nodes.screen]
  if show_event then
    ui_events.send_to_all(show_event, {})
  end
  runtime.for_each_role_or_global(function()
    local nodes = {
      screen = runtime.query_node(dice_nodes.screen),
      spin = runtime.query_node(dice_nodes.spin),
      fx_end_1 = runtime.query_node(dice_nodes.fx_end_1),
      fx_end_2 = runtime.query_node(dice_nodes.fx_end_2),
      faces = {},
    }
    for index, name in ipairs(dice_nodes.faces) do
      nodes.faces[index] = runtime.query_node(name)
    end

    nodes.screen.visible = true
    nodes.spin.visible = true
    nodes.fx_end_1.visible = false
    nodes.fx_end_2.visible = false
    for _, node in ipairs(nodes.faces or {}) do
      node.visible = false
    end

    if duration and duration > 0 then
      local step_time = duration / spin_steps
      pcall(function()
        nodes.spin.rotation = runtime_constants.q_zero
      end)
      for i = 1, spin_steps do
        local delay = step_time * (i - 1)
        local angle = 720 * i / spin_steps
        SetTimeOut(delay, function()
          pcall(function()
            nodes.spin.rotation = math.Quaternion(0.0, 0.0, angle)
          end)
        end)
      end
    end

    SetTimeOut(duration, function()
      nodes.spin.visible = false
      nodes.fx_end_1.visible = true
      nodes.fx_end_2.visible = true
      if face then
        for index, node in ipairs(nodes.faces or {}) do
          node.visible = face == index
        end
      end
    end)

    SetTimeOut(duration + hold_seconds, function()
      local hide_event = ui_events.hide[dice_nodes.screen]
      if hide_event then
        ui_events.send_to_all(hide_event, {})
      end
      nodes.screen.visible = false
      nodes.spin.visible = false
      nodes.fx_end_1.visible = false
      nodes.fx_end_2.visible = false
      for _, node in ipairs(nodes.faces or {}) do
        node.visible = false
      end
    end)
  end)
end

return dice
