local canvas_state = {}

local function _ensure_table(t, key)
  if type(t[key]) ~= "table" then
    t[key] = {}
  end
  return t[key]
end

function canvas_state.ensure(ui)
  if type(ui) ~= "table" then
    return nil
  end
  return _ensure_table(ui, "canvas_state")
end

function canvas_state.get(ui, key)
  local state = canvas_state.ensure(ui)
  if not state or not key then
    return nil
  end
  return _ensure_table(state, key)
end

function canvas_state.set(ui, key, value)
  local state = canvas_state.ensure(ui)
  if not state or not key then
    return
  end
  state[key] = value
end

return canvas_state
