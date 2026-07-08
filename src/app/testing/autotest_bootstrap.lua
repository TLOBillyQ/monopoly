local logger = require("src.foundation.log")
local timing = require("src.config.gameplay.timing")
local gameplay_loop = require("src.turn.loop")
local gameplay_start = require("src.app.gameplay_start")
local startup_roster = require("src.app.roster")
local test_profile_resolver = require("src.app.testing.test_profile_resolver")
local autotest_plan = require("src.app.testing.autotest_plan")
local autotest_expect = require("src.app.testing.autotest_expect")
local autotest_results = require("src.app.testing.autotest_results")
local autotest_runner = require("src.app.testing.autotest_runner")

-- 把 autotest 编排器接到宿主运行时：解析选择器、装速度档、
-- 提供按 profile 建局的能力，并占用 state.tick_observer 帧缝
-- （见 src/app/gameplay_start.lua）驱动 runner 与隔离 tick 崩溃。
-- 仅 debug 构建可达（init.lua 以 build mode 门控 + 惰性 require，
-- release 部署会整体剥离 src/app/testing）。
local bootstrap = {}

local AUTO_DECISION_SECONDS = 0.2

-- autotest 只验规则/结算端到端，不验动画节奏：关闭动画等待门、
-- 压缩托管决策间隔，让全量 profile 在分钟级跑完。
local function _apply_speed_profile(state)
  state.wait_move_anim = false
  state.wait_action_anim = false
  timing.auto_decision_delay_seconds = AUTO_DECISION_SECONDS
  if state.auto_runner ~= nil then
    state.auto_runner.interval = AUTO_DECISION_SECONDS
  end
end

local function _count_warns()
  return #logger.formatter.get_entries_by_level(logger, "warn")
end

local function _build_start_profile_game(state, build_mode)
  return function(profile_name)
    state.game_factory = startup_roster.build_game_factory(state, {
      build_mode = build_mode,
      profile_name = profile_name,
      auto_all = true,
    })
    local game = gameplay_loop.new_game(state)
    assert(type(state.on_game_replaced) == "function", "missing state.on_game_replaced")
    state.on_game_replaced(game)
    gameplay_start.prime_first_turn(game)
    return game
  end
end

function bootstrap.install(state, opts)
  assert(state ~= nil, "missing state")
  opts = opts or {}
  assert(type(opts.get_current_game) == "function", "missing get_current_game")

  local plan_ok, plan_or_err = pcall(autotest_plan.resolve, opts.selector)
  if not plan_ok then
    logger.info_unlimited(autotest_results.error_line(plan_or_err))
    return nil
  end

  _apply_speed_profile(state)

  local runner = autotest_runner.new({
    plan = plan_or_err,
    selector = opts.selector,
    start_profile_game = _build_start_profile_game(state, opts.build_mode),
    is_ready = function()
      return opts.get_current_game() ~= nil
    end,
    log = function(line)
      logger.info_unlimited(line)
    end,
    expect_for = test_profile_resolver.expect_for,
    evaluate = autotest_expect.evaluate,
    count_warns = _count_warns,
    poll_seconds = opts.poll_seconds,
    max_player_turns = opts.max_player_turns,
    max_seconds = opts.max_seconds,
  })

  state.tick_observer = function(dt, tick_ok, tick_err)
    if not tick_ok then
      runner:on_tick_error(tick_err)
    end
    runner:step(dt)
  end

  runner:start()
  return runner
end

return bootstrap
