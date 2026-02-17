local assertions = {}

function assertions.assert_equal(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assert_equal failed") .. " | expected=" .. tostring(expected) .. " got=" .. tostring(actual))
  end
end

function assertions.assert_truthy(value, msg)
  if not value then
    error(msg or "assert_truthy failed")
  end
end

function assertions.assert_phase(game, expected_phase, msg)
  local phase = game and game.turn and game.turn.phase or nil
  if phase ~= expected_phase then
    error((msg or "assert_phase failed") .. " | expected=" .. tostring(expected_phase) .. " got=" .. tostring(phase))
  end
end

return assertions
