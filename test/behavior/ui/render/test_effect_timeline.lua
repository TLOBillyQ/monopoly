-- Behavior specs for src/ui/render/support/effect_timeline.lua.
-- The timeline never runs anything itself: it hands (delay, callback) pairs to a
-- scheduler, so the specs capture the scheduled steps instead of waiting on time.

local support = require("test.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local effect_timeline = require("src.ui.render.support.effect_timeline")

-- _with_default_scheduler 在用例结尾把共享端口基线拆到未配置态,必须装回,
-- 否则 mutate 车道窄 suite 子集会撞空端口(#217)。注意钩子必须挂在 describe 内部:
-- 文件级 after_each 会被 mutate 车道 catalog 的捕获静默丢弃。
local function _restore_baseline()
  support.restore_runtime_services()
end

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- Records every (delay, callback) the timeline schedules, and lets a test fire
-- them back in order.
local function _recorder()
  local steps = {}
  return {
    steps = steps,
    schedule = function(delay, callback)
      steps[#steps + 1] = { delay = delay, callback = callback }
    end,
    fire = function(index)
      steps[index].callback()
    end,
  }
end

local function _with_default_scheduler(recorder, fn)
  runtime_ports.reset_for_tests()
  runtime_ports.configure({ schedule = recorder.schedule })
  local ok, err = pcall(fn)
  runtime_ports.reset_for_tests()
  if not ok then
    error(err, 2)
  end
end

TestEffectTimelineRunStep = {}

function TestEffectTimelineRunStep:tearDown()
  _restore_baseline()
end

function TestEffectTimelineRunStep:test_rejects_a_non_function_callback_without_scheduling()
  local recorder = _recorder()
  _assert_eq(effect_timeline.run_step(1.0, nil, { schedule = recorder.schedule }), false,
    "nil callback must be rejected")
  _assert_eq(effect_timeline.run_step(1.0, "nope", { schedule = recorder.schedule }), false,
    "non-function callback must be rejected")
  _assert_eq(#recorder.steps, 0, "rejected callbacks must not be scheduled")
end

function TestEffectTimelineRunStep:test_schedules_through_opts_schedule_when_it_is_a_function()
  local recorder = _recorder()
  local callback = function() end
  _assert_eq(effect_timeline.run_step(0.25, callback, { schedule = recorder.schedule }), true,
    "valid step reports success")
  _assert_eq(#recorder.steps, 1, "one step scheduled")
  _assert_eq(recorder.steps[1].delay, 0.25, "delay forwarded")
  _assert_eq(recorder.steps[1].callback, callback, "callback forwarded")
end

function TestEffectTimelineRunStep:test_substitutes_a_zero_delay_when_the_caller_passes_none()
  local recorder = _recorder()
  effect_timeline.run_step(nil, function() end, { schedule = recorder.schedule })
  _assert_eq(recorder.steps[1].delay, 0, "nil delay becomes 0")
end

function TestEffectTimelineRunStep:test_falls_back_to_the_runtime_scheduler_when_opts_carries_no_scheduler()
  local recorder = _recorder()
  _with_default_scheduler(recorder, function()
    effect_timeline.run_step(0.5, function() end, nil)
    effect_timeline.run_step(0.75, function() end, { schedule = "not-a-function" })
    _assert_eq(#recorder.steps, 2, "both steps fall back to runtime_ports.schedule")
    _assert_eq(recorder.steps[1].delay, 0.5, "missing opts falls back")
    _assert_eq(recorder.steps[2].delay, 0.75, "non-function opts.schedule falls back")
  end)
end

TestEffectTimelinePlay = {}

function TestEffectTimelinePlay:test_rejects_a_non_table_spec()
  _assert_eq(effect_timeline.play(nil), false, "nil spec rejected")
  _assert_eq(effect_timeline.play("spec"), false, "string spec rejected")
end

function TestEffectTimelinePlay:test_calls_show_immediately_and_schedules_each_step_with_its_own_delay()
  local recorder = _recorder()
  local order = {}
  local played = effect_timeline.play({
    schedule = recorder.schedule,
    show = function() order[#order + 1] = "show" end,
    steps = {
      { delay = 0.1, run = function() order[#order + 1] = "step1" end },
      { delay = 0.2, run = function() order[#order + 1] = "step2" end },
    },
  })

  _assert_eq(played, true, "play reports success")
  _assert_eq(order[1], "show", "show runs synchronously, before any step is scheduled")
  _assert_eq(#recorder.steps, 2, "each step scheduled, no teardown without cleanup/follow_up")
  _assert_eq(recorder.steps[1].delay, 0.1, "first step delay")
  _assert_eq(recorder.steps[2].delay, 0.2, "second step delay")

  recorder.fire(2)
  recorder.fire(1)
  _assert_eq(order[2], "step2", "steps run when the scheduler fires them, not before")
  _assert_eq(order[3], "step1", "step callbacks are the ones scheduled")
end

function TestEffectTimelinePlay:test_plays_a_spec_with_neither_show_nor_steps()
  local recorder = _recorder()
  _assert_eq(effect_timeline.play({ schedule = recorder.schedule }), true, "empty spec still plays")
  _assert_eq(#recorder.steps, 0, "nothing scheduled for an empty spec")
end

function TestEffectTimelinePlay:test_schedules_one_teardown_step_running_cleanup_then_follow_up()
  local recorder = _recorder()
  local order = {}
  effect_timeline.play({
    schedule = recorder.schedule,
    cleanup_delay = 1.5,
    cleanup = function() order[#order + 1] = "cleanup" end,
    follow_up = function() order[#order + 1] = "follow_up" end,
  })

  _assert_eq(#recorder.steps, 1, "cleanup and follow_up share a single scheduled step")
  _assert_eq(recorder.steps[1].delay, 1.5, "teardown uses cleanup_delay")
  recorder.fire(1)
  _assert_eq(order[1], "cleanup", "cleanup runs first")
  _assert_eq(order[2], "follow_up", "follow_up runs after cleanup")
end

function TestEffectTimelinePlay:test_schedules_teardown_at_zero_delay_when_cleanup_delay_is_absent()
  local recorder = _recorder()
  local cleaned = false
  effect_timeline.play({
    schedule = recorder.schedule,
    cleanup = function() cleaned = true end,
  })
  _assert_eq(recorder.steps[1].delay, 0, "missing cleanup_delay becomes 0")
  recorder.fire(1)
  _assert_eq(cleaned, true, "cleanup alone still runs")
end

function TestEffectTimelinePlay:test_schedules_teardown_when_only_follow_up_is_present()
  local recorder = _recorder()
  local followed = false
  effect_timeline.play({
    schedule = recorder.schedule,
    follow_up = function() followed = true end,
  })
  _assert_eq(#recorder.steps, 1, "follow_up alone earns a teardown step")
  recorder.fire(1)
  _assert_eq(followed, true, "follow_up alone still runs")
end

function TestEffectTimelinePlay:test_skips_teardown_when_neither_cleanup_nor_follow_up_is_a_function()
  local recorder = _recorder()
  effect_timeline.play({
    schedule = recorder.schedule,
    cleanup = "not-a-function",
    follow_up = 42,
    steps = { { delay = 0.3, run = function() end } },
  })
  _assert_eq(#recorder.steps, 1, "only the real step is scheduled")
  _assert_eq(recorder.steps[1].delay, 0.3, "the scheduled step is the timeline step")
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestEffectTimelineRunStep,
  TestEffectTimelinePlay
)
