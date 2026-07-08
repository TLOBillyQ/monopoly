require("spec.bootstrap")

-- autotest 车道的 headless 镜像：真实 roster/建局/turn loop/托管策略，
-- 一次跑完全部 test profile，与宿主 autotest 部署走同一编排器路径
-- （src/app/testing/autotest_bootstrap.lua）。任何 profile 建局崩溃、
-- tick 崩溃或 expect 不满足都会让本 spec 失败——这就是 CI 里的
-- "一次启动测所有 profile"。
local gameplay_fixtures = require("spec.support.gameplay_fixtures")
local gameplay_loop = require("src.turn.loop")
local gameplay_start = require("src.app.gameplay_start")
local startup_roster = require("src.app.roster")
local timing = require("src.config.gameplay.timing")
local autotest_bootstrap = require("src.app.testing.autotest_bootstrap")
local autotest_plan = require("src.app.testing.autotest_plan")

local TICK_SECONDS = 0.5
local MAX_TOTAL_TICKS = 20000

local function _install_sentinel_game(state)
  state.game_factory = startup_roster.build_game_factory(state, {
    build_mode = "debug",
    profile_name = "default",
  })
  local game = gameplay_loop.new_game(state)
  state.on_game_replaced(game)
  gameplay_start.prime_first_turn(game)
  return game
end

local function _drive_until_done(runner, state, current_game_ref)
  local ticks = 0
  while not runner.done and ticks < MAX_TOTAL_TICKS do
    ticks = ticks + 1
    local ok, err = pcall(gameplay_loop.tick, current_game_ref[1], state, TICK_SECONDS)
    state.tick_observer(TICK_SECONDS, ok, err)
  end
  return ticks
end

describe("autotest.run_all_profiles", function()
  it("runs_every_profile_end_to_end_without_failures", function()
    local original_decision_delay = timing.auto_decision_delay_seconds
    local state = gameplay_fixtures.build_loop_state()
    local current_game_ref = { nil }
    state.on_game_replaced = function(new_game)
      current_game_ref[1] = new_game
      gameplay_loop.set_game(state, new_game)
    end

    local runner
    local ok, err = pcall(function()
      runner = autotest_bootstrap.install(state, {
        selector = "all",
        build_mode = "debug",
        get_current_game = function()
          return current_game_ref[1]
        end,
        -- headless 预算：核心场景动作都发生在前几个玩家回合，
        -- 收紧预算防止行为车道超时；宿主侧沿用 runner 默认预算。
        max_player_turns = 6,
        max_seconds = 25,
      })
      assert(runner ~= nil, "autotest bootstrap should install a runner")

      _install_sentinel_game(state)
      local ticks = _drive_until_done(runner, state, current_game_ref)
      assert(runner.done, "runner should finish all profiles within " .. ticks .. " ticks")
    end)
    timing.auto_decision_delay_seconds = original_decision_delay
    assert(ok, tostring(err))

    local plan = autotest_plan.resolve("all")
    local totals = runner.recorder:totals()
    assert(totals.total == #plan,
      "every planned profile should produce a result, got " .. totals.total .. "/" .. #plan)

    local failures = {}
    for _, entry in ipairs(runner.recorder.entries) do
      if entry.result ~= "pass" then
        failures[#failures + 1] = entry.profile .. " (" .. tostring(entry.reason) .. ": "
          .. tostring(entry.message) .. ")"
      end
    end
    assert(#failures == 0, "failing profiles: " .. table.concat(failures, "; "))

    -- solo_missile 是当前唯一带 expect 的 profile：断言它真的走到
    -- expect_met（导弹被托管打出、拆楼、送医、事件发布），而不是
    -- 只靠预算兜底通过。
    local missile_entry
    for _, entry in ipairs(runner.recorder.entries) do
      if entry.profile == "solo_missile" then
        missile_entry = entry
      end
    end
    assert(missile_entry ~= nil, "solo_missile should be part of the all plan")
    assert(missile_entry.reason == "expect_met",
      "solo_missile should pass via expect, got: " .. tostring(missile_entry.reason))
  end)
end)
