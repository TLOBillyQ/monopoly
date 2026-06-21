local life_loss = {}

local function _try_pcall(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  local ok = pcall(fn, ...)
  return ok == true
end

local function _call_role_die(role)
  if type(role) ~= "table" then
    return false
  end
  return _try_pcall(role.die, role, nil) or _try_pcall(role.die, nil)
end

local function _resolve_life_component(role)
  if type(role) ~= "table" or type(role.get_component) ~= "function" then
    return nil
  end
  local ok, life_comp = pcall(role.get_component, role, "LifeComp")
  if ok then
    return life_comp
  end
  return nil
end

local function _call_life_die(life_comp, role)
  if type(life_comp) ~= "table" then
    return false
  end
  return _try_pcall(life_comp.die, life_comp, role)
    or _try_pcall(life_comp.die, role)
    or _try_pcall(life_comp.die, nil)
end

local function _try_call_life_die(role)
  if not role then
    return false
  end
  if _call_role_die(role) then
    return true
  end
  return _call_life_die(_resolve_life_component(role), role)
end

life_loss.call_life_die = _call_life_die
life_loss.resolve_life_component = _resolve_life_component
life_loss.try_call_life_die = _try_call_life_die

return life_loss
