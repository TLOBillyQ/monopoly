-- 验证：DeadlineService 的 5s/3s 警告按顺序触发，level 从 normal -> warn_5s -> warn_3s -> expired
local lu = require("luaunit")

local DeadlineService = require("src.turn.deadlines")
local runtime_state = require("src.state.runtime")

local function _build_state()
  local state = {}
  runtime_state.ensure_all(state)
  return state
end

TestFakeClockWarningLevels = {}

function TestFakeClockWarningLevels:test_levels_transition_through_normal_warn_5s_warn_3s_expired()
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
  lu.assertEquals(DeadlineService.peek(state, "choice").level, "normal")
  -- 推进至 elapsed=10.5（remaining=4.5），应该触发 warn_5s
  DeadlineService.tick(state, 9.5)
  lu.assertEquals(DeadlineService.peek(state, "choice").level, "warn_5s")
  lu.assertTrue(warns[1] == "warn_5s")
  -- 推进至 elapsed=12.5（remaining=2.5），应该触发 warn_3s
  DeadlineService.tick(state, 2.0)
  lu.assertEquals(DeadlineService.peek(state, "choice").level, "warn_3s")
  lu.assertTrue(warns[2] == "warn_3s")
  -- 推进到过期
  local fired_timeout = false
  DeadlineService.cancel(state, "choice")
  DeadlineService.start(state, "choice", {
    timeout_seconds = 1.0,
    on_timeout = function() fired_timeout = true end,
  })
  DeadlineService.tick(state, 1.5)
  lu.assertTrue(fired_timeout)
end

function TestFakeClockWarningLevels:test_warns_fire_only_once_each()
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
  lu.assertEquals(count_5s, 1)
  lu.assertEquals(count_3s, 1)
end

function TestFakeClockWarningLevels:test_expires_entries_at_exact_timeout_and_treats_missing_elapsed_as_zero()
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

  lu.assertNil(fired_scope)
  lu.assertEquals(entry.elapsed, 0.25)
  lu.assertEquals(DeadlineService.peek(state, "choice").remaining_seconds, 0.75)

  DeadlineService.tick(state, 0.75)

  lu.assertEquals(fired_scope, "choice")
  lu.assertTrue(entry.fired_timeout == true)
  lu.assertNil(DeadlineService.peek(state, "choice"))
end


function TestFakeClockWarningLevels:test_tick_ignores_non_table_states_and_non_positive_dt()
  DeadlineService.tick("not-a-state", 1.0)
  DeadlineService.tick(nil, 1.0)

  local state = {}
  DeadlineService.tick(state, 0)
  DeadlineService.tick(state, -1)
  DeadlineService.tick(state, "not-a-number")

  lu.assertNil(DeadlineService.peek(state, "choice"),
    "invalid ticks should not register or advance deadlines")
end


return TestFakeClockWarningLevels
