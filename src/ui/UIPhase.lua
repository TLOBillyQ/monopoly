local phase = {}

function phase.build_phase_label(phase)
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

function phase.build_phase_title(game, base_title)
  assert(game ~= nil and game.store ~= nil, "missing game/store")
  assert(base_title ~= nil, "missing base title")
  local phase_name = game.store:get({ "turn", "item_phase_active" })
  if not phase_name or phase_name == "" then
    return base_title
  end
  local label = phase.build_phase_label(phase_name)
  return "[" .. label .. "] " .. base_title
end

return phase
