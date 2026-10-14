-- 验证：DeadlineService 的 5s/3s 警告按顺序触发，level 从 normal -> warn_5s -> warn_3s -> expired
-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
local function _assert_same(actual, expected, message)
  luassert.is.same(expected, actual, message)
end

local DeadlineService = require("src.turn.deadlines")
local runtime_state = require("src.state.runtime")

local function _build_state()
  local state = {}
  runtime_state.ensure_all(state)
  return state
end

describe("TestFakeClockWarningLevels", function()

it("test_levels_transition_through_normal_warn_5s_warn_3s_expired", function()
  local state = _build_state()
  local warns = {}
  DeadlineService.start(state, "choice", {
    timeout_seconds = 15,
    on_warn = function(level)
      warns[#warns + 1] = level
    end,
  })
  -- 推进 1s -> remaining 14, normal
  DeadlineService.tick(state, 1.0)
  _assert_same(DeadlineService.peek(state, "choice").level, "normal")
  -- 推进至 elapsed=10.5（remaining=4.5），应该触发 warn_5s
  DeadlineService.tick(state, 9.5)
  _assert_same(DeadlineService.peek(state, "choice").level, "warn_5s")
  luassert.is_true(warns[1] == "warn_5s")
  -- 推进至 elapsed=12.5（remaining=2.5），应该触发 warn_3s
  DeadlineService.tick(state, 2.0)
  _assert_same(DeadlineService.peek(state, "choice").level, "warn_3s")
  luassert.is_true(warns[2] == "warn_3s")
  -- 推进到过期
  local fired_timeout = false
  DeadlineService.cancel(state, "choice")
  DeadlineService.start(state, "choice", {
    timeout_seconds = 1.0,
    on_timeout = function() fired_timeout = true end,
  })
  DeadlineService.tick(state, 1.5)
  luassert.is_true(fired_timeout)
end)

it("test_warns_fire_only_once_each", function()
  local state = _build_state()
  local count_5s, count_3s = 0, 0
  DeadlineService.start(state, "choice", {
    timeout_seconds = 15,
    on_warn = function(level)
      if level == "warn_5s" then count_5s = count_5s + 1 end
      if level == "warn_3s" then count_3s = count_3s + 1 end
    end,
  })
  -- 多次小步推进越过 5s 阈值
  DeadlineService.tick(state, 11.0)  -- remaining=4 -> warn_5s
  DeadlineService.tick(state, 0.5)   -- remaining=3.5 still warn_5s scope
  DeadlineService.tick(state, 0.6)   -- remaining=2.9 -> warn_3s
  DeadlineService.tick(state, 0.5)
  _assert_same(count_5s, 1)
  _assert_same(count_3s, 1)
end)

it("test_expires_entries_at_exact_timeout_and_treats_missing_elapsed_as_zero", function()
  local state = _build_state()
  local active = runtime_state.ensure_deadlines(state).active
  local fired_scope = nil
  local entry = {
    scope = "choice",
    timeout = 1,
    on_timeout = function(scope)
      fired_scope = scope
    end,
    fired_warn_5s = false,
    fired_warn_3s = false,
    fired_timeout = false,
  }

  active.choice = entry

  DeadlineService.tick(state, 0.25)

  luassert.is_nil(fired_scope)
  _assert_same(entry.elapsed, 0.25)
  _assert_same(DeadlineService.peek(state, "choice").remaining_seconds, 0.75)

  DeadlineService.tick(state, 0.75)

  _assert_same(fired_scope, "choice")
  luassert.is_true(entry.fired_timeout == true)
  luassert.is_nil(DeadlineService.peek(state, "choice"))
end)


it("test_tick_ignores_non_table_states_and_non_positive_dt", function()
  DeadlineService.tick("not-a-state", 1.0)
  DeadlineService.tick(nil, 1.0)

  local state = {}
  DeadlineService.tick(state, 0)
  DeadlineService.tick(state, -1)
  DeadlineService.tick(state, "not-a-number")

  luassert.is_nil(DeadlineService.peek(state, "choice"),
    "invalid ticks should not register or advance deadlines")
end)


end)
