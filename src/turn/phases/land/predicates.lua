local runtime_state = require("src.state.state_access.runtime_state")
local runtime_ports = require("src.core.ports.runtime_ports")

local function _has_action_anim(game)
  if not game or not game.turn then
    return false
  end
  if game.turn.action_anim then
    return true
  end
  local queue = game.turn.action_anim_queue
  return type(queue) == "table" and #queue > 0
end

local function _is_relocation_action_anim(entry)
  return entry and (entry.kind == "move_effect" or entry.kind == "teleport_effect" or entry.kind == "forced_relocation")
end

local function _has_pending_relocation_action_anim(game)
  if not game or not game.turn then
    return false
  end
  local current = game.turn.action_anim
  if _is_relocation_action_anim(current) then
    return true
  end
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" then
    return false
  end
  for _, entry in ipairs(queue) do
    if _is_relocation_action_anim(entry) then
      return true
    end
  end
  return false
end

local function _landing_visual_hold_state(game)
  if not game then
    return nil
  end
  return game.landing_visual_hold_state
end

local function _is_landing_visual_hold_active(game)
  local state = _landing_visual_hold_state(game)
  if state ~= nil and runtime_state.get_landing_visual_hold_source(state) ~= nil then
    return runtime_state.get_landing_visual_hold_active(state)
  end
  local turn = game and game.turn or nil
  return turn and turn.landing_visual_hold_active == true or false
end

local function _is_effect_idle()
  return runtime_ports.is_effect_idle()
end

return {
  has_action_anim = _has_action_anim,
  is_relocation_action_anim = _is_relocation_action_anim,
  has_pending_relocation_action_anim = _has_pending_relocation_action_anim,
  landing_visual_hold_state = _landing_visual_hold_state,
  is_landing_visual_hold_active = _is_landing_visual_hold_active,
  is_effect_idle = _is_effect_idle,
}
