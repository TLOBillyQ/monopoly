local runtime_constants = require("Config.RuntimeConstants")

local dice = {}

local function _resolve_roll_face(anim)
  if not anim then
    return nil
  end
  local total = anim.total
  if type(total) == "number" then
    if total >= 1 and total <= 6 then
      return total
    end
    if total > 6 then
      local rolls = anim.rolls
      local first = type(rolls) == "table" and rolls[1] or nil
      if type(first) == "number" and first >= 1 and first <= 6 then
        return first
      end
    end
  end
  local rolls = anim.rolls
  local first = type(rolls) == "table" and rolls[1] or nil
  if type(first) == "number" and first >= 1 and first <= 6 then
    return first
  end
  return nil
end

function dice.play_roll_dice_screen(anim, duration, hold_seconds, opts)
  local runtime = assert(opts and opts.runtime, "missing runtime")
  local dice_nodes = assert(opts and opts.dice_screen_nodes, "missing dice_screen_nodes")
  local face = _resolve_roll_face(anim)
  runtime.for_each_role_or_global(function()
    local nodes = {
      screen = runtime.query_node(dice_nodes.screen),
      spin = runtime.query_node(dice_nodes.spin),
      faces = {},
    }
    for index, name in ipairs(dice_nodes.faces) do
      nodes.faces[index] = runtime.query_node(name)
    end

    nodes.screen.visible = true
    nodes.spin.visible = true
    for index, node in ipairs(nodes.faces or {}) do
      node.visible = face == index
    end

    if duration and duration > 0 then
      local steps = 12
      local step_time = duration / steps
      pcall(function()
        nodes.spin.rotation = runtime_constants.q_zero
      end)
      for i = 1, steps do
        local delay = step_time * (i - 1)
        local angle = 360 * i / steps
        SetTimeOut(delay, function()
          pcall(function()
            nodes.spin.rotation = math.Quaternion(0.0, 0.0, angle)
          end)
        end)
      end
    end

    SetTimeOut(duration, function()
      if face then
        for index, node in ipairs(nodes.faces or {}) do
          node.visible = face == index
        end
      end
    end)

    SetTimeOut(duration + hold_seconds, function()
      nodes.screen.visible = false
      nodes.spin.visible = false
      for _, node in ipairs(nodes.faces or {}) do
        node.visible = false
      end
    end)
  end)
end

return dice
