local Phase = {}

function Phase.BuildPhaseLabel(phase)
  if phase == "pre_action" then
    return "行动前"
  end
  if phase == "pre_move" then
    return "投骰后"
  end
  if phase == "post_action" then
    return "行动后"
  end
  return phase
end

function Phase.BuildPhaseTitle(game, base_title)
  assert(game ~= nil and game.store ~= nil, "missing game/store")
  assert(base_title ~= nil, "missing base title")
  local phase = game.store:get({ "turn", "item_phase_active" })
  assert(phase ~= nil, "missing item_phase_active")
  if phase == "" then
    return base_title
  end
  local label = Phase.BuildPhaseLabel(phase)
  return "[" .. label .. "] " .. base_title
end

return Phase
