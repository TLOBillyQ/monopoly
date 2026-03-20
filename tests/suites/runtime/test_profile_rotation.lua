local profile_rotation = require("src.app.bootstrap.testing.profile_rotation")
local test_profile_resolver = require("src.app.bootstrap.testing.test_profile_resolver")

local function _contains(list, value)
  for _, entry in ipairs(list or {}) do
    if entry == value then
      return true
    end
  end
  return false
end

local function _test_high_value_profiles_drive_default_rotation_queue()
  profile_rotation._reset_for_tests()
  local expected = test_profile_resolver.high_value_profiles()
  profile_rotation.init()
  local snapshot = profile_rotation.snapshot()
  assert(#snapshot.queue == #expected, "default rotation should use curated high value profiles")
  for index, name in ipairs(expected) do
    assert(snapshot.queue[index] == name, "rotation queue mismatch at index " .. tostring(index))
  end
  assert(_contains(snapshot.queue, "forced_move_hospital"), "high value queue should include forced_move_hospital")
  assert(_contains(snapshot.queue, "exile"), "high value queue should include exile")
  profile_rotation._reset_for_tests()
end

return {
  name = "runtime.test_profile_rotation",
  tests = {
    { name = "high_value_profiles_drive_default_rotation_queue", run = _test_high_value_profiles_drive_default_rotation_queue },
  },
}
