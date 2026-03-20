local logger = require("src.core.utils.logger")
local test_profile_resolver = require("src.app.bootstrap.testing.test_profile_resolver")

local rotation = {}
local state_ref = nil

local DEFAULT_TURNS_PER_PROFILE = 20

local function _build_queue(names)
  local queue = {}
  for _, name in ipairs(names or {}) do
    if name ~= "default" then
      queue[#queue + 1] = name
    end
  end
  return queue
end

local function _current_state()
  return state_ref
end

function rotation.init(opts)
  opts = opts or {}
  local queue = opts.queue
  if type(queue) == "table" then
    queue = _build_queue(queue)
  else
    queue = _build_queue(test_profile_resolver.high_value_profiles())
  end
  local turns_per_profile = opts.turns_per_profile
  if turns_per_profile == nil or turns_per_profile <= 0 then
    turns_per_profile = DEFAULT_TURNS_PER_PROFILE
  end
  state_ref = {
    queue = queue,
    index = 1,
    turns_per_profile = turns_per_profile,
    results = {},
    finished = #queue == 0,
  }
  logger.info(
    "[ProfileRotation]",
    "init",
    "profiles=" .. tostring(#queue),
    "turns_per_profile=" .. tostring(turns_per_profile)
  )
  local current_name = rotation.current_profile_name()
  if current_name ~= nil then
    logger.info(
      "[ProfileRotation]",
      "start",
      "profile=" .. tostring(current_name),
      "index=1/" .. tostring(#queue)
    )
  end
  return state_ref
end

function rotation.is_active()
  local state = _current_state()
  return state ~= nil and state.finished ~= true and #state.queue > 0
end

function rotation.current_profile_name()
  local state = _current_state()
  if state == nil or state.finished == true then
    return nil
  end
  return state.queue[state.index]
end

function rotation.turns_per_profile()
  local state = _current_state()
  if state == nil then
    return DEFAULT_TURNS_PER_PROFILE
  end
  return state.turns_per_profile or DEFAULT_TURNS_PER_PROFILE
end

function rotation.record_result(profile_name, turn_count, game_finished)
  local state = _current_state()
  if state == nil then
    return nil
  end
  local entry = {
    profile = profile_name,
    turns = turn_count or 0,
    finished = game_finished == true,
  }
  state.results[#state.results + 1] = entry
  return entry
end

function rotation.report()
  local state = _current_state()
  if state == nil then
    return
  end
  logger.info("[ProfileRotation]", "=== ROTATION COMPLETE ===")
  for _, entry in ipairs(state.results) do
    logger.info(
      "[ProfileRotation]",
      tostring(entry.profile),
      "turns=" .. tostring(entry.turns),
      "game_finished=" .. tostring(entry.finished)
    )
  end
  logger.info("[ProfileRotation]", "=== END ===")
end

function rotation.advance()
  local state = _current_state()
  if state == nil or state.finished == true then
    return false
  end
  state.index = state.index + 1
  if state.index > #state.queue then
    state.finished = true
    rotation.report()
    return false
  end
  logger.info(
    "[ProfileRotation]",
    "start",
    "profile=" .. tostring(state.queue[state.index]),
    "index=" .. tostring(state.index) .. "/" .. tostring(#state.queue)
  )
  return true
end

function rotation.snapshot()
  local state = _current_state()
  if state == nil then
    return nil
  end
  local snapshot = {
    index = state.index,
    turns_per_profile = state.turns_per_profile,
    finished = state.finished == true,
    queue = {},
    results = {},
  }
  for index, name in ipairs(state.queue or {}) do
    snapshot.queue[index] = name
  end
  for index, entry in ipairs(state.results or {}) do
    snapshot.results[index] = {
      profile = entry.profile,
      turns = entry.turns,
      finished = entry.finished,
    }
  end
  return snapshot
end

function rotation._reset_for_tests()
  state_ref = nil
end

return rotation
