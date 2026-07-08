local autotest_runner = require("src.app.testing.autotest_runner")

-- 用假环境驱动编排器状态机：就绪等待、expect 提前通过、预算收尾、
-- 崩溃隔离、建局失败续跑、汇总行。真实端到端见
-- spec/behavior/scenarios/autotest/run_all_profiles_spec.lua。

local function _new_env(opts)
  opts = opts or {}
  local env = {
    lines = {},
    started = {},
    games = {},
    ready = opts.ready ~= false,
    expects = opts.expects or {},
    verdicts = opts.verdicts or {},
    boot_errors = opts.boot_errors or {},
  }

  local deps = {
    plan = opts.plan or { "profile_a", "profile_b" },
    selector = opts.selector or "all",
    poll_seconds = 1,
    max_player_turns = opts.max_player_turns or 4,
    max_seconds = opts.max_seconds or 100,
    is_ready = function()
      return env.ready
    end,
    start_profile_game = function(name)
      if env.boot_errors[name] then
        error("boot failed: " .. name)
      end
      local game = { turn = { turn_count = 0 }, finished = false, name = name }
      env.started[#env.started + 1] = name
      env.games[name] = game
      return game
    end,
    log = function(line)
      env.lines[#env.lines + 1] = line
    end,
    expect_for = function(name)
      return env.expects[name]
    end,
    evaluate = function(_, expect)
      if expect == nil then
        return { ok = true, failures = {} }
      end
      local verdict = env.verdicts[expect]
      if verdict ~= nil then
        return verdict
      end
      return { ok = false, failures = { "not yet" } }
    end,
    count_warns = function()
      return env.warns or 0
    end,
  }

  env.runner = autotest_runner.new(deps)
  return env
end

local function _step_polls(env, count)
  for _ = 1, count do
    env.runner:step(1)
  end
end

describe("autotest_runner", function()
  it("logs_begin_line_on_start_and_waits_for_readiness", function()
    local env = _new_env({ ready = false })
    env.runner:start()
    assert.equals("[autotest] begin selector=all total=2", env.lines[1])

    _step_polls(env, 3)
    assert.equals(0, #env.started, "not ready: no profile should start")

    env.ready = true
    _step_polls(env, 1)
    assert.equals("profile_a", env.started[1], "first profile starts once ready")
  end)

  it("throttles_observation_below_poll_seconds", function()
    local env = _new_env({})
    env.runner:start()
    env.runner:step(0.4)
    assert.equals(0, #env.started, "sub-poll dt should not trigger polling")
    env.runner:step(0.7)
    assert.equals(1, #env.started, "accumulated dt crosses poll threshold")
  end)

  it("passes_early_when_expect_met", function()
    local expect = { tiles = {} }
    local env = _new_env({
      plan = { "profile_a" },
      expects = { profile_a = expect },
      verdicts = { [expect] = { ok = true, failures = {} } },
    })
    env.runner:start()
    _step_polls(env, 2)

    local entry = env.runner.recorder.entries[1]
    assert.equals("pass", entry.result)
    assert.equals("expect_met", entry.reason)
    assert(env.runner.done, "single-profile plan should complete")
    assert.equals("[autotest] summary total=1 pass=1 fail=0 seconds=1.0",
      env.lines[#env.lines])
  end)

  it("fails_with_expect_unmet_when_budget_ends_first", function()
    local expect = { tiles = {} }
    local env = _new_env({
      plan = { "profile_a" },
      expects = { profile_a = expect },
      max_player_turns = 2,
    })
    env.runner:start()
    _step_polls(env, 1)
    env.games.profile_a.turn.turn_count = 2
    _step_polls(env, 1)

    local entry = env.runner.recorder.entries[1]
    assert.equals("fail", entry.result)
    assert.equals("expect_unmet", entry.reason)
    assert.equals("not yet", entry.message)
  end)

  it("passes_on_turn_budget_without_expect", function()
    local env = _new_env({ plan = { "profile_a" }, max_player_turns = 3 })
    env.runner:start()
    _step_polls(env, 1)
    env.games.profile_a.turn.turn_count = 3
    _step_polls(env, 1)

    local entry = env.runner.recorder.entries[1]
    assert.equals("pass", entry.result)
    assert.equals("budget_turns", entry.reason)
    assert.equals(3, entry.turns)
  end)

  it("passes_on_game_finished_without_expect", function()
    local env = _new_env({ plan = { "profile_a" } })
    env.runner:start()
    _step_polls(env, 1)
    env.games.profile_a.finished = true
    _step_polls(env, 1)

    assert.equals("game_finished", env.runner.recorder.entries[1].reason)
  end)

  it("passes_on_time_budget_without_expect", function()
    local env = _new_env({ plan = { "profile_a" }, max_seconds = 2 })
    env.runner:start()
    _step_polls(env, 4)

    assert.equals("budget_seconds", env.runner.recorder.entries[1].reason)
  end)

  it("isolates_tick_crash_to_current_profile_and_continues", function()
    local env = _new_env({ plan = { "profile_a", "profile_b" } })
    env.runner:start()
    _step_polls(env, 1)
    env.runner:on_tick_error("attempt to index nil")
    _step_polls(env, 1)

    local first = env.runner.recorder.entries[1]
    assert.equals("fail", first.result)
    assert.equals("tick_error", first.reason)
    assert.equals("attempt to index nil", first.message)
    assert.equals("profile_b", env.started[2], "next profile keeps running after crash")

    env.games.profile_b.finished = true
    _step_polls(env, 1)
    assert(env.runner.done, "batch completes despite crash")
    assert.equals("[autotest] summary total=2 pass=1 fail=1 seconds=2.0",
      env.lines[#env.lines])
  end)

  it("records_boot_error_and_moves_to_next_profile", function()
    local env = _new_env({
      plan = { "profile_a", "profile_b" },
      boot_errors = { profile_a = true },
    })
    env.runner:start()
    _step_polls(env, 1)

    local first = env.runner.recorder.entries[1]
    assert.equals("fail", first.result)
    assert.equals("boot_error", first.reason)
    assert(first.message:find("boot failed: profile_a", 1, true) ~= nil,
      "boot error message should surface")
    assert.equals("profile_b", env.started[1], "runner should reach the next profile")
  end)

  it("ignores_tick_errors_outside_active_profile", function()
    local env = _new_env({ ready = false })
    env.runner:start()
    env.runner:on_tick_error("noise before any profile")
    env.ready = true
    _step_polls(env, 1)
    assert(env.runner.crash_message == nil, "pre-profile noise must not poison first profile")
  end)

  it("rejects_missing_deps_and_empty_plan", function()
    assert(not pcall(autotest_runner.new, nil), "nil deps must raise")
    assert(not pcall(autotest_runner.new, { plan = {} }), "empty plan must raise")
  end)
end)
